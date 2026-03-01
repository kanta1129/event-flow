import Foundation

/// Gemini APIを使用したAI生成サービスの実装
class GeminiService: AIService {
    private let apiKey: String
    private let endpoint = "https://generativelanguage.googleapis.com/v1/models/gemini-pro:generateContent"
    private let maxRetries = 3
    
    /// GeminiServiceの初期化
    /// - Parameter apiKey: Gemini APIキー
    /// - Note: APIキーは環境変数または設定ファイルから取得することを推奨します
    ///         例: ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? ""
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // MARK: - AIService Protocol Implementation
    
    func generateEventTemplate(
        eventType: String,
        participantCount: Int,
        budget: Double?
    ) async throws -> EventTemplate {
        let prompt = buildEventTemplatePrompt(
            eventType: eventType,
            participantCount: participantCount,
            budget: budget
        )
        
        let response = try await callGeminiAPI(prompt: prompt)
        return try parseEventTemplate(from: response)
    }
    
    func generateReminderMessage(context: ReminderContext) async throws -> String {
        let prompt = buildReminderMessagePrompt(context: context)
        let response = try await callGeminiAPI(prompt: prompt)
        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Private Methods
    
    /// イベントテンプレート生成用のプロンプトを構築
    private func buildEventTemplatePrompt(
        eventType: String,
        participantCount: Int,
        budget: Double?
    ) -> String {
        var prompt = """
        以下の条件でイベント計画を生成してください：
        イベントタイプ: \(eventType)
        参加者数: \(participantCount)人
        """
        
        if let budget = budget {
            prompt += "\n予算: \(Int(budget))円/人"
        }
        
        prompt += """
        
        
        以下のJSON形式で出力してください：
        ```json
        {
          "shoppingList": [
            {"item": "商品名", "quantity": "数量", "estimatedCost": 金額}
          ],
          "tasks": [
            {"title": "タスク名", "description": "説明", "priority": "high/medium/low"}
          ],
          "schedule": [
            {"time": "HH:mm", "activity": "活動内容"}
          ]
        }
        ```
        
        注意事項：
        - shoppingListには具体的な商品名と数量を含めてください
        - tasksには少なくとも3つのタスクを含めてください
        - scheduleにはイベント当日のタイムラインを含めてください
        - JSONのみを出力し、説明文は含めないでください
        """
        
        return prompt
    }
    
    /// 催促メッセージ生成用のプロンプトを構築
    private func buildReminderMessagePrompt(context: ReminderContext) -> String {
        var prompt = """
        以下の状況で丁寧な催促メッセージを生成してください：
        参加者名: \(context.participantName)
        """
        
        if !context.incompleteTasks.isEmpty {
            prompt += "\n未完了タスク: \(context.incompleteTasks.joined(separator: ", "))"
        }
        
        if context.isPaymentUnpaid {
            prompt += "\n支払いステータス: 未払い"
        }
        
        if let eventDate = context.eventDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy年M月d日"
            prompt += "\nイベント日: \(formatter.string(from: eventDate))"
        }
        
        prompt += """
        
        
        要件：
        - 柔らかく、プレッシャーを与えない表現でお願いします
        - 友好的で協力的なトーンを使用してください
        - 簡潔に（3-4文程度）まとめてください
        """
        
        return prompt
    }
    
    /// Gemini APIを呼び出す（リトライロジック付き）
    private func callGeminiAPI(prompt: String) async throws -> String {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                return try await performAPICall(prompt: prompt)
            } catch let error as AIError {
                lastError = error
                
                // レート制限エラーの場合は指数バックオフで待機
                if case .rateLimitExceeded(let retryAfter) = error {
                    if attempt < maxRetries - 1 {
                        try await Task.sleep(nanoseconds: UInt64(retryAfter * 1_000_000_000))
                        continue
                    }
                }
                
                // その他のエラーは指数バックオフで再試行
                if attempt < maxRetries - 1 {
                    let delay = pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                
                throw error
            } catch {
                lastError = error
                
                // ネットワークエラーの場合は指数バックオフで再試行
                if attempt < maxRetries - 1 {
                    let delay = pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                
                throw AIError.networkError(error)
            }
        }
        
        throw lastError ?? AIError.maxRetriesExceeded
    }
    
    /// 実際のAPI呼び出しを実行
    private func performAPICall(prompt: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw AIError.apiKeyInvalid
        }
        
        // URLを構築
        guard var urlComponents = URLComponents(string: endpoint) else {
            throw AIError.invalidEndpoint
        }
        urlComponents.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        
        guard let url = urlComponents.url else {
            throw AIError.invalidEndpoint
        }
        
        // リクエストボディを構築
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw AIError.invalidRequest
        }
        
        // HTTPリクエストを作成
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 30
        
        // リクエストを実行
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // HTTPレスポンスを確認
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }
        
        // ステータスコードを確認
        switch httpResponse.statusCode {
        case 200:
            return try parseGeminiResponse(data)
        case 429:
            // レート制限エラー
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
            let delay = Double(retryAfter ?? "60") ?? 60.0
            throw AIError.rateLimitExceeded(retryAfter: delay)
        case 401, 403:
            throw AIError.apiKeyInvalid
        case 400:
            throw AIError.invalidRequest
        default:
            throw AIError.apiError(statusCode: httpResponse.statusCode)
        }
    }
    
    /// Gemini APIのレスポンスを解析してテキストを抽出
    private func parseGeminiResponse(_ data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw AIError.invalidResponse
        }
        
        return text
    }
    
    /// レスポンスからEventTemplateを解析
    private func parseEventTemplate(from response: String) throws -> EventTemplate {
        // JSONブロックを抽出（```json ... ``` の中身）
        let jsonString = extractJSON(from: response)
        
        guard let data = jsonString.data(using: .utf8) else {
            throw AIError.invalidResponse
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(EventTemplate.self, from: data)
        } catch {
            throw AIError.jsonParsingError(error)
        }
    }
    
    /// レスポンステキストからJSONブロックを抽出
    private func extractJSON(from text: String) -> String {
        // ```json ... ``` パターンを探す
        if let jsonRange = text.range(of: "```json\\s*([\\s\\S]*?)```", options: .regularExpression) {
            let jsonBlock = String(text[jsonRange])
            // ```json と ``` を削除
            let cleaned = jsonBlock
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned
        }
        
        // JSONブロックが見つからない場合は、{ } で囲まれた部分を探す
        if let startIndex = text.firstIndex(of: "{"),
           let endIndex = text.lastIndex(of: "}") {
            return String(text[startIndex...endIndex])
        }
        
        // それでも見つからない場合は元のテキストを返す
        return text
    }
}

// MARK: - Error Types

/// AI生成に関するエラー
enum AIError: LocalizedError {
    case networkError(Error)
    case rateLimitExceeded(retryAfter: TimeInterval)
    case invalidResponse
    case apiKeyInvalid
    case invalidEndpoint
    case invalidRequest
    case jsonParsingError(Error)
    case apiError(statusCode: Int)
    case maxRetriesExceeded
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "ネットワークエラーが発生しました: \(error.localizedDescription)"
        case .rateLimitExceeded(let seconds):
            return "AI生成の制限に達しました。\(Int(seconds))秒後に再試行してください。"
        case .invalidResponse:
            return "AIの応答を解析できませんでした。もう一度お試しください。"
        case .apiKeyInvalid:
            return "AI接続に問題があります。APIキーを確認してください。"
        case .invalidEndpoint:
            return "APIエンドポイントが無効です。"
        case .invalidRequest:
            return "リクエストが無効です。入力内容を確認してください。"
        case .jsonParsingError(let error):
            return "JSON解析エラー: \(error.localizedDescription)"
        case .apiError(let statusCode):
            return "APIエラーが発生しました（ステータスコード: \(statusCode)）"
        case .maxRetriesExceeded:
            return "最大再試行回数を超えました。しばらくしてから再試行してください。"
        }
    }
}
