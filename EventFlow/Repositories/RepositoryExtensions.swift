//
//  RepositoryExtensions.swift
//  EventFlow
//
//  リポジトリのオフライン対応を支援する拡張機能
//  Requirements: 8.2, 8.3
//

import Foundation

/// リポジトリのオフライン対応ヘルパー
extension FirestoreEventRepository {
    
    /// オフライン時の変更をキューに追加
    func queueOfflineChange(
        changeType: PendingChange.ChangeType,
        event: Event
    ) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let eventDict: [String: Any] = [
            "id": event.id,
            "title": event.title,
            "eventType": event.eventType,
            "date": event.date.timeIntervalSince1970,
            "organizerId": event.organizerId,
            "participantCount": event.participantCount,
            "budget": event.budget,
            "shareUrl": event.shareUrl,
            "createdAt": event.createdAt.timeIntervalSince1970,
            "updatedAt": event.updatedAt.timeIntervalSince1970
        ]
        
        let data = try JSONSerialization.data(withJSONObject: eventDict)
        
        let change = PendingChange(
            changeType: changeType,
            entityType: .event,
            entityId: event.id,
            data: data
        )
        
        LocalCacheManager.shared.queueChange(change)
        LocalCacheManager.shared.cacheEvent(event)
    }
}

extension FirestoreTaskRepository {
    
    /// オフライン時の変更をキューに追加
    func queueOfflineChange(
        changeType: PendingChange.ChangeType,
        task: Task,
        eventId: String
    ) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let taskDict: [String: Any] = [
            "id": task.id,
            "title": task.title,
            "description": task.description,
            "priority": task.priority.rawValue,
            "status": task.status.rawValue,
            "assignedTo": task.assignedTo as Any,
            "note": task.note as Any,
            "createdAt": task.createdAt.timeIntervalSince1970,
            "updatedAt": task.updatedAt.timeIntervalSince1970
        ]
        
        let data = try JSONSerialization.data(withJSONObject: taskDict)
        
        // entityIdの形式: "eventId/taskId"
        let entityId = "\(eventId)/\(task.id)"
        
        let change = PendingChange(
            changeType: changeType,
            entityType: .task,
            entityId: entityId,
            data: data
        )
        
        LocalCacheManager.shared.queueChange(change)
        LocalCacheManager.shared.cacheTask(task, eventId: eventId)
    }
}

extension FirestoreParticipantRepository {
    
    /// オフライン時の変更をキューに追加
    func queueOfflineChange(
        changeType: PendingChange.ChangeType,
        participant: Participant,
        eventId: String
    ) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let participantDict: [String: Any] = [
            "id": participant.id,
            "name": participant.name,
            "expectedPayment": participant.expectedPayment,
            "paymentStatus": participant.paymentStatus.rawValue,
            "paidAmount": participant.paidAmount,
            "joinedAt": participant.joinedAt.timeIntervalSince1970,
            "updatedAt": participant.updatedAt.timeIntervalSince1970
        ]
        
        let data = try JSONSerialization.data(withJSONObject: participantDict)
        
        // entityIdの形式: "eventId/participantId"
        let entityId = "\(eventId)/\(participant.id)"
        
        let change = PendingChange(
            changeType: changeType,
            entityType: .participant,
            entityId: entityId,
            data: data
        )
        
        LocalCacheManager.shared.queueChange(change)
        LocalCacheManager.shared.cacheParticipant(participant, eventId: eventId)
    }
}
