# エラーハンドリングシステム

EventFlowアプリケーションのエラーハンドリングシステムの使用方法を説明します。

## 概要

このエラーハンドリングシステムは、以下の要件を満たすために設計されています：

- **Requirements 12.1**: ネットワーク接続エラーの明確なメッセージ表示
- **Requirements 12.2**: Gemini APIエラーの明確なメッセージ表示
- **Requirements 12.3**: Firestoreエラーの明確なメッセージ表示とリトライオプション
- **Requirements 12.5**: デバッグ用のエラーロギング

## コンポーネント

### 1. EventFlowError.swift

アプリケーション全体で使用する統一されたエラー型です。

```swift
// 使用例
throw EventFlowError.networkUnavailable
throw EventFlowError.aiGenerationFailed
throw EventFlowError.validationFailed(field: "eventTitle", reason: "空です")
```

**主なエラータイプ:**
- ネットワークエラー: `networkUnavailable`, `networkTimeout`, `networkError`
- AIエラー: `aiGenerationFailed`, `aiRateLimitExceeded`, `aiInvalidResponse`
- バリデーションエラー: `validationFailed`, `invalidEventData`
- Firestoreエラー: `firestoreOperationFailed`, `firestorePermissionDenied`
- 認証エラー: `authenticationRequired`, `unauthorizedAccess`

### 2. RetryPolicy.swift

指数バックオフによるリトライロジックを提供します。

```swift
// 使用例1: デフォルトポリシーでリトライ
let result = try await RetryExecutor.execute {
    try await someNetworkOperation()
}

// 使用例2: カスタムポリシーでリトライ
let customPolicy = RetryPolicy(
    maxRetries: 5,
    initialDelay: 0.5,
    multiplier: 2.0,
    maxDelay: 60.0
)

let result = try await RetryExecutor.execute(policy: customPolicy) {
    try await someOperation()
}

// 使用例3: レート制限を考慮したリトライ
let result = try await RetryExecutor.executeWithRateLimit {
    try await geminiService.generateTemplate(...)
}
```

**プリセットポリシー:**
- `.default`: 3回リトライ、1秒から開始、最大30秒
- `.aggressive`: 5回リトライ、0.5秒から開始、最大60秒
- `.conservative`: 2回リトライ、2秒から開始、最大20秒

### 3. ErrorHandler.swift

エラーの変換、処理、ユーザーフレンドリーなメッセージ生成を行います。

```swift
// 使用例1: エラーを処理してログに記録
do {
    try await repository.updateEvent(event)
} catch {
    let eventFlowError = ErrorHandler.shared.handle(
        error,
        context: ["eventId": event.id, "operation": "update"]
    )
    // eventFlowErrorを使用してUIにエラーを表示
}

// 使用例2: リトライ可能かチェック
do {
    try await someOperation()
} catch {
    let (error, isRetryable) = ErrorHandler.shared.handleWithRetryCheck(error)
    if isRetryable {
        // リトライボタンを表示
    }
}

// 使用例3: ユーザーフレンドリーなメッセージを取得
let message = ErrorHandler.shared.getUserFriendlyMessage(for: error)
let suggestion = ErrorHandler.shared.getRecoverySuggestion(for: error)
```

### 4. ErrorLogger.swift

Firebase Crashlyticsを使用したエラーロギングを提供します。

```swift
// 使用例1: エラーをログに記録
ErrorLogger.shared.log(
    error: error,
    context: [
        "eventId": eventId,
        "operation": "createEvent",
        "userId": userId
    ]
)

// 使用例2: メッセージをログに記録
ErrorLogger.shared.logMessage("Event creation started", level: .info)
ErrorLogger.shared.logMessage("Critical error occurred", level: .critical)

// 使用例3: ユーザーIDを設定
ErrorLogger.shared.setUserId(userId)

// 使用例4: カスタム値を設定
ErrorLogger.shared.setCustomValue("premium", forKey: "userTier")

// 使用例5: 古いログをクリーンアップ
ErrorLogger.shared.cleanupOldLogs(olderThan: 7)
```

### 5. Localizable.strings

エラーメッセージの多言語対応（日本語・英語）を提供します。

ローカライズされたメッセージは自動的に使用されます：

```swift
let error = EventFlowError.networkUnavailable
print(error.localizedDescription)
// 日本語: "ネットワーク接続がありません。インターネット接続を確認してください。"
// 英語: "No network connection available. Please check your internet connection."
```

## 実装パターン

### パターン1: ViewModelでのエラーハンドリング

```swift
class EventViewModel: ObservableObject {
    @Published var error: EventFlowError?
    @Published var isLoading = false
    
    func createEvent(_ event: Event) async {
        isLoading = true
        error = nil
        
        do {
            try await RetryExecutor.execute {
                try await repository.createEvent(event)
            }
            // 成功処理
        } catch {
            self.error = ErrorHandler.shared.handle(
                error,
                context: ["operation": "createEvent"]
            )
        }
        
        isLoading = false
    }
}
```

### パターン2: Viewでのエラー表示

```swift
struct EventCreationView: View {
    @StateObject private var viewModel = EventViewModel()
    
    var body: some View {
        VStack {
            // UI要素
        }
        .alert(
            "エラー",
            isPresented: .constant(viewModel.error != nil),
            presenting: viewModel.error
        ) { error in
            if error.isRetryable {
                Button("再試行") {
                    Task {
                        await viewModel.createEvent(event)
                    }
                }
            }
            Button("OK") {
                viewModel.error = nil
            }
        } message: { error in
            VStack(alignment: .leading) {
                Text(error.localizedDescription)
                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(.caption)
                }
            }
        }
    }
}
```

### パターン3: Repositoryでのエラーハンドリング

```swift
class FirestoreEventRepository: EventRepository {
    func updateEvent(_ event: Event) async throws {
        // ネットワーク接続をチェック
        if !NetworkMonitor.shared.isConnected {
            throw EventFlowError.networkUnavailable
        }
        
        do {
            try await RetryExecutor.execute(policy: .default) {
                try await performFirestoreUpdate(event)
            }
        } catch let error as EventFlowError {
            // EventFlowErrorはそのままスロー
            throw error
        } catch {
            // その他のエラーはEventFlowErrorに変換
            throw ErrorHandler.shared.convertToEventFlowError(error)
        }
    }
}
```

### パターン4: エラーコンテキストの構築

```swift
var context = ErrorContext()
context.addEventId(event.id)
context.addOperation("updateEvent")
context.addUserId(currentUserId)
context.add(key: "participantCount", value: event.participantCount)

ErrorLogger.shared.log(error: error, context: context.build())
```

## ベストプラクティス

### 1. エラーの変換

常に汎用エラーをEventFlowErrorに変換してください：

```swift
// ❌ 悪い例
catch {
    throw error  // 汎用エラーをそのままスロー
}

// ✅ 良い例
catch {
    throw ErrorHandler.shared.convertToEventFlowError(error)
}
```

### 2. エラーのログ記録

重要な操作では必ずエラーをログに記録してください：

```swift
do {
    try await criticalOperation()
} catch {
    let eventFlowError = ErrorHandler.shared.handle(
        error,
        context: ["operation": "criticalOperation"]
    )
    throw eventFlowError
}
```

### 3. リトライロジック

ネットワーク操作には必ずリトライロジックを使用してください：

```swift
// ✅ 良い例
try await RetryExecutor.execute {
    try await networkOperation()
}

// ❌ 悪い例
try await networkOperation()  // リトライなし
```

### 4. ユーザーへのフィードバック

エラーメッセージと復旧提案を必ず表示してください：

```swift
// ✅ 良い例
Text(error.localizedDescription)
if let suggestion = error.recoverySuggestion {
    Text(suggestion)
}

// ❌ 悪い例
Text("エラーが発生しました")  // 詳細なし
```

## テスト

### エラーハンドリングのテスト例

```swift
func testNetworkErrorHandling() async throws {
    // モックリポジトリでネットワークエラーをシミュレート
    let mockRepo = MockEventRepository()
    mockRepo.shouldFailWithNetworkError = true
    
    let viewModel = EventViewModel(repository: mockRepo)
    
    await viewModel.createEvent(testEvent)
    
    XCTAssertNotNil(viewModel.error)
    XCTAssertTrue(viewModel.error?.isRetryable ?? false)
}

func testRetryLogic() async throws {
    var attemptCount = 0
    
    let result = try await RetryExecutor.execute(policy: .default) {
        attemptCount += 1
        if attemptCount < 3 {
            throw EventFlowError.networkTimeout
        }
        return "success"
    }
    
    XCTAssertEqual(result, "success")
    XCTAssertEqual(attemptCount, 3)
}
```

## トラブルシューティング

### ログファイルの確認

ローカルログファイルは以下の場所に保存されます：

```
Documents/Logs/
├── error_log_2024-01-15.json
├── message_log_2024-01-15.txt
└── ...
```

### Firebase Crashlyticsでの確認

1. Firebase Consoleにアクセス
2. Crashlyticsセクションを開く
3. カスタムキーでフィルタリング可能

### デバッグモード

デバッグビルドでは、すべてのエラーがコンソールに詳細に出力されます：

```
🔴 Error handled: ネットワーク接続がありません
💡 Suggestion: インターネット接続を確認して、もう一度お試しください
```

## まとめ

このエラーハンドリングシステムを使用することで：

- ✅ 統一されたエラー処理
- ✅ ユーザーフレンドリーなエラーメッセージ
- ✅ 自動リトライロジック
- ✅ 包括的なエラーロギング
- ✅ 多言語対応

が実現されます。
