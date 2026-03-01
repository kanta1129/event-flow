import Foundation

/// プロトコル: AI生成サービスのインターフェース
protocol AIService {
    /// イベントテンプレートを生成する
    /// - Parameters:
    ///   - eventType: イベントのタイプ（例: "BBQ", "飲み会", "旅行"）
    ///   - participantCount: 参加者数
    ///   - budget: 予算（オプション）
    /// - Returns: 生成されたイベントテンプレート
    /// - Throws: AI生成エラー（ネットワークエラー、APIエラーなど）
    func generateEventTemplate(
        eventType: String,
        participantCount: Int,
        budget: Double?
    ) async throws -> EventTemplate
    
    /// 催促メッセージを生成する
    /// - Parameter context: 催促メッセージのコンテキスト情報
    /// - Returns: 生成された催促メッセージ
    /// - Throws: AI生成エラー（ネットワークエラー、APIエラーなど）
    func generateReminderMessage(context: ReminderContext) async throws -> String
}

/// 催促メッセージ生成のコンテキスト情報
struct ReminderContext {
    let participantName: String
    let eventDate: Date?
    let incompleteTasks: [String]
    let isPaymentUnpaid: Bool
}
