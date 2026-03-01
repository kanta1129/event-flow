//
//  EventFlowError.swift
//  EventFlow
//
//  カスタムエラー型の定義
//  Requirements: 12.1, 12.2, 12.3
//

import Foundation

/// EventFlowアプリケーション全体で使用するエラー型
enum EventFlowError: LocalizedError {
    // MARK: - Network Errors
    case networkUnavailable
    case networkTimeout
    case networkError(Error)
    
    // MARK: - AI Errors
    case aiGenerationFailed
    case aiRateLimitExceeded(retryAfter: TimeInterval)
    case aiInvalidResponse
    case aiApiKeyInvalid
    
    // MARK: - Validation Errors
    case validationFailed(field: String, reason: String)
    case invalidEventData
    case invalidTaskData
    case invalidParticipantData
    
    // MARK: - Firestore Errors
    case firestoreOperationFailed(Error)
    case firestorePermissionDenied
    case firestoreDocumentNotFound
    case firestoreTimeout
    
    // MARK: - Authentication Errors
    case authenticationRequired
    case authenticationFailed(Error)
    case unauthorizedAccess
    
    // MARK: - General Errors
    case unknown(Error)
    case maxRetriesExceeded
    
    // MARK: - LocalizedError Implementation
    
    var errorDescription: String? {
        switch self {
        // Network Errors
        case .networkUnavailable:
            return NSLocalizedString(
                "error.network.unavailable",
                comment: "Network unavailable error"
            )
        case .networkTimeout:
            return NSLocalizedString(
                "error.network.timeout",
                comment: "Network timeout error"
            )
        case .networkError(let error):
            return String(
                format: NSLocalizedString(
                    "error.network.general",
                    comment: "General network error"
                ),
                error.localizedDescription
            )
            
        // AI Errors
        case .aiGenerationFailed:
            return NSLocalizedString(
                "error.ai.generation_failed",
                comment: "AI generation failed error"
            )
        case .aiRateLimitExceeded(let seconds):
            return String(
                format: NSLocalizedString(
                    "error.ai.rate_limit",
                    comment: "AI rate limit error"
                ),
                Int(seconds)
            )
        case .aiInvalidResponse:
            return NSLocalizedString(
                "error.ai.invalid_response",
                comment: "AI invalid response error"
            )
        case .aiApiKeyInvalid:
            return NSLocalizedString(
                "error.ai.api_key_invalid",
                comment: "AI API key invalid error"
            )
            
        // Validation Errors
        case .validationFailed(let field, let reason):
            return String(
                format: NSLocalizedString(
                    "error.validation.failed",
                    comment: "Validation failed error"
                ),
                field,
                reason
            )
        case .invalidEventData:
            return NSLocalizedString(
                "error.validation.invalid_event",
                comment: "Invalid event data error"
            )
        case .invalidTaskData:
            return NSLocalizedString(
                "error.validation.invalid_task",
                comment: "Invalid task data error"
            )
        case .invalidParticipantData:
            return NSLocalizedString(
                "error.validation.invalid_participant",
                comment: "Invalid participant data error"
            )
            
        // Firestore Errors
        case .firestoreOperationFailed(let error):
            return String(
                format: NSLocalizedString(
                    "error.firestore.operation_failed",
                    comment: "Firestore operation failed error"
                ),
                error.localizedDescription
            )
        case .firestorePermissionDenied:
            return NSLocalizedString(
                "error.firestore.permission_denied",
                comment: "Firestore permission denied error"
            )
        case .firestoreDocumentNotFound:
            return NSLocalizedString(
                "error.firestore.document_not_found",
                comment: "Firestore document not found error"
            )
        case .firestoreTimeout:
            return NSLocalizedString(
                "error.firestore.timeout",
                comment: "Firestore timeout error"
            )
            
        // Authentication Errors
        case .authenticationRequired:
            return NSLocalizedString(
                "error.auth.required",
                comment: "Authentication required error"
            )
        case .authenticationFailed(let error):
            return String(
                format: NSLocalizedString(
                    "error.auth.failed",
                    comment: "Authentication failed error"
                ),
                error.localizedDescription
            )
        case .unauthorizedAccess:
            return NSLocalizedString(
                "error.auth.unauthorized",
                comment: "Unauthorized access error"
            )
            
        // General Errors
        case .unknown(let error):
            return String(
                format: NSLocalizedString(
                    "error.general.unknown",
                    comment: "Unknown error"
                ),
                error.localizedDescription
            )
        case .maxRetriesExceeded:
            return NSLocalizedString(
                "error.general.max_retries",
                comment: "Max retries exceeded error"
            )
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable, .networkTimeout:
            return NSLocalizedString(
                "error.recovery.check_connection",
                comment: "Check connection recovery suggestion"
            )
        case .aiRateLimitExceeded:
            return NSLocalizedString(
                "error.recovery.wait_and_retry",
                comment: "Wait and retry recovery suggestion"
            )
        case .aiGenerationFailed, .aiInvalidResponse:
            return NSLocalizedString(
                "error.recovery.retry",
                comment: "Retry recovery suggestion"
            )
        case .firestorePermissionDenied, .unauthorizedAccess:
            return NSLocalizedString(
                "error.recovery.check_permissions",
                comment: "Check permissions recovery suggestion"
            )
        case .authenticationRequired:
            return NSLocalizedString(
                "error.recovery.login",
                comment: "Login recovery suggestion"
            )
        default:
            return NSLocalizedString(
                "error.recovery.try_again",
                comment: "Try again recovery suggestion"
            )
        }
    }
    
    /// エラーが再試行可能かどうか
    var isRetryable: Bool {
        switch self {
        case .networkUnavailable, .networkTimeout, .networkError,
             .aiGenerationFailed, .aiInvalidResponse,
             .firestoreOperationFailed, .firestoreTimeout:
            return true
        case .aiRateLimitExceeded:
            return true
        case .aiApiKeyInvalid, .firestorePermissionDenied,
             .authenticationRequired, .unauthorizedAccess,
             .validationFailed, .invalidEventData, .invalidTaskData,
             .invalidParticipantData, .firestoreDocumentNotFound:
            return false
        case .authenticationFailed, .unknown, .maxRetriesExceeded:
            return false
        }
    }
}
