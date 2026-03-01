//
//  SyncManager.swift
//  EventFlow
//
//  オフライン変更の同期と競合解決を管理
//  Requirements: 8.3
//

import Foundation
import Combine
import FirebaseFirestore

/// 同期エラー
enum SyncError: LocalizedError {
    case noConnection
    case syncFailed(Error)
    case conflictResolutionFailed
    case invalidChangeData
    
    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "ネットワーク接続がありません"
        case .syncFailed(let error):
            return "同期に失敗しました: \(error.localizedDescription)"
        case .conflictResolutionFailed:
            return "競合解決に失敗しました"
        case .invalidChangeData:
            return "変更データが無効です"
        }
    }
}

/// オフライン変更の同期と競合解決を管理するクラス
class SyncManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = SyncManager()
    
    // MARK: - Properties
    
    private let cacheManager: LocalCacheManager
    private let firebaseManager: FirebaseManager
    private let networkMonitor: NetworkMonitor
    
    /// 同期中かどうか
    @Published private(set) var isSyncing: Bool = false
    
    /// 同期エラー
    @Published private(set) var syncError: SyncError?
    
    private var syncObserver: NSObjectProtocol?
    
    // MARK: - Initialization
    
    init(cacheManager: LocalCacheManager = .shared,
         firebaseManager: FirebaseManager = .shared,
         networkMonitor: NetworkMonitor = .shared) {
        self.cacheManager = cacheManager
        self.firebaseManager = firebaseManager
        self.networkMonitor = networkMonitor
        
        setupReconnectionObserver()
    }
    
    deinit {
        if let observer = syncObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Public Methods
    
    /// 保留中の変更を手動で同期
    func syncPendingChanges() async {
        guard networkMonitor.isConnected else {
            syncError = .noConnection
            #if DEBUG
            print("⚠️ Cannot sync: No network connection")
            #endif
            return
        }
        
        guard !isSyncing else {
            #if DEBUG
            print("⚠️ Sync already in progress")
            #endif
            return
        }
        
        await performSync()
    }
    
    // MARK: - Private Methods
    
    /// 再接続時の自動同期を設定
    private func setupReconnectionObserver() {
        syncObserver = NotificationCenter.default.addObserver(
            forName: .networkReconnected,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.performSync()
            }
        }
        
        #if DEBUG
        print("🔄 SyncManager: Reconnection observer setup complete")
        #endif
    }
    
    /// 同期を実行
    private func performSync() async {
        isSyncing = true
        syncError = nil
        
        #if DEBUG
        print("🔄 Starting sync of pending changes...")
        #endif
        
        let pendingChanges = cacheManager.getPendingChanges()
        
        guard !pendingChanges.isEmpty else {
            #if DEBUG
            print("✅ No pending changes to sync")
            #endif
            isSyncing = false
            return
        }
        
        #if DEBUG
        print("📝 Found \(pendingChanges.count) pending changes to sync")
        #endif
        
        // タイムスタンプ順にソート（古い変更から適用）
        let sortedChanges = pendingChanges.sorted { $0.timestamp < $1.timestamp }
        
        for change in sortedChanges {
            do {
                try await applyChange(change)
                cacheManager.removePendingChange(id: change.id)
                
                #if DEBUG
                print("✅ Synced change: \(change.changeType) \(change.entityType) \(change.entityId)")
                #endif
            } catch {
                #if DEBUG
                print("❌ Failed to sync change \(change.id): \(error.localizedDescription)")
                #endif
                syncError = .syncFailed(error)
                // エラーが発生しても他の変更の同期を続行
                continue
            }
        }
        
        isSyncing = false
        
        #if DEBUG
        print("🔄 Sync completed")
        #endif
    }
    
    /// 個別の変更をFirestoreに適用
    private func applyChange(_ change: PendingChange) async throws {
        let db = firebaseManager.getFirestore()
        
        switch change.entityType {
        case .event:
            try await applyEventChange(change, db: db)
        case .task:
            try await applyTaskChange(change, db: db)
        case .participant:
            try await applyParticipantChange(change, db: db)
        }
    }
    
    /// イベント変更を適用
    private func applyEventChange(_ change: PendingChange, db: Firestore) async throws {
        let docRef = db.collection("events").document(change.entityId)
        
        switch change.changeType {
        case .create, .update:
            // 競合解決: last-write-wins
            let localData = try decodeChangeData(change.data)
            try await resolveConflictAndUpdate(docRef: docRef, localData: localData)
            
        case .delete:
            try await docRef.delete()
        }
    }
    
    /// タスク変更を適用
    private func applyTaskChange(_ change: PendingChange, db: Firestore) async throws {
        // entityIdの形式: "eventId/taskId"
        let components = change.entityId.split(separator: "/")
        guard components.count == 2 else {
            throw SyncError.invalidChangeData
        }
        
        let eventId = String(components[0])
        let taskId = String(components[1])
        
        let docRef = db.collection("events")
            .document(eventId)
            .collection("tasks")
            .document(taskId)
        
        switch change.changeType {
        case .create, .update:
            let localData = try decodeChangeData(change.data)
            try await resolveConflictAndUpdate(docRef: docRef, localData: localData)
            
        case .delete:
            try await docRef.delete()
        }
    }
    
    /// 参加者変更を適用
    private func applyParticipantChange(_ change: PendingChange, db: Firestore) async throws {
        // entityIdの形式: "eventId/participantId"
        let components = change.entityId.split(separator: "/")
        guard components.count == 2 else {
            throw SyncError.invalidChangeData
        }
        
        let eventId = String(components[0])
        let participantId = String(components[1])
        
        let docRef = db.collection("events")
            .document(eventId)
            .collection("participants")
            .document(participantId)
        
        switch change.changeType {
        case .create, .update:
            let localData = try decodeChangeData(change.data)
            try await resolveConflictAndUpdate(docRef: docRef, localData: localData)
            
        case .delete:
            try await docRef.delete()
        }
    }
    
    /// 競合解決とデータ更新（last-write-wins戦略）
    private func resolveConflictAndUpdate(
        docRef: DocumentReference,
        localData: [String: Any]
    ) async throws {
        // Firestoreから現在のデータを取得
        let snapshot = try await docRef.getDocument()
        
        if snapshot.exists, let remoteData = snapshot.data() {
            // 競合解決: updatedAtを比較してlast-write-winsを適用
            let localUpdatedAt = (localData["updatedAt"] as? Timestamp)?.dateValue() ?? Date.distantPast
            let remoteUpdatedAt = (remoteData["updatedAt"] as? Timestamp)?.dateValue() ?? Date.distantPast
            
            if localUpdatedAt > remoteUpdatedAt {
                // ローカルの変更が新しい場合のみ適用
                var dataToWrite = localData
                dataToWrite["updatedAt"] = Timestamp(date: Date())
                try await docRef.setData(dataToWrite, merge: true)
                
                #if DEBUG
                print("✅ Applied local change (newer than remote)")
                #endif
            } else {
                // リモートの変更が新しい場合はスキップ
                #if DEBUG
                print("⏭️ Skipped local change (remote is newer)")
                #endif
            }
        } else {
            // ドキュメントが存在しない場合は新規作成
            var dataToWrite = localData
            dataToWrite["updatedAt"] = Timestamp(date: Date())
            try await docRef.setData(dataToWrite)
            
            #if DEBUG
            print("✅ Created new document")
            #endif
        }
    }
    
    /// 変更データをデコード
    private func decodeChangeData(_ data: Data) throws -> [String: Any] {
        guard let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SyncError.invalidChangeData
        }
        return dictionary
    }
}
