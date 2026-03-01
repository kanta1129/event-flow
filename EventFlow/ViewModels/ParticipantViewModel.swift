//
//  ParticipantViewModel.swift
//  EventFlow
//
//  参加者管理と集金トラッキングのビジネスロジックと状態管理を担当するViewModel
//  Requirements: 7.1, 9.1, 10.1, 10.2, 10.3
//

import Foundation
import Combine

/// 参加者管理と集金トラッキングのViewModel
/// ObservableObjectプロトコルに準拠し、SwiftUIビューとバインド可能
@MainActor
class ParticipantViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 参加者のリスト
    @Published var participants: [Participant] = []
    
    /// 合計期待支払い額
    /// Requirements: 10.1
    @Published var totalExpected: Double = 0.0
    
    /// 合計回収済み支払い額
    /// Requirements: 10.2
    @Published var totalCollected: Double = 0.0
    
    /// ローディング状態
    @Published var isLoading: Bool = false
    
    /// エラー情報
    @Published var error: Error?
    
    // MARK: - Dependencies
    
    private let participantRepository: ParticipantRepository
    private let aiService: AIService
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var currentEventId: String?
    
    // MARK: - Initialization
    
    /// ParticipantViewModelの初期化
    /// - Parameters:
    ///   - participantRepository: 参加者データアクセス用のリポジトリ
    ///   - aiService: AI催促メッセージ生成用のサービス
    init(participantRepository: ParticipantRepository, aiService: AIService) {
        self.participantRepository = participantRepository
        self.aiService = aiService
    }
    
    // MARK: - Public Methods
    
    /// 参加者を追加
    /// Requirements: 9.1
    /// - Parameters:
    ///   - participant: 追加する参加者
    ///   - eventId: 参加者が属するイベントのID
    func addParticipant(_ participant: Participant, eventId: String) async {
        isLoading = true
        error = nil
        
        do {
            _ = try await participantRepository.addParticipant(participant, eventId: eventId)
            // リアルタイムリスナーが自動的に参加者リストを更新するため、
            // ここでは明示的にparticipants配列を更新しない
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }
    
    /// 参加者を更新
    /// - Parameters:
    ///   - participant: 更新する参加者
    ///   - eventId: 参加者が属するイベントのID
    func updateParticipant(_ participant: Participant, eventId: String) async {
        isLoading = true
        error = nil
        
        do {
            try await participantRepository.updateParticipant(participant, eventId: eventId)
            // リアルタイムリスナーが自動的に参加者リストを更新するため、
            // ここでは明示的にparticipants配列を更新しない
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }
    
    /// 参加者を削除
    /// - Parameters:
    ///   - participantId: 削除する参加者のID
    ///   - eventId: 参加者が属するイベントのID
    func deleteParticipant(participantId: String, eventId: String) async {
        isLoading = true
        error = nil
        
        do {
            try await participantRepository.deleteParticipant(participantId: participantId, eventId: eventId)
            // リアルタイムリスナーが自動的に参加者リストを更新するため、
            // ここでは明示的にparticipants配列を更新しない
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }
    
    /// 参加者のリアルタイム監視を開始
    /// Requirements: 9.1
    /// - Parameter eventId: 監視するイベントのID
    func observeParticipants(eventId: String) {
        // 既存のリスナーをクリア
        cancellables.removeAll()
        currentEventId = eventId
        
        let stream = participantRepository.observeParticipants(eventId: eventId)
        
        Task {
            for await participants in stream {
                self.participants = participants
                // 集金計算を更新
                calculatePaymentTotals()
            }
        }
    }
    
    /// 参加者の監視を停止
    func stopObserving() {
        cancellables.removeAll()
        currentEventId = nil
        participants = []
        totalExpected = 0.0
        totalCollected = 0.0
    }
    
    /// 催促メッセージを生成
    /// Requirements: 7.1
    /// - Parameters:
    ///   - participantId: 催促対象の参加者ID
    ///   - eventDate: イベント日時
    ///   - incompleteTasks: 未完了タスクのリスト
    /// - Returns: 生成された催促メッセージ
    func generateReminderMessage(
        participantId: String,
        eventDate: Date?,
        incompleteTasks: [String]
    ) async -> String? {
        guard let participant = participants.first(where: { $0.id == participantId }) else {
            return nil
        }
        
        isLoading = true
        error = nil
        
        do {
            let context = ReminderContext(
                participantName: participant.name,
                eventDate: eventDate,
                incompleteTasks: incompleteTasks,
                isPaymentUnpaid: participant.paymentStatus == .unpaid
            )
            
            let message = try await aiService.generateReminderMessage(context: context)
            isLoading = false
            return message
        } catch {
            self.error = error
            isLoading = false
            return nil
        }
    }
    
    // MARK: - Payment Calculation Methods
    
    /// 集金計算ロジック
    /// Requirements: 10.1, 10.2, 10.3
    private func calculatePaymentTotals() {
        // 合計期待支払い額を計算
        totalExpected = participants.reduce(0.0) { $0 + $1.expectedPayment }
        
        // 合計回収済み支払い額を計算（支払い済みの参加者のみ）
        totalCollected = participants
            .filter { $0.paymentStatus == .paid }
            .reduce(0.0) { $0 + $1.paidAmount }
    }
    
    /// 未回収支払い額を計算
    /// Requirements: 10.3
    /// - Returns: 未回収支払い額
    func outstandingPayment() -> Double {
        return totalExpected - totalCollected
    }
    
    /// 支払い完了率を計算
    /// Requirements: 10.5
    /// - Returns: 支払い完了率（0.0〜1.0）
    func completionPercentage() -> Double {
        guard totalExpected > 0 else {
            return 0.0
        }
        return totalCollected / totalExpected
    }
    
    /// 未払いの参加者を取得
    /// Requirements: 10.6
    /// - Returns: 未払いの参加者の配列
    func unpaidParticipants() -> [Participant] {
        return participants.filter { $0.paymentStatus == .unpaid }
    }
    
    /// 支払い済みの参加者を取得
    /// - Returns: 支払い済みの参加者の配列
    func paidParticipants() -> [Participant] {
        return participants.filter { $0.paymentStatus == .paid }
    }
    
    /// 参加者数を取得
    /// Requirements: 9.3
    /// - Returns: 参加者数
    func participantCount() -> Int {
        return participants.count
    }
}
