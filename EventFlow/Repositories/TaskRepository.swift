//
//  TaskRepository.swift
//  EventFlow
//
//  タスクデータのCRUD操作とリアルタイム監視を定義するプロトコル
//  Requirements: 2.4, 2.5, 2.6, 5.1
//

import Foundation

/// タスクデータの永続化とリアルタイム監視を抽象化するプロトコル
protocol TaskRepository {
    
    /// タスクを追加
    /// - Parameters:
    ///   - task: 追加するタスク
    ///   - eventId: タスクが属するイベントのID
    /// - Returns: 作成されたタスクのID
    /// - Throws: データベースエラー
    func addTask(_ task: Task, eventId: String) async throws -> String
    
    /// タスクを取得
    /// - Parameters:
    ///   - taskId: タスクID
    ///   - eventId: タスクが属するイベントのID
    /// - Returns: 取得したタスク
    /// - Throws: データベースエラー、タスクが見つからない場合
    func getTask(taskId: String, eventId: String) async throws -> Task
    
    /// タスクを更新
    /// - Parameters:
    ///   - task: 更新するタスク
    ///   - eventId: タスクが属するイベントのID
    /// - Throws: データベースエラー
    func updateTask(_ task: Task, eventId: String) async throws
    
    /// タスクを削除
    /// - Parameters:
    ///   - taskId: 削除するタスクのID
    ///   - eventId: タスクが属するイベントのID
    /// - Throws: データベースエラー
    func deleteTask(taskId: String, eventId: String) async throws
    
    /// イベントのタスクをリアルタイムで監視
    /// - Parameter eventId: 監視するイベントのID
    /// - Returns: タスクの変更を通知するAsyncStream
    func observeTasks(eventId: String) -> AsyncStream<[Task]>
}
