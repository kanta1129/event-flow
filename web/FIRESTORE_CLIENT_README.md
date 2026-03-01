# FirestoreClient クラス

## 概要

FirestoreClientは、EventFlow Web InterfaceでFirestoreデータベース操作を管理するクライアントクラスです。

## 機能

- Firestore初期化
- タスクのリアルタイム監視
- タスクの引き受け（claim）
- タスクステータスの更新
- 支払いステータスの更新
- 参加者の管理

## 使用方法

### 初期化

```javascript
// イベントIDを指定してインスタンスを作成
const firestoreClient = new FirestoreClient('event-id-123');

// または、Firebase設定を渡して初期化
const firestoreClient = new FirestoreClient('event-id-123', firebaseConfig);
```

### タスクのリアルタイム監視

```javascript
firestoreClient.observeTasks(
    (tasks) => {
        console.log('タスクが更新されました:', tasks);
        // タスクを表示する処理
    },
    (error) => {
        console.error('エラー:', error);
    }
);
```

### タスクの引き受け

```javascript
await firestoreClient.claimTask('task-id', '参加者名');
```

### タスクステータスの更新

```javascript
// ステータスのみ更新
await firestoreClient.updateTaskStatus('task-id', 'completed');

// ステータスとメモを更新
await firestoreClient.updateTaskStatus('task-id', 'in_progress', 'メモ内容');

// メモのみ更新
await firestoreClient.updateTaskStatus('task-id', null, 'メモ内容');
```

### 支払いステータスの更新

```javascript
await firestoreClient.updatePaymentStatus('参加者名', 'paid');
```

### 参加者の追加

```javascript
// 参加者が存在しない場合のみ追加
const wasCreated = await firestoreClient.addParticipantIfNotExists('参加者名');
```

### 参加者のタスクを取得

```javascript
const tasks = await firestoreClient.getParticipantTasks('参加者名');
```

### 参加者情報を取得

```javascript
const participant = await firestoreClient.getParticipant('参加者名');
if (participant) {
    console.log('支払い額:', participant.expectedPayment);
    console.log('支払いステータス:', participant.paymentStatus);
}
```

### 単一のタスクを取得

```javascript
const task = await firestoreClient.getTask('task-id');
if (task) {
    console.log('タスク名:', task.title);
    console.log('ステータス:', task.status);
}
```

### クリーンアップ

```javascript
// すべてのリスナーを解除
firestoreClient.cleanup();
```

## エラーハンドリング

すべての非同期メソッドはエラーをスローする可能性があります。try-catchブロックで適切に処理してください。

```javascript
try {
    await firestoreClient.claimTask('task-id', '参加者名');
    console.log('タスクを引き受けました');
} catch (error) {
    console.error('エラー:', error.message);
    // ユーザーにエラーメッセージを表示
}
```

## データ構造

### Task

```javascript
{
    id: string,
    title: string,
    description: string,
    priority: 'high' | 'medium' | 'low',
    status: 'unassigned' | 'assigned' | 'in_progress' | 'completed',
    assignedTo: string | null,
    note: string | null,
    createdAt: Timestamp,
    updatedAt: Timestamp
}
```

### Participant

```javascript
{
    id: string,
    name: string,
    expectedPayment: number,
    paymentStatus: 'paid' | 'unpaid',
    paidAmount: number,
    joinedAt: Timestamp,
    updatedAt: Timestamp
}
```

## 要件との対応

このクラスは以下の要件を実装しています：

- **Requirements 4.4**: タスク割り当て時のFirestore更新（1秒以内）
- **Requirements 6.4**: ステータス更新時のFirestore保存（1秒以内）

## 設計ドキュメントとの対応

このクラスは `design.md` の「Web Interface コンポーネント」セクションで定義されたFirestoreClientの仕様に基づいて実装されています。
