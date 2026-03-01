//
//  RetryPolicy.swift
//  EventFlow
//
//  指数バックオフリトライロジックの実装
//  Requirements: 12.3
//

import Foundation

/// リトライポリシーの設定
struct RetryPolicy {
    /// 最大リトライ回数
    let maxRetries: Int
    
    /// 初期遅延時間（秒）
    let initialDelay: TimeInterval
    
    /// バックオフ乗数
    let multiplier: Double
    
    /// 最大遅延時間（秒）
    let maxDelay: TimeInterval
    
    /// デフォルトのリトライポリシー（指数バックオフ）
    static let `default` = RetryPolicy(
        maxRetries: 3,
        initialDelay: 1.0,
        multiplier: 2.0,
        maxDelay: 30.0
    )
    
    /// アグレッシブなリトライポリシー（より多くの試行）
    static let aggressive = RetryPolicy(
        maxRetries: 5,
        initialDelay: 0.5,
        multiplier: 2.0,
        maxDelay: 60.0
    )
    
    /// 控えめなリトライポリシー（少ない試行）
    static let conservative = RetryPolicy(
        maxRetries: 2,
        initialDelay: 2.0,
        multiplier: 3.0,
        maxDelay: 20.0
    )
    
    /// 指定された試行回数に対する遅延時間を計算
    /// - Parameter attempt: 試行回数（0から始まる）
    /// - Returns: 遅延時間（秒）
    func delay(for attempt: Int) -> TimeInterval {
        let exponentialDelay = initialDelay * pow(multiplier, Double(attempt))
        return min(exponentialDelay, maxDelay)
    }
}

/// リトライ可能な操作を実行するユーティリティ
struct RetryExecutor {
    
    /// リトライポリシーに従って操作を実行
    /// - Parameters:
    ///   - policy: リトライポリシー
    ///   - operation: 実行する非同期操作
    /// - Returns: 操作の結果
    /// - Throws: 最後に発生したエラー
    static func execute<T>(
        policy: RetryPolicy = .default,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 0...policy.maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                #if DEBUG
                print("⚠️ Retry attempt \(attempt + 1)/\(policy.maxRetries + 1) failed: \(error.localizedDescription)")
                #endif
                
                // 最後の試行の場合はエラーをスロー
                if attempt >= policy.maxRetries {
                    throw EventFlowError.maxRetriesExceeded
                }
                
                // エラーが再試行可能かチェック
                if let eventFlowError = error as? EventFlowError,
                   !eventFlowError.isRetryable {
                    #if DEBUG
                    print("❌ Error is not retryable, aborting")
                    #endif
                    throw error
                }
                
                // 指数バックオフで待機
                let delay = policy.delay(for: attempt)
                
                #if DEBUG
                print("⏳ Waiting \(delay) seconds before retry...")
                #endif
                
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        // この行には到達しないはずだが、コンパイラを満足させるため
        throw lastError ?? EventFlowError.maxRetriesExceeded
    }
    
    /// レート制限を考慮したリトライ実行
    /// - Parameters:
    ///   - policy: リトライポリシー
    ///   - operation: 実行する非同期操作
    /// - Returns: 操作の結果
    /// - Throws: 最後に発生したエラー
    static func executeWithRateLimit<T>(
        policy: RetryPolicy = .default,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 0...policy.maxRetries {
            do {
                return try await operation()
            } catch let error as EventFlowError {
                lastError = error
                
                // レート制限エラーの場合は指定された時間待機
                if case .aiRateLimitExceeded(let retryAfter) = error {
                    #if DEBUG
                    print("⏳ Rate limit exceeded, waiting \(retryAfter) seconds...")
                    #endif
                    
                    if attempt < policy.maxRetries {
                        try await Task.sleep(nanoseconds: UInt64(retryAfter * 1_000_000_000))
                        continue
                    } else {
                        throw error
                    }
                }
                
                // その他のエラーは通常のリトライロジックを適用
                if !error.isRetryable || attempt >= policy.maxRetries {
                    throw error
                }
                
                let delay = policy.delay(for: attempt)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
            } catch {
                lastError = error
                
                if attempt >= policy.maxRetries {
                    throw EventFlowError.maxRetriesExceeded
                }
                
                let delay = policy.delay(for: attempt)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        throw lastError ?? EventFlowError.maxRetriesExceeded
    }
}

/// リトライ可能な操作のラッパー
@propertyWrapper
struct Retryable<T> {
    private let policy: RetryPolicy
    private let operation: () async throws -> T
    
    var wrappedValue: T {
        get async throws {
            try await RetryExecutor.execute(policy: policy, operation: operation)
        }
    }
    
    init(
        policy: RetryPolicy = .default,
        operation: @escaping () async throws -> T
    ) {
        self.policy = policy
        self.operation = operation
    }
}
