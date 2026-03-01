//
//  FirebaseManager.swift
//  EventFlow
//
//  Firestoreの初期化と設定を管理するシングルトンクラス
//

import Foundation
import FirebaseCore
import FirebaseFirestore

/// Firestoreの初期化と設定を管理するマネージャークラス
class FirebaseManager {
    
    // MARK: - Singleton
    
    static let shared = FirebaseManager()
    
    // MARK: - Properties
    
    /// Firestoreインスタンス
    private(set) var firestore: Firestore
    
    /// オフラインモードの有効化状態
    private(set) var isOfflinePersistenceEnabled: Bool = false
    
    // MARK: - Initialization
    
    private init() {
        // Firestoreインスタンスを取得
        self.firestore = Firestore.firestore()
        
        // Firestore設定
        configureFirestore()
    }
    
    // MARK: - Configuration
    
    /// Firestoreの設定を行う
    private func configureFirestore() {
        let settings = FirestoreSettings()
        
        // オフライン永続化を有効化（Requirements 8.2, 8.3）
        settings.isPersistenceEnabled = true
        
        // キャッシュサイズの設定（100MB）
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        
        firestore.settings = settings
        
        isOfflinePersistenceEnabled = true
        
        #if DEBUG
        print("✅ Firestore initialized with offline persistence enabled")
        #endif
    }
    
    // MARK: - Public Methods
    
    /// Firestoreインスタンスを取得
    /// - Returns: 設定済みのFirestoreインスタンス
    func getFirestore() -> Firestore {
        return firestore
    }
    
    /// コレクションへの参照を取得
    /// - Parameter path: コレクションパス
    /// - Returns: CollectionReference
    func collection(_ path: String) -> CollectionReference {
        return firestore.collection(path)
    }
    
    /// ドキュメントへの参照を取得
    /// - Parameter path: ドキュメントパス
    /// - Returns: DocumentReference
    func document(_ path: String) -> DocumentReference {
        return firestore.document(path)
    }
    
    /// バッチ書き込みを開始
    /// - Returns: WriteBatch
    func batch() -> WriteBatch {
        return firestore.batch()
    }
    
    /// トランザクションを実行
    /// - Parameter updateBlock: トランザクション内で実行する処理
    /// - Returns: トランザクション結果
    func runTransaction<T>(_ updateBlock: @escaping (Transaction) throws -> T) async throws -> T {
        return try await firestore.runTransaction { transaction, errorPointer in
            do {
                return try updateBlock(transaction)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil as T?
            }
        } as! T
    }
    
    // MARK: - Network Status
    
    /// ネットワーク接続を無効化（テスト用）
    func disableNetwork() async throws {
        try await firestore.disableNetwork()
        #if DEBUG
        print("🔌 Firestore network disabled")
        #endif
    }
    
    /// ネットワーク接続を有効化
    func enableNetwork() async throws {
        try await firestore.enableNetwork()
        #if DEBUG
        print("🔌 Firestore network enabled")
        #endif
    }
    
    // MARK: - Cache Management
    
    /// ローカルキャッシュをクリア
    func clearPersistence() async throws {
        try await firestore.clearPersistence()
        #if DEBUG
        print("🗑️ Firestore cache cleared")
        #endif
    }
    
    /// キャッシュからデータを待機（オフライン時のフォールバック）
    func waitForPendingWrites() async throws {
        try await firestore.waitForPendingWrites()
        #if DEBUG
        print("⏳ Pending writes completed")
        #endif
    }
}

// MARK: - Firestore Error Handling

extension FirebaseManager {
    
    /// Firestoreエラーを処理
    /// - Parameter error: Firestoreエラー
    /// - Returns: ユーザーフレンドリーなエラーメッセージ
    static func handleFirestoreError(_ error: Error) -> String {
        let nsError = error as NSError
        
        switch nsError.code {
        case FirestoreErrorCode.unavailable.rawValue:
            return "ネットワーク接続が利用できません。オフラインモードで動作しています。"
        case FirestoreErrorCode.permissionDenied.rawValue:
            return "この操作を実行する権限がありません。"
        case FirestoreErrorCode.notFound.rawValue:
            return "データが見つかりませんでした。"
        case FirestoreErrorCode.alreadyExists.rawValue:
            return "このデータは既に存在します。"
        case FirestoreErrorCode.unauthenticated.rawValue:
            return "認証が必要です。ログインしてください。"
        case FirestoreErrorCode.deadlineExceeded.rawValue:
            return "リクエストがタイムアウトしました。もう一度お試しください。"
        default:
            return "エラーが発生しました: \(error.localizedDescription)"
        }
    }
}
