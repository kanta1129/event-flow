//
//  FirestoreParticipantRepository.swift
//  EventFlow
//
//  Firestoreを使用したParticipantRepositoryの実装
//  Requirements: 9.1, 9.2, 9.4
//

import Foundation
import FirebaseFirestore

/// Firestoreを使用した参加者リポジトリの実装
class FirestoreParticipantRepository: ParticipantRepository {
    
    // MARK: - Properties
    
    private let firebaseManager: FirebaseManager
    private let eventsCollectionPath = "events"
    private let participantsSubcollectionPath = "participants"
    
    // MARK: - Initialization
    
    init(firebaseManager: FirebaseManager = .shared) {
        self.firebaseManager = firebaseManager
    }
    
    // MARK: - ParticipantRepository Implementation
    
    /// 参加者を追加
    /// - Parameters:
    ///   - participant: 追加する参加者
    ///   - eventId: 参加者が属するイベントのID
    /// - Returns: 作成された参加者のID
    /// - Throws: Firestoreエラー
    func addParticipant(_ participant: Participant, eventId: String) async throws -> String {
        let db = firebaseManager.getFirestore()
        let docRef = db.collection(eventsCollectionPath)
            .document(eventId)
            .collection(participantsSubcollectionPath)
            .document(participant.id)
        
        do {
            let participantData = try encodeParticipant(participant)
            try await docRef.setData(participantData)
            
            #if DEBUG
            print("✅ Participant created: \(participant.id) in event: \(eventId)")
            #endif
            
            return participant.id
        } catch {
            #if DEBUG
            print("❌ Failed to create participant: \(error.localizedDescription)")
            #endif
            throw RepositoryError.createFailed(error)
        }
    }
    
    /// 参加者を取得
    /// - Parameters:
    ///   - participantId: 参加者ID
    ///   - eventId: 参加者が属するイベントのID
    /// - Returns: 取得した参加者
    /// - Throws: Firestoreエラー、参加者が見つからない場合
    func getParticipant(participantId: String, eventId: String) async throws -> Participant {
        let db = firebaseManager.getFirestore()
        let docRef = db.collection(eventsCollectionPath)
            .document(eventId)
            .collection(participantsSubcollectionPath)
            .document(participantId)
        
        do {
            let snapshot = try await docRef.getDocument()
            
            guard snapshot.exists else {
                throw RepositoryError.notFound
            }
            
            guard let data = snapshot.data() else {
                throw RepositoryError.invalidData
            }
            
            let participant = try decodeParticipant(from: data, id: participantId)
            
            #if DEBUG
            print("✅ Participant retrieved: \(participantId) from event: \(eventId)")
            #endif
            
            return participant
        } catch let error as RepositoryError {
            throw error
        } catch {
            #if DEBUG
            print("❌ Failed to get participant: \(error.localizedDescription)")
            #endif
            throw RepositoryError.fetchFailed(error)
        }
    }
    
    /// 参加者を更新
    /// - Parameters:
    ///   - participant: 更新する参加者
    ///   - eventId: 参加者が属するイベントのID
    /// - Throws: Firestoreエラー
    func updateParticipant(_ participant: Participant, eventId: String) async throws {
        let db = firebaseManager.getFirestore()
        let docRef = db.collection(eventsCollectionPath)
            .document(eventId)
            .collection(participantsSubcollectionPath)
            .document(participant.id)
        
        do {
            var participantData = try encodeParticipant(participant)
            // updatedAtを現在時刻に更新
            participantData["updatedAt"] = Timestamp(date: Date())
            
            try await docRef.setData(participantData, merge: true)
            
            #if DEBUG
            print("✅ Participant updated: \(participant.id) in event: \(eventId)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to update participant: \(error.localizedDescription)")
            #endif
            throw RepositoryError.updateFailed(error)
        }
    }
    
    /// 参加者を削除
    /// - Parameters:
    ///   - participantId: 削除する参加者のID
    ///   - eventId: 参加者が属するイベントのID
    /// - Throws: Firestoreエラー
    func deleteParticipant(participantId: String, eventId: String) async throws {
        let db = firebaseManager.getFirestore()
        let docRef = db.collection(eventsCollectionPath)
            .document(eventId)
            .collection(participantsSubcollectionPath)
            .document(participantId)
        
        do {
            try await docRef.delete()
            
            #if DEBUG
            print("✅ Participant deleted: \(participantId) from event: \(eventId)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to delete participant: \(error.localizedDescription)")
            #endif
            throw RepositoryError.deleteFailed(error)
        }
    }
    
    /// イベントの参加者をリアルタイムで監視
    /// - Parameter eventId: 監視するイベントのID
    /// - Returns: 参加者の変更を通知するAsyncStream
    func observeParticipants(eventId: String) -> AsyncStream<[Participant]> {
        let db = firebaseManager.getFirestore()
        let collectionRef = db.collection(eventsCollectionPath)
            .document(eventId)
            .collection(participantsSubcollectionPath)
        
        return AsyncStream { continuation in
            let listener = collectionRef.addSnapshotListener { snapshot, error in
                if let error = error {
                    #if DEBUG
                    print("❌ Error observing participants: \(error.localizedDescription)")
                    #endif
                    continuation.finish()
                    return
                }
                
                guard let snapshot = snapshot else {
                    #if DEBUG
                    print("⚠️ Participants snapshot is empty")
                    #endif
                    continuation.yield([])
                    return
                }
                
                var participants: [Participant] = []
                
                for document in snapshot.documents {
                    do {
                        let participant = try self.decodeParticipant(from: document.data(), id: document.documentID)
                        participants.append(participant)
                    } catch {
                        #if DEBUG
                        print("❌ Failed to decode participant \(document.documentID): \(error.localizedDescription)")
                        #endif
                        // 個別の参加者のデコードエラーは無視して続行
                        continue
                    }
                }
                
                continuation.yield(participants)
                
                #if DEBUG
                print("📡 Participants update received: \(participants.count) participants in event: \(eventId)")
                #endif
            }
            
            // AsyncStreamが終了したらリスナーを削除
            continuation.onTermination = { @Sendable _ in
                listener.remove()
                #if DEBUG
                print("🔌 Participants listener removed for event: \(eventId)")
                #endif
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// ParticipantをFirestore用のDictionaryにエンコード
    private func encodeParticipant(_ participant: Participant) throws -> [String: Any] {
        let data: [String: Any] = [
            "name": participant.name,
            "expectedPayment": participant.expectedPayment,
            "paymentStatus": participant.paymentStatus.rawValue,
            "paidAmount": participant.paidAmount,
            "joinedAt": Timestamp(date: participant.joinedAt),
            "updatedAt": Timestamp(date: participant.updatedAt)
        ]
        
        return data
    }
    
    /// FirestoreのDictionaryからParticipantをデコード
    private func decodeParticipant(from data: [String: Any], id: String) throws -> Participant {
        guard let name = data["name"] as? String,
              let expectedPayment = data["expectedPayment"] as? Double,
              let paymentStatusString = data["paymentStatus"] as? String,
              let paymentStatus = PaymentStatus(rawValue: paymentStatusString),
              let paidAmount = data["paidAmount"] as? Double,
              let joinedAtTimestamp = data["joinedAt"] as? Timestamp,
              let updatedAtTimestamp = data["updatedAt"] as? Timestamp else {
            throw RepositoryError.invalidData
        }
        
        return Participant(
            id: id,
            name: name,
            expectedPayment: expectedPayment,
            paymentStatus: paymentStatus,
            paidAmount: paidAmount,
            joinedAt: joinedAtTimestamp.dateValue(),
            updatedAt: updatedAtTimestamp.dateValue()
        )
    }
}
