//
//  FirestoreEventRepository.swift
//  EventFlow
//
//  Firestoreを使用したEventRepositoryの実装
//  Requirements: 5.1, 8.1, 8.2
//

import Foundation
import FirebaseFirestore

/// Firestoreを使用したイベントリポジトリの実装
class FirestoreEventRepository: EventRepository {
    
    // MARK: - Properties
    
    private let firebaseManager: FirebaseManager
    private let collectionPath = "events"
    
    // MARK: - Initialization
    
    init(firebaseManager: FirebaseManager = .shared) {
        self.firebaseManager = firebaseManager
    }
    
    // MARK: - EventRepository Implementation
    
    /// イベントを作成
    /// - Parameter event: 作成するイベント
    /// - Returns: 作成されたイベントのID
    /// - Throws: Firestoreエラー
    func createEvent(_ event: Event) async throws -> String {
        let db = firebaseManager.getFirestore()
        let docRef = db.collection(collectionPath).document(event.id)
        
        do {
            let eventData = try encodeEvent(event)
            try await docRef.setData(eventData)
            
            #if DEBUG
            print("✅ Event created: \(event.id)")
            #endif
            
            return event.id
        } catch {
            #if DEBUG
            print("❌ Failed to create event: \(error.localizedDescription)")
            #endif
            throw RepositoryError.createFailed(error)
        }
    }
    
    /// イベントを取得
    /// - Parameter id: イベントID
    /// - Returns: 取得したイベント
    /// - Throws: Firestoreエラー、イベントが見つからない場合
    func getEvent(id: String) async throws -> Event {
        let db = firebaseManager.getFirestore()
        let docRef = db.collection(collectionPath).document(id)
        
        do {
            let snapshot = try await docRef.getDocument()
            
            guard snapshot.exists else {
                throw RepositoryError.notFound
            }
            
            guard let data = snapshot.data() else {
                throw RepositoryError.invalidData
            }
            
            let event = try decodeEvent(from: data, id: id)
            
            #if DEBUG
            print("✅ Event retrieved: \(id)")
            #endif
            
            return event
        } catch let error as RepositoryError {
            throw error
        } catch {
            #if DEBUG
            print("❌ Failed to get event: \(error.localizedDescription)")
            #endif
            throw RepositoryError.fetchFailed(error)
        }
    }
    
    /// イベントを更新
    /// - Parameter event: 更新するイベント
    /// - Throws: Firestoreエラー
    func updateEvent(_ event: Event) async throws {
        let db = firebaseManager.getFirestore()
        let docRef = db.collection(collectionPath).document(event.id)
        
        do {
            var eventData = try encodeEvent(event)
            // updatedAtを現在時刻に更新
            eventData["updatedAt"] = Timestamp(date: Date())
            
            try await docRef.setData(eventData, merge: true)
            
            #if DEBUG
            print("✅ Event updated: \(event.id)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to update event: \(error.localizedDescription)")
            #endif
            throw RepositoryError.updateFailed(error)
        }
    }
    
    /// イベントを削除
    /// - Parameter id: 削除するイベントのID
    /// - Throws: Firestoreエラー
    func deleteEvent(id: String) async throws {
        let db = firebaseManager.getFirestore()
        let docRef = db.collection(collectionPath).document(id)
        
        do {
            try await docRef.delete()
            
            #if DEBUG
            print("✅ Event deleted: \(id)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to delete event: \(error.localizedDescription)")
            #endif
            throw RepositoryError.deleteFailed(error)
        }
    }
    
    /// イベントをリアルタイムで監視
    /// - Parameter id: 監視するイベントのID
    /// - Returns: イベントの変更を通知するAsyncStream
    func observeEvent(id: String) -> AsyncStream<Event> {
        let db = firebaseManager.getFirestore()
        let docRef = db.collection(collectionPath).document(id)
        
        return AsyncStream { continuation in
            let listener = docRef.addSnapshotListener { snapshot, error in
                if let error = error {
                    #if DEBUG
                    print("❌ Error observing event: \(error.localizedDescription)")
                    #endif
                    continuation.finish()
                    return
                }
                
                guard let snapshot = snapshot,
                      snapshot.exists,
                      let data = snapshot.data() else {
                    #if DEBUG
                    print("⚠️ Event snapshot is empty or doesn't exist")
                    #endif
                    continuation.finish()
                    return
                }
                
                do {
                    let event = try self.decodeEvent(from: data, id: id)
                    continuation.yield(event)
                    
                    #if DEBUG
                    print("📡 Event update received: \(id)")
                    #endif
                } catch {
                    #if DEBUG
                    print("❌ Failed to decode event: \(error.localizedDescription)")
                    #endif
                    continuation.finish()
                }
            }
            
            // AsyncStreamが終了したらリスナーを削除
            continuation.onTermination = { @Sendable _ in
                listener.remove()
                #if DEBUG
                print("🔌 Event listener removed: \(id)")
                #endif
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// EventをFirestore用のDictionaryにエンコード
    private func encodeEvent(_ event: Event) throws -> [String: Any] {
        return [
            "title": event.title,
            "eventType": event.eventType,
            "date": Timestamp(date: event.date),
            "organizerId": event.organizerId,
            "participantCount": event.participantCount,
            "budget": event.budget,
            "shareUrl": event.shareUrl,
            "createdAt": Timestamp(date: event.createdAt),
            "updatedAt": Timestamp(date: event.updatedAt)
        ]
    }
    
    /// FirestoreのDictionaryからEventをデコード
    private func decodeEvent(from data: [String: Any], id: String) throws -> Event {
        guard let title = data["title"] as? String,
              let eventType = data["eventType"] as? String,
              let dateTimestamp = data["date"] as? Timestamp,
              let organizerId = data["organizerId"] as? String,
              let participantCount = data["participantCount"] as? Int,
              let budget = data["budget"] as? Double,
              let shareUrl = data["shareUrl"] as? String,
              let createdAtTimestamp = data["createdAt"] as? Timestamp,
              let updatedAtTimestamp = data["updatedAt"] as? Timestamp else {
            throw RepositoryError.invalidData
        }
        
        return Event(
            id: id,
            title: title,
            eventType: eventType,
            date: dateTimestamp.dateValue(),
            organizerId: organizerId,
            participantCount: participantCount,
            budget: budget,
            shareUrl: shareUrl,
            createdAt: createdAtTimestamp.dateValue(),
            updatedAt: updatedAtTimestamp.dateValue()
        )
    }
}

// MARK: - Repository Error

/// リポジトリ操作で発生するエラー
enum RepositoryError: LocalizedError {
    case createFailed(Error)
    case fetchFailed(Error)
    case updateFailed(Error)
    case deleteFailed(Error)
    case notFound
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .createFailed(let error):
            return "イベントの作成に失敗しました: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "イベントの取得に失敗しました: \(error.localizedDescription)"
        case .updateFailed(let error):
            return "イベントの更新に失敗しました: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "イベントの削除に失敗しました: \(error.localizedDescription)"
        case .notFound:
            return "イベントが見つかりませんでした"
        case .invalidData:
            return "データの形式が正しくありません"
        }
    }
}
