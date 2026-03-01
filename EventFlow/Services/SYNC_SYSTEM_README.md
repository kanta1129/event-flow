# ネットワーク再接続時の同期システム

## 概要

EventFlowアプリは、オフライン時でもデータ変更を記録し、ネットワーク再接続時に自動的にFirestoreと同期する機能を実装しています。

## コンポーネント

### 1. NetworkMonitor
- **役割**: ネットワーク接続状態をリアルタイムで監視
- **場所**: `EventFlow/Services/NetworkMonitor.swift`
- **機能**:
  - Network frameworkを使用してネットワーク状態を監視
  - 接続タイプの判定（WiFi、Cellular、Ethernet）
  - 再接続時に通知を送信

### 2. SyncManager
- **役割**: オフライン変更の同期と競合解決を管理
- **場所**: `EventFlow/Services/SyncManager.swift`
- **機能**:
  - 再接続時の自動同期
  - PendingChangeキューの処理
  - Last-write-wins競合解決戦略
  - 同期エラーハンドリング

### 3. LocalCacheManager
- **役割**: ローカルキャッシュとオフライン変更キューの管理
- **場所**: `EventFlow/Services/LocalCacheManager.swift`
- **機能**:
  - PendingChangeのキューイング
  - イベント、タスク、参加者のローカルキャッシュ
  - UserDefaultsを使用した永続化

### 4. RepositoryExtensions
- **役割**: リポジトリのオフライン対応を支援
- **場所**: `EventFlow/Repositories/RepositoryExtensions.swift`
- **機能**:
  - オフライン変更のキューイングヘルパー
  - データのシリアライゼーション

## 動作フロー

### オフライン時の変更

1. ユーザーがデータを変更（例: タスクのステータス更新）
2. Repository層でネットワーク状態をチェック
3. オフラインの場合:
   - 変更をPendingChangeとしてキューに追加
   - ローカルキャッシュを更新
   - ユーザーには即座に反映

```swift
// 例: タスク更新時
func updateTask(_ task: Task, eventId: String) async throws {
    if !NetworkMonitor.shared.isConnected {
        // オフライン時はキューに追加
        try queueOfflineChange(changeType: .update, task: task, eventId: eventId)
        return
    }
    // オンライン時は通常のFirestore更新
    // ...
}
```

### ネットワーク再接続時の同期

1. NetworkMonitorが再接続を検出
2. `.networkReconnected`通知を送信
3. SyncManagerが通知を受信
4. PendingChangeキューを取得
5. タイムスタンプ順にソート
6. 各変更を順次適用:
   - Firestoreから現在のデータを取得
   - updatedAtを比較（競合解決）
   - ローカルの変更が新しい場合のみ適用
7. 成功した変更をキューから削除

```swift
// 競合解決ロジック（last-write-wins）
let localUpdatedAt = (localData["updatedAt"] as? Timestamp)?.dateValue() ?? Date.distantPast
let remoteUpdatedAt = (remoteData["updatedAt"] as? Timestamp)?.dateValue() ?? Date.distantPast

if localUpdatedAt > remoteUpdatedAt {
    // ローカルの変更が新しい場合のみ適用
    try await docRef.setData(dataToWrite, merge: true)
}
```

## 競合解決戦略: Last-Write-Wins

### 原則
- 最新の`updatedAt`タイムスタンプを持つ変更を優先
- 古い変更は自動的にスキップ
- データの整合性を保証

### 例
1. ユーザーAがオフラインでタスクを更新（updatedAt: 10:00）
2. ユーザーBがオンラインで同じタスクを更新（updatedAt: 10:05）
3. ユーザーAが再接続
4. SyncManagerが競合を検出
5. ユーザーBの変更が新しいため、ユーザーAの変更はスキップ

## エラーハンドリング

### 同期エラーの種類
- `noConnection`: ネットワーク接続なし
- `syncFailed`: 同期処理の失敗
- `conflictResolutionFailed`: 競合解決の失敗
- `invalidChangeData`: 無効な変更データ

### エラー時の動作
- エラーが発生しても他の変更の同期を続行
- `SyncManager.syncError`プロパティでエラー状態を公開
- デバッグログで詳細を記録

## 使用方法

### アプリ起動時の初期化

```swift
// EventFlowApp.swift
@main
struct EventFlowApp: App {
    private let networkMonitor = NetworkMonitor.shared
    
    init() {
        FirebaseApp.configure()
        networkMonitor.startMonitoring()
    }
}
```

### 手動同期のトリガー

```swift
// 必要に応じて手動で同期を実行
await SyncManager.shared.syncPendingChanges()
```

### ネットワーク状態の監視

```swift
// NetworkMonitorを使用してネットワーク状態を確認
if NetworkMonitor.shared.isConnected {
    print("オンライン")
} else {
    print("オフライン")
}
```

## テスト

### ユニットテスト
- NetworkMonitorの状態変化テスト
- SyncManagerの競合解決ロジックテスト
- PendingChangeのキューイングテスト

### 統合テスト
- オフライン→オンライン復帰シナリオ
- 複数デバイスでの同時変更
- ネットワーク断続的な切断

## パフォーマンス考慮事項

### 最適化
- タイムスタンプ順にソートして古い変更から適用
- バッチ処理ではなく個別処理（エラー時の影響を最小化）
- 成功した変更は即座にキューから削除

### 制限事項
- UserDefaultsの容量制限（推奨: 1MB以下）
- 大量の変更がキューに溜まった場合の処理時間
- ネットワーク帯域幅の考慮

## 今後の改善案

1. **バッチ同期**: 複数の変更をまとめて送信
2. **優先度付きキュー**: 重要な変更を優先的に同期
3. **部分的な競合解決**: フィールドレベルでの競合解決
4. **同期進捗の表示**: UIで同期状態を表示
5. **リトライロジック**: 失敗した変更の自動リトライ

## 関連要件

- **Requirements 8.2**: オフライン時の変更キューイング
- **Requirements 8.3**: ネットワーク再接続時の自動同期
- **Property 21**: オフライン変更の同期検証

## 参考資料

- [Apple Network Framework](https://developer.apple.com/documentation/network)
- [Firebase Offline Capabilities](https://firebase.google.com/docs/firestore/manage-data/enable-offline)
- [Conflict Resolution Strategies](https://en.wikipedia.org/wiki/Conflict-free_replicated_data_type)
