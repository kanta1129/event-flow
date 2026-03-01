# EventFlow - イベント幹事支援アプリ

EventFlowは、イベント幹事の負担を劇的に軽減するiOSアプリケーションです。「企画から集金まで、幹事の頭の中をすべて可視化するコマンドセンター」をコンセプトに、AIによる自動化、参加者の巻き込み、リアルタイムステータス管理を実現します。

## 主な機能

- 🤖 **AIによるイベントテンプレート生成**: Gemini APIを使用して、イベントタイプと参加者数から自動的に買い物リスト、タスク、スケジュールを生成
- 📱 **クロスプラットフォーム**: iOS App（幹事用）+ Web Interface（参加者用）
- 🔄 **リアルタイム同期**: Firebase Firestoreによる即座のデータ同期
- 👥 **参加者の巻き込み**: スワイプ式のタスク選択で参加者が簡単にタスクを引き受け可能
- 💰 **集金トラッキング**: 支払い状況のリアルタイム管理
- 📊 **進捗可視化**: タスクと支払いの完了状況を一目で確認

## 技術スタック

- **iOS App**: SwiftUI + Combine
- **Backend**: Firebase Firestore + Firebase Authentication
- **AI**: Google Gemini API
- **Web Interface**: HTML/CSS/JavaScript（軽量、フレームワークレス）

## セットアップ

### 前提条件

- Xcode 14.0以上
- iOS 16.0以上
- Googleアカウント（Firebase用）
- Firebase CLI（Security Rulesのデプロイ用）

### インストール手順

詳細なセットアップ手順は[FIREBASE_SETUP.md](FIREBASE_SETUP.md)を参照してください。

1. **Firebaseプロジェクトの作成**
2. **iOSアプリの登録とGoogleService-Info.plistのダウンロード**
3. **Firebase SDKの追加**
4. **Firestoreデータベースの作成**
5. **Firebase Authenticationの設定**
6. **Firestore Security Rulesのデプロイ**

## Firestore Security Rules

EventFlowは、以下のセキュリティルールを実装しています：

### イベントドキュメント (`/events/{eventId}`)

- **読み取り**: 認証済みユーザーのみ
- **書き込み**: イベント作成者（`organizerId`）のみ

### タスクサブコレクション (`/events/{eventId}/tasks/{taskId}`)

- **読み取り**: 誰でも可能（共有URL経由でアクセス可能）
- **書き込み**: イベント作成者のみ全操作可能
- **更新**: 参加者は以下のフィールドのみ更新可能
  - `status`: タスクのステータス（未着手、進行中、完了）
  - `note`: タスクに関するメモ
  - `updatedAt`: 更新日時

### 参加者サブコレクション (`/events/{eventId}/participants/{participantId}`)

- **読み取り**: 誰でも可能
- **作成**: 誰でも可能（参加者が自分を追加できる）
- **更新**: 以下のフィールドのみ更新可能
  - `paymentStatus`: 支払いステータス（未払い、支払い済み）
  - `paidAmount`: 支払い済み金額
  - `updatedAt`: 更新日時
- **削除**: イベント作成者のみ

### 買い物リストサブコレクション (`/events/{eventId}/shoppingList/{itemId}`)

- **読み取り**: 誰でも可能
- **書き込み**: イベント作成者のみ

### Security Rulesのデプロイ

```bash
# Firebase CLIのインストール（初回のみ）
npm install -g firebase-tools

# Firebaseにログイン
firebase login

# Firestoreの初期化（初回のみ）
firebase init firestore

# Security Rulesのデプロイ
firebase deploy --only firestore:rules
```

詳細は[FIREBASE_SETUP.md](FIREBASE_SETUP.md)の「ステップ9: Firestore Security Rulesのデプロイ」を参照してください。

## プロジェクト構造

```
EventFlow/
├── EventFlow/
│   ├── Models/           # データモデル（Event, Task, Participant等）
│   ├── ViewModels/       # ビジネスロジックと状態管理
│   ├── Views/            # SwiftUI Views
│   ├── Repositories/     # データアクセス層（Firestore操作）
│   ├── Services/         # 外部サービス統合（Gemini API等）
│   └── EventFlowApp.swift
├── firestore.rules       # Firestore Security Rules
├── firestore.indexes.json # Firestoreインデックス設定
├── firebase.json         # Firebase設定
├── FIREBASE_SETUP.md     # Firebase詳細セットアップガイド
└── README.md             # このファイル
```

## 開発状況

現在の実装状況は`.kiro/specs/event-flow/tasks.md`を参照してください。

### 完了したタスク

- ✅ Task 1.1: Xcodeプロジェクトの作成とSwiftUI基本構造のセットアップ
- ✅ Task 1.2: Firebase SDKの統合とFirestore初期化
- ✅ Task 1.3: Firestore Security Rulesの実装

### 次のステップ

- [ ] Task 2.1: Swiftデータモデルの作成
- [ ] Task 2.2: EventRepositoryの実装
- [ ] Task 4.1: GeminiServiceの実装

## セキュリティとプライバシー

- すべてのネットワーク通信はHTTPSを使用
- Firebase Authenticationによる認証
- Firestore Security Rulesによるアクセス制御
- `GoogleService-Info.plist`は`.gitignore`に含まれており、リポジトリにコミットされません

## ライセンス

このプロジェクトは開発中です。

## サポート

問題が発生した場合は、以下を確認してください：

1. [FIREBASE_SETUP.md](FIREBASE_SETUP.md)のトラブルシューティングセクション
2. Firebase公式ドキュメント
3. プロジェクトの仕様書（`.kiro/specs/event-flow/`）


