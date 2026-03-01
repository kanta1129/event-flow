# EventFlow Web Interface

参加者向けのWebインターフェースです。ブラウザからアクセスして、タスクの選択とステータス更新ができます。

## 機能

### 1. 参加者名入力
- 初回アクセス時に名前を入力
- LocalStorageに保存され、次回以降は自動入力

### 2. スワイプ式タスク選択
- タスクカードを左右にスワイプ
- 右スワイプ: タスクを引き受ける
- 左スワイプ: スキップして次のタスクへ
- デスクトップではマウスドラッグでも操作可能

### 3. ステータス更新パネル
- 自分が引き受けたタスクの一覧表示
- タスク完了チェックボックス
- メモの追加・編集
- 支払い完了ボタン

## セットアップ

### 1. Firebase設定

`app.js` の Firebase設定を更新してください：

```javascript
const firebaseConfig = {
    apiKey: "YOUR_API_KEY",
    authDomain: "YOUR_AUTH_DOMAIN",
    projectId: "YOUR_PROJECT_ID",
    storageBucket: "YOUR_STORAGE_BUCKET",
    messagingSenderId: "YOUR_MESSAGING_SENDER_ID",
    appId: "YOUR_APP_ID"
};
```

Firebase Console から取得した値を設定します。

### 2. ホスティング

#### Firebase Hosting（推奨）

```bash
# Firebase CLIをインストール
npm install -g firebase-tools

# ログイン
firebase login

# プロジェクトを初期化
firebase init hosting

# デプロイ
firebase deploy --only hosting
```

#### ローカルサーバー

開発時は簡易サーバーで動作確認できます：

```bash
# Python 3
python -m http.server 8000

# Node.js (http-server)
npx http-server -p 8000
```

ブラウザで `http://localhost:8000?eventId=YOUR_EVENT_ID` にアクセス

## URL形式

```
https://your-domain.com/?eventId=EVENT_ID
```

- `eventId`: イベントの一意なID（iOS Appで生成）

## ファイル構成

```
web/
├── index.html      # メインHTMLファイル
├── styles.css      # スタイルシート（モバイルファースト）
├── app.js          # アプリケーションロジック
└── README.md       # このファイル
```

## 技術スタック

- **HTML5**: セマンティックマークアップ
- **CSS3**: モバイルファーストデザイン、Flexbox、アニメーション
- **JavaScript (ES6+)**: バニラJS（フレームワーク不使用）
- **Firebase Web SDK**: Firestore リアルタイムデータベース

## ブラウザサポート

- iOS Safari 14+
- Chrome 90+
- Firefox 88+
- Edge 90+

## パフォーマンス

- 初回ロード: 3秒以内（標準的なモバイルネットワーク）
- Firestore更新: 1秒以内
- リアルタイム同期: 2秒以内

## セキュリティ

- Firestore Security Rulesで保護
- HTTPS必須
- イベントIDベースのアクセス制御

## トラブルシューティング

### Firebase接続エラー

1. `app.js` の設定が正しいか確認
2. Firebaseプロジェクトが有効か確認
3. ブラウザのコンソールでエラーを確認

### タスクが表示されない

1. URLに正しい `eventId` が含まれているか確認
2. Firestore Security Rulesが正しく設定されているか確認
3. イベントにタスクが存在するか確認

### スワイプが動作しない

1. ブラウザがタッチイベントをサポートしているか確認
2. デスクトップではマウスドラッグを使用
3. JavaScriptエラーがないか確認

## 開発

### デバッグモード

ブラウザの開発者ツールを開いて、コンソールログを確認：

```javascript
console.log('Firebase initialized successfully');
console.log('App initialized with eventId:', currentEventId);
```

### カスタマイズ

#### カラーテーマ

`styles.css` の `:root` セクションでカラー変数を変更：

```css
:root {
    --primary-color: #4A90E2;
    --success-color: #5CB85C;
    /* ... */
}
```

#### アニメーション速度

```css
:root {
    --transition-fast: 0.2s ease;
    --transition-normal: 0.3s ease;
    --transition-slow: 0.5s ease;
}
```

## ライセンス

このプロジェクトはEventFlowアプリケーションの一部です。
