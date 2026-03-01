# Gemini API セットアップガイド

## 概要

EventFlowアプリは、Google Gemini APIを使用してイベントテンプレートと催促メッセージを自動生成します。このガイドでは、Gemini APIキーの取得と設定方法を説明します。

## APIキーの取得

1. [Google AI Studio](https://makersuite.google.com/app/apikey) にアクセス
2. Googleアカウントでログイン
3. "Get API Key" または "APIキーを取得" をクリック
4. 新しいAPIキーを作成
5. APIキーをコピーして安全な場所に保存

## APIキーの設定方法

### 方法1: 環境変数を使用（推奨）

環境変数を使用することで、APIキーをコードに直接書き込まずに管理できます。

#### Xcodeでの設定

1. Xcodeでプロジェクトを開く
2. Product > Scheme > Edit Scheme を選択
3. Run > Arguments タブを選択
4. Environment Variables セクションで "+" をクリック
5. 以下を追加：
   - Name: `GEMINI_API_KEY`
   - Value: `あなたのAPIキー`

#### コードでの使用例

```swift
let apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? ""
let geminiService = GeminiService(apiKey: apiKey)
```

### 方法2: 設定ファイルを使用

APIキーを設定ファイルに保存する方法です。

1. プロジェクトに `Config.plist` ファイルを作成
2. 以下の内容を追加：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>GeminiAPIKey</key>
    <string>あなたのAPIキー</string>
</dict>
</plist>
```

3. `.gitignore` に `Config.plist` を追加（APIキーをGitにコミットしないため）

#### コードでの使用例

```swift
func loadAPIKey() -> String {
    guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
          let config = NSDictionary(contentsOfFile: path),
          let apiKey = config["GeminiAPIKey"] as? String else {
        return ""
    }
    return apiKey
}

let apiKey = loadAPIKey()
let geminiService = GeminiService(apiKey: apiKey)
```

### 方法3: 開発時のみハードコード（非推奨）

**警告**: この方法は開発時のテストのみに使用し、本番環境では絶対に使用しないでください。

```swift
let apiKey = "YOUR_API_KEY_HERE" // 本番環境では使用しないこと！
let geminiService = GeminiService(apiKey: apiKey)
```

## 使用例

### イベントテンプレートの生成

```swift
let geminiService = GeminiService(apiKey: apiKey)

Task {
    do {
        let template = try await geminiService.generateEventTemplate(
            eventType: "BBQ",
            participantCount: 10,
            budget: 5000
        )
        
        print("買い物リスト:")
        for item in template.shoppingList {
            print("- \(item.item): \(item.quantity) (約\(item.estimatedCost)円)")
        }
        
        print("\nタスク:")
        for task in template.tasks {
            print("- \(task.title) [\(task.priority)]")
        }
        
        print("\nスケジュール:")
        for schedule in template.schedule {
            print("- \(schedule.time): \(schedule.activity)")
        }
    } catch let error as AIError {
        print("エラー: \(error.errorDescription ?? "不明なエラー")")
    }
}
```

### 催促メッセージの生成

```swift
let context = ReminderContext(
    participantName: "田中さん",
    eventDate: Date(),
    incompleteTasks: ["飲み物の買い出し"],
    isPaymentUnpaid: false
)

Task {
    do {
        let message = try await geminiService.generateReminderMessage(context: context)
        print("催促メッセージ:\n\(message)")
    } catch let error as AIError {
        print("エラー: \(error.errorDescription ?? "不明なエラー")")
    }
}
```

## エラーハンドリング

GeminiServiceは以下のエラーを返す可能性があります：

- `networkError`: ネットワーク接続エラー
- `rateLimitExceeded`: APIレート制限超過（自動リトライあり）
- `invalidResponse`: APIレスポンスの解析エラー
- `apiKeyInvalid`: APIキーが無効または認証エラー
- `jsonParsingError`: JSON解析エラー
- `maxRetriesExceeded`: 最大再試行回数超過

すべてのエラーは `LocalizedError` プロトコルに準拠しており、`errorDescription` プロパティで日本語のエラーメッセージを取得できます。

## リトライロジック

GeminiServiceは自動的に以下のリトライロジックを実装しています：

- 最大3回まで再試行
- 指数バックオフ（1秒、2秒、4秒）
- レート制限エラーの場合は `Retry-After` ヘッダーに従って待機

## セキュリティのベストプラクティス

1. **APIキーをコードに直接書き込まない**
2. **APIキーをGitリポジトリにコミットしない**
3. **環境変数または設定ファイルを使用する**
4. **設定ファイルを `.gitignore` に追加する**
5. **本番環境では環境変数を使用する**

## トラブルシューティング

### "AI接続に問題があります" エラー

- APIキーが正しく設定されているか確認
- APIキーが有効か確認（Google AI Studioで確認）
- ネットワーク接続を確認

### "AI生成の制限に達しました" エラー

- Gemini APIの無料枠の制限に達した可能性があります
- しばらく待ってから再試行してください
- 必要に応じて有料プランへのアップグレードを検討してください

### "AIの応答を解析できませんでした" エラー

- Gemini APIのレスポンス形式が期待と異なる可能性があります
- プロンプトを調整してみてください
- もう一度試してみてください（AIの応答は毎回異なります）

## 参考リンク

- [Google AI Studio](https://makersuite.google.com/)
- [Gemini API Documentation](https://ai.google.dev/docs)
- [API Pricing](https://ai.google.dev/pricing)
