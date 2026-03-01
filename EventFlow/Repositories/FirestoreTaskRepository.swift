//
//  FirestoreTaskRepository.swift
//  EventFlow
//
//  Firestoreを使用したTaskRepositoryの実装
//  Requirements: 2.4, 2.5, 2.6, 5.1
//

import Foundation
import FirebaseFirestore

/// Firestoreを使用したタスクリポジトリの実装
class FirestoreTaskRepository: TaskRepository {
    
    // MARK: - Properties
    
    private let firebaseManager: FirebaseManager
    private let eventsCollectionPath = "events"
    private let tasksSubcollectionPath = "tasks"
    
    // MARK: - Initialization
    
    init(firebaseManager: FirebaseManager = .shared) {
        self.firebaseManager = firebaseManager
    }
    
    // MARK: - TaskRepository Implementation
    
    /// タスクを追加
    /// - Parameters:
    ///   - task: 追加するタスク
    ///   - eventId: タスクが属するイベントのID
    /// - Returns: 作成されたタスクのID
    /// - Throws: Firestoreエラー
    func addTask(_ task: Task, eventId: String) async throws -> String {
        let db = firebaseManager.getFirestore()
        let docRef = db.collection(eventsCollectionPath)
            .document(eventId)
            .collection(tasksSubcollectionPath)
            .document(task.id)
        
        do {
            let taskData = try encodeTask(task)
            try await docRef.setData(taskData)
            
            #if DEBUG
            print("✅ Task created: \(task.id) in event: \(eventId)")
            #endif
            
            return task.id
        } catch {
            #if DEBUG
            print("❌ Failed to create task: \(error.localizedDescription)")
            #endif
            throw RepositoryError.createFailed(error)
        }
    }
    
    /// タスクを取得
    /// - Parameters:
    ///   - taskId: タスクID
    ///   - eventId: タスクが属するイベントのID
    /// - Returns: 取得したタスク
    /// - Throws: Firestoreエラー、タスクが見つからない場合
    func getTask(taskId: String, eventId: String) async throws -> Task {
        let db = firebaseManager.getFirestore()
        let docRef = db.collection(eventsCollectionPath)
            .document(eventId)
            .collection(tasksSubcollectionPath)
            .document(taskId)
        
        do {
            let snapshot = try await docRef.getDocument()
            
            guard snapshot.exists else {
                throw RepositoryError.notFound
            }
            
            guard let data = snapshot.data() else {
                throw RepositoryError.invalidData
            }
            
            let task = try decodeTask(from: data, id: taskId)
            
            #if DEBUG
            print("✅ Task retrieved: \(taskId) from event: \(eventId)")
            #endif
            
            return task
        } catch let error as RepositoryError {
            throw error
        } catch {
            #if DEBUG
            print("❌ Failed to get task: \(error.localizedDescription)")
            #endif
            throw RepositoryError.fetchFailed(error)
        }
    }
    
    /// タスクを更新
    /// - Parameters:
    ///   - task: 更新するタスク
    ///   - eventId: タスクが属するイベントのID
    /// - Throws: Firestoreエラー
    func updateTask(_ task: Task, eventId: String) async throws {
        let db = firebaseManager.getFirestore()
        let docRef = db.collection(eventsCollectionPath)
            .document(eventId)
            .collection(tasksSubcollectionPath)
            .document(task.id)
        
        do {
            var taskData = try encodeTask(task)
            // updatedAtを現在時刻に更新
            taskData["updatedAt"] = Timestamp(date: Date())
            
            try await docRef.setData(taskData, merge: true)
            
            #if DEBUG
            print("✅ Task updated: \(task.id) in event: \(eventId)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to update task: \(error.localizedDescription)")
            #endif
            throw RepositoryError.updateFailed(error)
        }
    }
    
    /// タスクを削除
    /// - Parameters:
    ///   - taskId: 削除するタスクのID
    ///   - eventId: タスクが属するイベントのID
    /// - Throws: Firestoreエラー
    func deleteTask(taskId: String, eventId: String) async throws {
        let db = firebaseManager.getFirestore()
        let docRef = db.collection(eventsCollectionPath)
            .document(eventId)
            .collection(tasksSubcollectionPath)
            .document(taskId)
        
        do {
            try await docRef.delete()
            
            #if DEBUG
            print("✅ Task deleted: \(taskId) from event: \(eventId)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to delete task: \(error.localizedDescription)")
            #endif
            throw RepositoryError.deleteFailed(error)
        }
    }
    
    /// イベントのタスクをリアルタイムで監視
    /// - Parameter eventId: 監視するイベントのID
    /// - Returns: タスクの変更を通知するAsyncStream
    func observeTasks(eventId: String) -> AsyncStream<[Task]> {
        let db = firebaseManager.getFirestore()
        let collectionRef = db.collection(eventsCollectionPath)
            .document(eventId)
            .collection(tasksSubcollectionPath)
        
        return AsyncStream { continuation in
            let listener = collectionRef.addSnapshotListener { snapshot, error in
                if let error = error {
                    #if DEBUG
                    print("❌ Error observing tasks: \(error.localizedDescription)")
                    #endif
                    continuation.finish()
                    return
                }
                
                guard let snapshot = snapshot else {
                    #if DEBUG
                    print("⚠️ Tasks snapshot is empty")
                    #endif
                    continuation.yield([])
                    return
                }
                
                var tasks: [Task] = []
                
                for document in snapshot.documents {
                    do {
                        let task = try self.decodeTask(from: document.data(), id: document.documentID)
                        tasks.append(task)
                    } catch {
                        #if DEBUG
                        print("❌ Failed to decode task \(document.documentID): \(error.localizedDescription)")
                        #endif
                        // 個別のタスクのデコードエラーは無視して続行
                        continue
                    }
                }
                
                continuation.yield(tasks)
                
                #if DEBUG
                print("📡 Tasks update received: \(tasks.count) tasks in event: \(eventId)")
                #endif
            }
            
            // AsyncStreamが終了したらリスナーを削除
            continuation.onTermination = { @Sendable _ in
                listener.remove()
                #if DEBUG
                print("🔌 Tasks listener removed for event: \(eventId)")
                #endif
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// TaskをFirestore用のDictionaryにエンコード
    private func encodeTask(_ task: Task) throws -> [String: Any] {
        var data: [String: Any] = [
            "title": task.title,
            "description": task.description,
            "priority": task.priority.rawValue,
            "status": task.status.rawValue,
            "createdAt": Timestamp(date: task.createdAt),
            "updatedAt": Timestamp(date: task.updatedAt)
        ]
        
        // オプショナルフィールドの処理
        if let assignedTo = task.assignedTo {
            data["assignedTo"] = assignedTo
        }
        
        if let note = task.note {
            data["note"] = note
        }
        
        return data
    }
    
    /// FirestoreのDictionaryからTaskをデコード
    private func decodeTask(from data: [String: Any], id: String) throws -> Task {
        guard let title = data["title"] as? String,
              let description = data["description"] as? String,
              let priorityString = data["priority"] as? String,
              let priority = TaskPriority(rawValue: priorityString),
              let statusString = data["status"] as? String,
              let status = TaskStatus(rawValue: statusString),
              let createdAtTimestamp = data["createdAt"] as? Timestamp,
              let updatedAtTimestamp = data["updatedAt"] as? Timestamp else {
            throw RepositoryError.invalidData
        }
        
        // オプショナルフィールドの処理
        let assignedTo = data["assignedTo"] as? String
        let note = data["note"] as? String
        
        return Task(
            id: id,
            title: title,
            description: description,
            priority: priority,
            status: status,
            assignedTo: assignedTo,
            note: note,
            createdAt: createdAtTimestamp.dateValue(),
            updatedAt: updatedAtTimestamp.dateValue()
        )
    }
}
