# EventFlow iOS App

EventFlowは、イベント幹事の負担を軽減するiOSアプリケーションです。

## プロジェクト構造

```
EventFlow/
├── EventFlowApp.swift          # アプリのエントリーポイント
├── ContentView.swift            # 初期ビュー
├── Info.plist                   # アプリ設定（iOS 16.0+）
├── Models/                      # データモデル
├── ViewModels/                  # ビジネスロジックと状態管理
├── Views/                       # SwiftUI Views
├── Repositories/                # データアクセス層
└── Services/                    # 外部サービス統合

```

## 技術スタック

- **フレームワーク**: SwiftUI
- **最小iOS**: 16.0+
- **アーキテクチャ**: MVVM + Repository Pattern
- **バックエンド**: Firebase Firestore（後で統合）
- **AI**: Google Gemini API（後で統合）

## セットアップ手順

### 1. Xcodeプロジェクトの作成

このソースコードをXcodeプロジェクトに統合するには：

1. Xcodeを開く
2. "Create a new Xcode project"を選択
3. "iOS" → "App"を選択
4. プロジェクト設定:
   - Product Name: `EventFlow`
   - Interface: `SwiftUI`
   - Language: `Swift`
   - Minimum Deployments: `iOS 16.0`
5. このディレクトリのファイルをXcodeプロジェクトにドラッグ&ドロップ

### 2. Firebase SDKの統合

#### 2.1 Firebase Consoleでプロジェクトを作成

1. [Firebase Console](https://console.firebase.google.com/) にアクセス
2. 「プロジェクトを追加」をクリック
3. プロジェクト名を入力（例: `EventFlow`）
4. Google Analyticsの設定（オプション）
5. プロジェクトを作成

#### 2.2 iOSアプリをFirebaseプロジェクトに追加

1. Firebase Consoleでプロジェクトを開く
2. 「iOSアプリを追加」をクリック
3. バンドルIDを入力（例: `com.yourcompany.EventFlow`）
   - XcodeプロジェクトのBundle Identifierと一致させる必要があります
4. アプリのニックネームを入力（オプション）
5. 「アプリを登録」をクリック

#### 2.3 GoogleService-Info.plistをダウンロード

1. Firebase Consoleから`GoogleService-Info.plist`をダウンロード
2. ダウンロードしたファイルで`EventFlow/GoogleService-Info.plist`を置き換える
3. Xcodeでファイルをプロジェクトに追加（ターゲットに含める）

**重要**: `GoogleService-Info.plist`には機密情報が含まれています。Gitにコミットしないでください。

#### 2.4 Swift Package Managerで依存関係を追加

1. Xcodeでプロジェクトを開く
2. `File` → `Add Package Dependencies...`を選択
3. 以下のURLを入力:
   ```
   https://github.com/firebase/firebase-ios-sdk.git
   ```
4. バージョン: `10.0.0`以上を選択
5. 以下のパッケージを追加:
   - `FirebaseFirestore`
   - `FirebaseAuth`

#### 2.5 Firestoreデータベースを作成

1. Firebase Consoleで「Firestore Database」を選択
2. 「データベースを作成」をクリック
3. ロケーションを選択（例: `asia-northeast1` - 東京）
4. セキュリティルールを選択:
   - 開発中: 「テストモードで開始」
   - 本番環境: 「ロックモードで開始」（後でルールを設定）
5. 「有効にする」をクリック

#### 2.6 Firebase Authenticationを有効化

1. Firebase Consoleで「Authentication」を選択
2. 「始める」をクリック
3. 「Sign-in method」タブを選択
4. 「匿名」を有効化（開発用）
5. オプション: Apple、Googleなどのプロバイダーを追加

#### 2.7 動作確認

アプリを実行して、Xcodeコンソールに以下のメッセージが表示されることを確認:
```
✅ Firestore initialized with offline persistence enabled
```

### 3. 次のステップ

- [x] Firebase SDKの統合（Task 1.2）✅
- [ ] Firestore Security Rulesの実装（Task 1.3）
- [ ] データモデルの実装（Task 2.1）
- [ ] Gemini API統合（Task 4.1）

## 開発ガイドライン

### フォルダ構造の使用方法

- **Models/**: `Codable`と`Identifiable`に準拠したデータ構造を配置
- **ViewModels/**: `ObservableObject`に準拠したViewModelを配置
- **Views/**: SwiftUI Viewコンポーネントを配置
- **Repositories/**: データソースの抽象化レイヤーを配置
- **Services/**: 外部API統合（Firebase, Gemini）を配置
  - `FirebaseManager.swift`: Firestoreの初期化と設定を管理

### FirebaseManagerの使用方法

`FirebaseManager`はシングルトンパターンで実装されており、アプリ全体でFirestoreインスタンスを共有します。

```swift
// Firestoreインスタンスを取得
let firestore = FirebaseManager.shared.getFirestore()

// コレクションへの参照を取得
let eventsCollection = FirebaseManager.shared.collection("events")

// ドキュメントへの参照を取得
let eventDoc = FirebaseManager.shared.document("events/event123")

// バッチ書き込み
let batch = FirebaseManager.shared.batch()
batch.setData(["title": "BBQ"], forDocument: eventDoc)
try await batch.commit()
```

**主な機能**:
- オフライン永続化の自動有効化（Requirements 8.2, 8.3）
- ネットワーク状態の管理
- エラーハンドリングのヘルパーメソッド
- キャッシュ管理

### コーディング規約

- SwiftUIのベストプラクティスに従う
- MVVM + Repositoryパターンを維持
- Combineを使用したリアクティブプログラミング
- 非同期処理には`async/await`を使用

## ライセンス

このプロジェクトは開発中です。
