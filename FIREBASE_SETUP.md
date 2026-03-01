# Firebase セットアップガイド

このドキュメントでは、EventFlowアプリにFirebaseを統合する手順を詳しく説明します。

## 前提条件

- Xcodeがインストールされていること（14.0以上推奨）
- Googleアカウントを持っていること
- インターネット接続があること

## ステップ1: Firebaseプロジェクトの作成

### 1.1 Firebase Consoleにアクセス

1. ブラウザで [Firebase Console](https://console.firebase.google.com/) を開く
2. Googleアカウントでログイン

### 1.2 新しいプロジェクトを作成

1. 「プロジェクトを追加」または「Create a project」をクリック
2. プロジェクト名を入力:
   - 例: `EventFlow` または `EventFlow-Dev`（開発用）
3. 「続行」をクリック
4. Google Analyticsの設定（オプション）:
   - 開発中は無効でも問題ありません
   - 本番環境では有効化を推奨
5. 「プロジェクトを作成」をクリック
6. プロジェクトの準備が完了するまで待つ（約30秒）

## ステップ2: iOSアプリの登録

### 2.1 アプリを追加

1. プロジェクトのダッシュボードで「iOSアプリを追加」をクリック
   - または、プロジェクト設定（⚙️アイコン）→「プロジェクトの設定」→「アプリを追加」
2. 「iOS」アイコンをクリック

### 2.2 バンドルIDの設定

1. **Apple バンドル ID**を入力:
   ```
   com.yourcompany.EventFlow
   ```
   - `yourcompany`を自分の組織名に置き換えてください
   - このIDはXcodeプロジェクトのBundle Identifierと**完全に一致**する必要があります

2. **アプリのニックネーム**（オプション）:
   ```
   EventFlow iOS
   ```

3. **App Store ID**（オプション）:
   - 開発中は空欄でOK
   - App Store公開時に追加可能

4. 「アプリを登録」をクリック

### 2.3 GoogleService-Info.plistのダウンロード

1. `GoogleService-Info.plist`ファイルをダウンロード
2. ダウンロードしたファイルを保存

**重要**: このファイルには機密情報が含まれています。安全に保管してください。

## ステップ3: XcodeプロジェクトへのGoogleService-Info.plistの追加

### 3.1 ファイルの配置

1. Xcodeでプロジェクトを開く
2. ダウンロードした`GoogleService-Info.plist`を以下の場所に配置:
   ```
   EventFlow/GoogleService-Info.plist
   ```
3. 既存のテンプレートファイルを置き換える

### 3.2 Xcodeプロジェクトに追加

1. Xcodeのプロジェクトナビゲーターで`EventFlow`フォルダを右クリック
2. 「Add Files to "EventFlow"...」を選択
3. `GoogleService-Info.plist`を選択
4. **重要**: 以下のオプションを確認:
   - ✅ "Copy items if needed"にチェック
   - ✅ "Add to targets"で`EventFlow`にチェック
5. 「Add」をクリック

### 3.3 確認

プロジェクトナビゲーターで`GoogleService-Info.plist`が表示されることを確認してください。

## ステップ4: Firebase SDKの追加（Swift Package Manager）

### 4.1 パッケージの追加

1. Xcodeで`File` → `Add Package Dependencies...`を選択
2. 検索バーに以下のURLを入力:
   ```
   https://github.com/firebase/firebase-ios-sdk.git
   ```
3. 「Add Package」をクリック

### 4.2 バージョンの選択

1. **Dependency Rule**を選択:
   - 「Up to Next Major Version」を選択
   - バージョン: `10.0.0`以上
2. 「Add Package」をクリック

### 4.3 プロダクトの選択

以下のプロダクトを選択してください:
- ✅ `FirebaseFirestore`
- ✅ `FirebaseAuth`

「Add Package」をクリックして完了。

### 4.4 ビルドの確認

1. `Command + B`でプロジェクトをビルド
2. エラーがないことを確認

## ステップ5: Firestoreデータベースの作成

### 5.1 Firestoreを有効化

1. Firebase Consoleで「Firestore Database」を選択
2. 「データベースを作成」をクリック

### 5.2 ロケーションの選択

1. **Cloud Firestoreのロケーション**を選択:
   - 推奨: `asia-northeast1` (東京)
   - または: `asia-northeast2` (大阪)
2. 「次へ」をクリック

**注意**: ロケーションは後から変更できません。

### 5.3 セキュリティルールの選択

開発中は「テストモードで開始」を選択:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.time < timestamp.date(2024, 12, 31);
    }
  }
}
```

**重要**: 本番環境では必ずセキュリティルールを設定してください（Task 1.3で実装）。

### 5.4 データベースの作成

「有効にする」をクリックして、データベースの作成を完了します。

## ステップ6: Firebase Authenticationの設定

### 6.1 Authenticationを有効化

1. Firebase Consoleで「Authentication」を選択
2. 「始める」をクリック

### 6.2 サインイン方法の設定

1. 「Sign-in method」タブを選択
2. 「匿名」を選択
3. 「有効にする」トグルをON
4. 「保存」をクリック

### 6.3 オプション: 追加のプロバイダー

本番環境では以下のプロバイダーを追加することを推奨:
- **Apple**: iOS必須（App Store審査要件）
- **Google**: 広く使用されている
- **メール/パスワード**: 基本的な認証

## ステップ7: 動作確認

### 7.1 アプリの実行

1. Xcodeでシミュレーターまたは実機を選択
2. `Command + R`でアプリを実行

### 7.2 コンソールログの確認

Xcodeのコンソールに以下のメッセージが表示されることを確認:
```
✅ Firestore initialized with offline persistence enabled
```

このメッセージが表示されれば、Firebaseの統合は成功です！

### 7.3 トラブルシューティング

#### エラー: "GoogleService-Info.plist not found"

**原因**: plistファイルがプロジェクトに正しく追加されていない

**解決方法**:
1. ステップ3を再度実行
2. ファイルがターゲットに含まれているか確認
3. クリーンビルド: `Command + Shift + K`

#### エラー: "Firebase/Core module not found"

**原因**: Firebase SDKが正しくインストールされていない

**解決方法**:
1. ステップ4を再度実行
2. Xcodeを再起動
3. Derived Dataを削除: `Xcode` → `Preferences` → `Locations` → `Derived Data`フォルダを開いて削除

#### エラー: "Bundle ID mismatch"

**原因**: XcodeのBundle IDとFirebaseのBundle IDが一致していない

**解決方法**:
1. Xcodeでプロジェクト設定を開く
2. `TARGETS` → `EventFlow` → `General` → `Bundle Identifier`を確認
3. Firebase Consoleのアプリ設定と一致させる

## ステップ8: セキュリティの確認

### 8.1 .gitignoreの確認

`GoogleService-Info.plist`がGitにコミットされないことを確認:

```bash
git status
```

`.gitignore`に以下が含まれていることを確認:
```
GoogleService-Info.plist
```

### 8.2 機密情報の保護

- `GoogleService-Info.plist`をGitHubなどの公開リポジトリにプッシュしない
- チームメンバーには個別にファイルを共有（Slack、メールなど）
- 本番環境と開発環境で異なるFirebaseプロジェクトを使用することを推奨

## ステップ9: Firestore Security Rulesのデプロイ

### 9.1 Firebase CLIのインストール

Security Rulesをデプロイするには、Firebase CLIが必要です。

#### macOSの場合（Homebrewを使用）:
```bash
brew install firebase-cli
```

#### npmを使用する場合:
```bash
npm install -g firebase-tools
```

### 9.2 Firebaseにログイン

```bash
firebase login
```

ブラウザが開き、Googleアカウントでログインを求められます。

### 9.3 Firebaseプロジェクトの初期化

プロジェクトのルートディレクトリで以下を実行:

```bash
firebase init firestore
```

以下の質問に答えます:
1. **既存のプロジェクトを使用しますか？**: `Use an existing project`を選択
2. **プロジェクトを選択**: 作成したFirebaseプロジェクトを選択
3. **Firestore Rulesファイル**: `firestore.rules`（デフォルトのまま Enter）
4. **Firestore Indexesファイル**: `firestore.indexes.json`（デフォルトのまま Enter）

### 9.4 Security Rulesのデプロイ

```bash
firebase deploy --only firestore:rules
```

成功すると、以下のようなメッセージが表示されます:
```
✔  Deploy complete!

Project Console: https://console.firebase.google.com/project/your-project-id/overview
```

### 9.5 Firebase Consoleでの確認

1. [Firebase Console](https://console.firebase.google.com/)を開く
2. プロジェクトを選択
3. 「Firestore Database」→「ルール」タブを選択
4. デプロイしたルールが表示されることを確認

### 9.6 Security Rulesの説明

デプロイされたルールは以下のセキュリティを提供します:

#### イベントドキュメント
- **読み取り**: 認証済みユーザーのみ
- **書き込み**: イベント作成者（organizerId）のみ

#### タスクサブコレクション
- **読み取り**: 誰でも可能（共有URL経由でアクセス可能）
- **書き込み**: イベント作成者のみ全操作可能
- **更新**: 参加者は`status`、`note`、`updatedAt`フィールドのみ更新可能

#### 参加者サブコレクション
- **読み取り**: 誰でも可能
- **作成**: 誰でも可能（参加者が自分を追加できる）
- **更新**: `paymentStatus`、`paidAmount`、`updatedAt`フィールドのみ更新可能
- **削除**: イベント作成者のみ

#### 買い物リストサブコレクション
- **読み取り**: 誰でも可能
- **書き込み**: イベント作成者のみ

### 9.7 ルールのテスト

Firebase Consoleでルールをテストできます:

1. 「Firestore Database」→「ルール」タブ
2. 「ルールプレイグラウンド」をクリック
3. テストシナリオを入力して動作を確認

#### テスト例1: 参加者がタスクステータスを更新
```
Location: /events/test-event-id/tasks/test-task-id
Operation: update
Authenticated: No
Data: { "status": "completed", "updatedAt": <timestamp> }
Expected: Allow
```

#### テスト例2: 未認証ユーザーがイベントを削除
```
Location: /events/test-event-id
Operation: delete
Authenticated: No
Expected: Deny
```

### 9.8 トラブルシューティング

#### エラー: "Permission denied"

**原因**: Firebase CLIがログインしていない、または権限がない

**解決方法**:
```bash
firebase logout
firebase login
```

#### エラー: "Project not found"

**原因**: プロジェクトIDが正しくない

**解決方法**:
1. `.firebaserc`ファイルを確認
2. 正しいプロジェクトIDが設定されているか確認
3. 必要に応じて`firebase use <project-id>`で切り替え

#### ルールが反映されない

**原因**: デプロイ後、反映に数秒かかる場合がある

**解決方法**:
1. 数秒待ってから再試行
2. Firebase Consoleでルールが更新されているか確認
3. アプリを再起動

## 次のステップ

Firebase統合とSecurity Rulesの設定が完了しました！次は以下のタスクに進んでください:

- [x] Task 1.3: Firestore Security Rulesの実装 ✅
- [ ] Task 2.1: Swiftデータモデルの作成
- [ ] Task 2.2: EventRepositoryの実装

## 参考リンク

- [Firebase iOS SDK ドキュメント](https://firebase.google.com/docs/ios/setup)
- [Firestore ドキュメント](https://firebase.google.com/docs/firestore)
- [Firebase Authentication ドキュメント](https://firebase.google.com/docs/auth)
- [Firebase Console](https://console.firebase.google.com/)

## サポート

問題が発生した場合は、以下を確認してください:
1. このドキュメントのトラブルシューティングセクション
2. Firebase公式ドキュメント
3. プロジェクトのREADME.md

---

**最終更新**: Task 1.2完了時
