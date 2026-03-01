//
//  ParticipantRepository.swift
//  EventFlow
//
//  参加者データのCRUD操作とリアルタイム監視を定義するプロトコル
//  Requirements: 9.1, 9.2, 9.4
//

import Foundation

/// 参加者データの永続化とリアルタイム監視を抽象化するプロトコル
protocol ParticipantRepository {
    
    /// 参加者を追加
    /// - Parameters:
    ///   - participant: 追加する参加者
    ///   - eventId: 参加者が属するイベントのID
    /// - Returns: 作成された参加者のID
    /// - Throws: データベースエラー
    func addParticipant(_ participant: Participant, eventId: String) async throws -> String
    
    /// 参加者を取得
    /// - Parameters:
    ///   - participantId: 参加者ID
    ///   - eventId: 参加者が属するイベントのID
    /// - Returns: 取得した参加者
    /// - Throws: データベースエラー、参加者が見つからない場合
    func getParticipant(participantId: String, eventId: String) async throws -> Participant
    
    /// 参加者を更新
    /// - Parameters:
    ///   - participant: 更新する参加者
    ///   - eventId: 参加者が属するイベントのID
    /// - Throws: データベースエラー
    func updateParticipant(_ participant: Participant, eventId: String) async throws
    
    /// 参加者を削除
    /// - Parameters:
    ///   - participantId: 削除する参加者のID
    ///   - eventId: 参加者が属するイベントのID
    /// - Throws: データベースエラー
    func deleteParticipant(participantId: String, eventId: String) async throws
    
    /// イベントの参加者をリアルタイムで監視
    /// - Parameter eventId: 監視するイベントのID
    /// - Returns: 参加者の変更を通知するAsyncStream
    func observeParticipants(eventId: String) -> AsyncStream<[Participant]>
}
