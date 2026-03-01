//
//  ErrorHandler.swift
//  EventFlow
//
//  エラーハンドリングユーティリティ
//  Requirements: 12.1, 12.2, 12.3
//

import Foundation
import FirebaseFirestore

/// エラーハンドリングユーティリティクラス
class ErrorHandler {
    
    /// シングルトンインスタンス
    static let shared = ErrorHandler()
    
    private let logger: ErrorLogger
    
    private init(logger: ErrorLogger = ErrorLogger.shared) {
        self.logger = logger
    }
    
    // MARK: - Error Conversion
    
    /// 汎用エラーをEventFlowErrorに変換
    /// - Parameter error: 変換元のエラー
    /// - Returns: EventFlowError
    func convertToEventFlowError(_ error: Error) -> EventFlowError {
        // 既にEventFlowErrorの場合はそのまま返す
        if let eventFlowError = error as? EventFlowError {
            return eventFlowError
        }
        
        // AIErrorの変換
        if let aiError = error as? AIError {
            return convertAIError(aiError)
        }
        
        // SyncErrorの変換
        if let syncError = error as? SyncError {
            return convertSyncError(syncError)
        }
        
        // FirestoreErrorの変換
        if let firestoreError = error as? FirestoreErrorCode {
            return convertFirestoreError(firestoreError)
        }
        
        // NSErrorの変換
        if let nsError = error as NSError {
            return convertNSError(nsError)
        }
        
        // その他のエラー
        return .unknown(error)
    }
    
    /// AIErrorをEventFlowErrorに変換
    private func convertAIError(_ error: AIError) -> EventFlowError {
        switch error {
        case .networkError(let underlyingError):
            return .networkError(underlyingError)
        case .rateLimitExceeded(let retryAfter):
            return .aiRateLimitExceeded(retryAfter: retryAfter)
        case .invalidResponse:
            return .aiInvalidResponse
        case .apiKeyInvalid:
            return .aiApiKeyInvalid
        case .invalidEndpoint, .invalidRequest, .jsonParsingError, .apiError:
            return .aiGenerationFailed
        case .maxRetriesExceeded:
            return .maxRetriesExceeded
        }
    }
    
    /// SyncErrorをEventFlowErrorに変換
    private func convertSyncError(_ error: SyncError) -> EventFlowError {
        switch error {
        case .noConnection:
            return .networkUnavailable
        case .syncFailed(let underlyingError):
            return .firestoreOperationFailed(underlyingError)
        case .conflictResolutionFailed:
            return .firestoreOperationFailed(error)
        case .invalidChangeData:
            return .invalidEventData
        }
    }
    
    /// FirestoreErrorCodeをEventFlowErrorに変換
    private func convertFirestoreError(_ error: FirestoreErrorCode) -> EventFlowError {
        switch error.code {
        case .unavailable, .deadlineExceeded:
            return .firestoreTimeout
        case .permissionDenied:
            return .firestorePermissionDenied
        case .notFound:
            return .firestoreDocumentNotFound
        case .unauthenticated:
            return .authenticationRequired
        default:
            return .firestoreOperationFailed(error)
        }
    }
    
    /// NSErrorをEventFlowErrorに変換
    private func convertNSError(_ error: NSError) -> EventFlowError {
        // ネットワークエラーの判定
        if error.domain == NSURLErrorDomain {
            switch error.code {
            case NSURLErrorNotConnectedToInternet,
                 NSURLErrorNetworkConnectionLost:
                return .networkUnavailable
            case NSURLErrorTimedOut:
                return .networkTimeout
            default:
                return .networkError(error)
            }
        }
        
        return .unknown(error)
    }
    
    // MARK: - Error Handling
    
    /// エラーを処理してログに記録
    /// - Parameters:
    ///   - error: 処理するエラー
    ///   - context: エラーコンテキスト情報
    /// - Returns: EventFlowError
    @discardableResult
    func handle(
        _ error: Error,
        context: [String: Any] = [:]
    ) -> EventFlowError {
        let eventFlowError = convertToEventFlowError(error)
        
        // エラーをログに記録
        logger.log(error: eventFlowError, context: context)
        
        #if DEBUG
        print("🔴 Error handled: \(eventFlowError.localizedDescription)")
        if let suggestion = eventFlowError.recoverySuggestion {
            print("💡 Suggestion: \(suggestion)")
        }
        #endif
        
        return eventFlowError
    }
    
    /// エラーを処理してリトライ可能かチェック
    /// - Parameters:
    ///   - error: 処理するエラー
    ///   - context: エラーコンテキスト情報
    /// - Returns: (EventFlowError, isRetryable)
    func handleWithRetryCheck(
        _ error: Error,
        context: [String: Any] = [:]
    ) -> (error: EventFlowError, isRetryable: Bool) {
        let eventFlowError = handle(error, context: context)
        return (eventFlowError, eventFlowError.isRetryable)
    }
    
    // MARK: - User-Friendly Messages
    
    /// ユーザーフレンドリーなエラーメッセージを取得
    /// - Parameter error: エラー
    /// - Returns: ユーザー向けメッセージ
    func getUserFriendlyMessage(for error: Error) -> String {
        let eventFlowError = convertToEventFlowError(error)
        return eventFlowError.localizedDescription
    }
    
    /// エラーの復旧提案を取得
    /// - Parameter error: エラー
    /// - Returns: 復旧提案メッセージ
    func getRecoverySuggestion(for error: Error) -> String? {
        let eventFlowError = convertToEventFlowError(error)
        return eventFlowError.recoverySuggestion
    }
}

// MARK: - Error Context Builder

/// エラーコンテキスト情報を構築するヘルパー
struct ErrorContext {
    private var context: [String: Any] = [:]
    
    init() {}
    
    mutating func add(key: String, value: Any) {
        context[key] = value
    }
    
    mutating func addEventId(_ eventId: String) {
        context["eventId"] = eventId
    }
    
    mutating func addTaskId(_ taskId: String) {
        context["taskId"] = taskId
    }
    
    mutating func addParticipantId(_ participantId: String) {
        context["participantId"] = participantId
    }
    
    mutating func addOperation(_ operation: String) {
        context["operation"] = operation
    }
    
    mutating func addUserId(_ userId: String) {
        context["userId"] = userId
    }
    
    func build() -> [String: Any] {
        return context
    }
}
