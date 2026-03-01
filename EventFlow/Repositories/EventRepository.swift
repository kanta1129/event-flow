//
//  EventRepository.swift
//  EventFlow
//
//  イベントデータのCRUD操作とリアルタイム監視を定義するプロトコル
//

import Foundation

/// イベントデータの永続化とリアルタイム監視を抽象化するプロトコル
/// Requirements: 5.1, 8.1, 8.2
protocol EventRepository {
    
    /// イベントを作成
    /// - Parameter event: 作成するイベント
    /// - Returns: 作成されたイベントのID
    /// - Throws: データベースエラー
    func createEvent(_ event: Event) async throws -> String
    
    /// イベントを取得
    /// - Parameter id: イベントID
    /// - Returns: 取得したイベント
    /// - Throws: データベースエラー、イベントが見つからない場合
    func getEvent(id: String) async throws -> Event
    
    /// イベントを更新
    /// - Parameter event: 更新するイベント
    /// - Throws: データベースエラー
    func updateEvent(_ event: Event) async throws
    
    /// イベントを削除
    /// - Parameter id: 削除するイベントのID
    /// - Throws: データベースエラー
    func deleteEvent(id: String) async throws
    
    /// イベントをリアルタイムで監視
    /// - Parameter id: 監視するイベントのID
    /// - Returns: イベントの変更を通知するAsyncStream
    func observeEvent(id: String) -> AsyncStream<Event>
}
