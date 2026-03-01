# Implementation Plan: EventFlow

## Overview

EventFlowは、イベント幹事の負担を軽減するクロスプラットフォームシステムです。iOS App（Swift/SwiftUI）、Web Interface（JavaScript）、Firebase Firestore、Gemini APIの4つの主要コンポーネントを段階的に実装します。各タスクは前のタスクの成果物を活用し、最終的に完全に統合されたシステムを構築します。

## Tasks

- [ ] 1. プロジェクト初期設定とFirebase統合
  - [ ] 1.1 Xcodeプロジェクトの作成とSwiftUI基本構造のセットアップ
    - Xcodeで新規iOSプロジェクトを作成（SwiftUI、iOS 16.0+）
    - 基本的なフォルダ構造を作成（Models, ViewModels, Views, Repositories, Services）
    - _Requirements: 全体的な基盤_

  - [ ] 1.2 Firebase SDKの統合とFirestore初期化
    - Swift Package ManagerでFirebase SDKを追加（FirebaseFirestore, FirebaseAuth）
    - GoogleService-Info.plistを追加
    - AppDelegateまたはAppでFirebaseを初期化
    - _Requirements: 8.1, 11.1_

  - [ ] 1.3 Firestore Security Rulesの実装
    - Firebaseコンソールでセキュリティルールを設定
    - イベント作成者のみが書き込み可能なルールを実装
    - 参加者がタスクステータスと支払いステータスを更新できるルールを実装
    - _Requirements: 11.2, 11.3_

  - [ ]* 1.4 Firebase統合のプロパティテスト
    - **Property 33: Unauthenticated requests are rejected**
    - **Validates: Requirements 11.1**

- [ ] 2. データモデルとリポジトリレイヤーの実装
  - [ ] 2.1 Swiftデータモデルの作成
    - Event, Task, Participant, ShoppingItem構造体を実装（Identifiable, Codable準拠）
    - TaskPriority, TaskStatus, PaymentStatus列挙型を実装
    - _Requirements: 8.1, 9.1, 10.1_

  - [ ] 2.2 EventRepositoryプロトコルと実装の作成
    - EventRepositoryプロトコルを定義（CRUD操作）
    - FirestoreEventRepositoryクラスを実装
    - リアルタイムリスナー（observeEvent）を実装
    - _Requirements: 5.1, 8.1, 8.2_

  - [ ]* 2.3 データモデルのプロパティテスト
    - **Property 22: Created events can be retrieved**
    - **Validates: Requirements 8.4**

  - [ ] 2.4 TaskRepositoryの実装
    - タスクのCRUD操作を実装
    - リアルタイムタスク監視（observeTasks）を実装
    - _Requirements: 2.4, 2.5, 2.6, 5.1_

  - [ ]* 2.5 TaskRepositoryのプロパティテスト
    - **Property 7: Adding tasks increases task list length**
    - **Property 9: Deleting tasks removes them from list**
    - **Validates: Requirements 2.4, 2.6**

  - [ ] 2.6 ParticipantRepositoryの実装
    - 参加者のCRUD操作を実装
    - リアルタイム参加者監視（observeParticipants）を実装
    - _Requirements: 9.1, 9.2, 9.4_

  - [ ]* 2.7 ParticipantRepositoryのプロパティテスト
    - **Property 23: Adding participants increases participant list length**
    - **Property 26: Removing participants decreases list length**
    - **Validates: Requirements 9.1, 9.4**

- [ ] 3. Checkpoint - データレイヤーの動作確認
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 4. Gemini API統合とAI生成機能
  - [ ] 4.1 GeminiServiceの実装
    - AIServiceプロトコルを定義
    - GeminiServiceクラスを実装（イベントテンプレート生成）
    - JSON解析ロジックを実装（EventTemplate構造体へのデコード）
    - エラーハンドリングとリトライロジックを実装
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_

  - [ ]* 4.2 AI生成のプロパティテスト
    - **Property 1: Generated templates contain shopping list with quantities**
    - **Property 2: Generated templates contain task assignments**
    - **Property 3: Generated templates contain time schedule**
    - **Validates: Requirements 1.2, 1.3, 1.4**

  - [ ] 4.3 催促メッセージ生成機能の実装
    - GeminiServiceにgenerateReminderMessage関数を追加
    - ReminderContext構造体を定義
    - プロンプトテンプレートを実装
    - _Requirements: 7.1, 7.2, 7.3_

  - [ ]* 4.4 催促メッセージ生成のユニットテスト
    - 未完了タスクに対するメッセージ生成をテスト
    - 未払いに対するメッセージ生成をテスト
    - エラー条件（API失敗）をテスト
    - _Requirements: 7.1, 7.2_

- [ ] 5. ViewModelレイヤーの実装
  - [ ] 5.1 EventViewModelの実装
    - @Published プロパティ（event, isLoading, error）を定義
    - generateTemplate関数を実装（GeminiServiceを使用）
    - updateEvent関数を実装
    - shareEventURL関数を実装（ユニークURL生成）
    - _Requirements: 1.1, 2.8, 3.1_

  - [ ]* 5.2 EventViewModelのプロパティテスト
    - **Property 11: Event URLs are unique**
    - **Validates: Requirements 3.1**

  - [ ] 5.3 TaskViewModelの実装
    - @Published プロパティ（tasks, isLoading）を定義
    - CRUD操作関数を実装
    - observeTasks関数を実装（Combineでリアルタイム更新）
    - _Requirements: 2.4, 2.5, 2.6, 5.1, 5.4_

  - [ ]* 5.4 TaskViewModelのプロパティテスト
    - **Property 8: Editing task descriptions persists changes**
    - **Property 16: Task status is displayed for each task**
    - **Validates: Requirements 2.5, 5.4**

  - [ ] 5.5 ParticipantViewModelの実装
    - @Published プロパティ（participants, totalExpected, totalCollected）を定義
    - 集金計算ロジックを実装
    - generateReminderMessage関数を実装
    - observeParticipants関数を実装
    - _Requirements: 7.1, 9.1, 10.1, 10.2, 10.3_

  - [ ]* 5.6 ParticipantViewModelのプロパティテスト
    - **Property 28: Total expected payment equals sum of individual expectations**
    - **Property 29: Total collected payment equals sum of paid amounts**
    - **Property 30: Outstanding payment equals expected minus collected**
    - **Property 32: Payment completion percentage calculation**
    - **Validates: Requirements 10.1, 10.2, 10.3, 10.5**

- [ ] 6. iOS UI実装 - イベント作成とテンプレート生成
  - [ ] 6.1 EventCreationViewの実装
    - イベント基本情報入力フォーム（タイトル、タイプ、参加者数、日時、予算）
    - バリデーションロジックを実装
    - AI生成ボタンとローディング表示を実装
    - _Requirements: 1.1_

  - [ ]* 6.2 EventCreationViewのユニットテスト
    - バリデーションルールをテスト
    - エラー表示をテスト
    - _Requirements: 1.1, 12.2_

  - [ ] 6.3 テンプレート表示と編集UIの実装
    - 生成されたテンプレートの表示（買い物リスト、タスク、スケジュール）
    - インライン編集機能を実装
    - 追加・削除ボタンを実装
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7_

  - [ ]* 6.4 テンプレート編集のプロパティテスト
    - **Property 4: Adding shopping items increases list length**
    - **Property 5: Removing shopping items decreases list length**
    - **Property 6: Modifying quantities persists changes**
    - **Property 10: Modifying schedule persists changes**
    - **Validates: Requirements 2.1, 2.2, 2.3, 2.7**

- [ ] 7. iOS UI実装 - イベント詳細とステータス表示
  - [ ] 7.1 EventDetailViewの実装
    - イベント概要セクションを実装
    - 進捗インジケーターを実装（完了率表示）
    - タブビュー（タスク、参加者、買い物リスト）を実装
    - URL共有ボタンを実装
    - _Requirements: 3.1, 3.2, 5.3_

  - [ ]* 7.2 進捗表示のプロパティテスト
    - **Property 15: Progress indicator reflects completion ratio**
    - **Validates: Requirements 5.3**

  - [ ] 7.3 TaskListViewの実装
    - タスク一覧表示（ステータス別カラーコーディング）
    - タスク追加・編集・削除UI
    - リアルタイム更新の反映
    - _Requirements: 2.4, 2.5, 2.6, 5.1, 5.4, 5.6_

  - [ ] 7.4 ParticipantListViewの実装
    - 参加者一覧表示（支払いステータス表示）
    - 集金サマリー表示（合計期待額、回収額、未回収額）
    - 催促メッセージ生成ボタン
    - _Requirements: 5.5, 9.3, 10.1, 10.2, 10.3, 10.4, 10.6_

  - [ ]* 7.5 支払いステータス表示のプロパティテスト
    - **Property 17: Payment status is displayed for each participant**
    - **Property 31: Payment status displayed matches stored value**
    - **Validates: Requirements 5.5, 10.4**

- [ ] 8. Checkpoint - iOS App基本機能の動作確認
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 9. オフライン対応とエラーハンドリング
  - [ ] 9.1 ローカルキャッシュの実装
    - UserDefaultsまたはCoreDataでローカルキャッシュを実装
    - オフライン時の変更キューイング機能を実装
    - _Requirements: 8.2_

  - [ ] 9.2 ネットワーク再接続時の同期ロジック
    - ネットワーク状態監視を実装（Network framework）
    - 再接続時の自動同期を実装
    - 競合解決ロジック（last-write-wins）を実装
    - _Requirements: 8.3_

  - [ ]* 9.3 オフライン対応のプロパティテスト
    - **Property 21: Offline changes are queued and synced**
    - **Validates: Requirements 8.2, 8.3**

  - [ ] 9.4 エラーハンドリングの実装
    - カスタムエラー型を定義（NetworkError, AIError, ValidationError）
    - エラーメッセージのローカライゼーション
    - リトライロジック（指数バックオフ）を実装
    - エラーロギング（Firebase Crashlytics）を実装
    - _Requirements: 12.1, 12.2, 12.3, 12.5_

  - [ ]* 9.5 エラーハンドリングのユニットテスト
    - ネットワークエラー時の動作をテスト
    - AI生成エラー時のリトライをテスト
    - Firestoreエラー時のフォールバックをテスト
    - _Requirements: 12.1, 12.2, 12.3_

  - [ ]* 9.6 エラーロギングのプロパティテスト
    - **Property 37: Errors are logged**
    - **Validates: Requirements 12.5**

- [ ] 10. Web Interface - 基本構造とFirebase統合
  - [ ] 10.1 HTMLページの作成
    - index.htmlを作成（レスポンシブデザイン）
    - CSSスタイルシートを作成（モバイルファースト）
    - Firebase Web SDKをCDNから読み込み
    - _Requirements: 3.4, 3.5_

  - [ ] 10.2 FirestoreClientクラスの実装（JavaScript）
    - Firestore初期化ロジックを実装
    - observeTasks関数を実装（リアルタイムリスナー）
    - claimTask関数を実装
    - updateTaskStatus関数を実装
    - updatePaymentStatus関数を実装
    - _Requirements: 4.4, 6.4_

  - [ ]* 10.3 FirestoreClientのプロパティテスト（fast-check）
    - **Property 12: Swiping right assigns task to participant**
    - **Property 18: Marking task as completed updates status**
    - **Property 19: Marking payment as completed updates status**
    - **Validates: Requirements 4.2, 6.1, 6.2**

- [ ] 11. Web Interface - スワイプ式タスク選択UI
  - [ ] 11.1 ParticipantNameInputコンポーネントの実装
    - 名前入力フォームを実装
    - LocalStorageへの保存を実装
    - _Requirements: 4.6_

  - [ ] 11.2 TaskCardViewコンポーネントの実装
    - カード形式のタスク表示を実装
    - スワイプジェスチャー検出（Hammer.jsまたはネイティブTouch Events）
    - 右スワイプ: タスク引き受けアニメーション
    - 左スワイプ: 次のカードへのアニメーション
    - _Requirements: 4.1, 4.2, 4.3_

  - [ ]* 11.3 スワイプ動作のプロパティテスト
    - **Property 13: Swiping left advances to next task**
    - **Validates: Requirements 4.3**

  - [ ] 11.4 タスク割り当て状態の表示
    - 既に割り当てられたタスクの表示（unavailable状態）
    - リアルタイム更新の反映
    - _Requirements: 4.5_

  - [ ]* 11.5 タスク割り当て状態のプロパティテスト
    - **Property 14: Assigned tasks display as unavailable**
    - **Validates: Requirements 4.5**

- [ ] 12. Web Interface - ステータス更新パネル
  - [ ] 12.1 StatusUpdatePanelコンポーネントの実装
    - 自分が引き受けたタスクの一覧表示
    - 完了チェックボックスを実装
    - メモ入力フィールドを実装
    - 支払い完了ボタンを実装
    - _Requirements: 6.1, 6.2, 6.3_

  - [ ]* 12.2 ステータス更新のプロパティテスト
    - **Property 20: Adding notes to tasks persists them**
    - **Validates: Requirements 6.3**

  - [ ] 12.3 更新成功時の確認表示
    - トースト通知を実装
    - エラー時のメッセージ表示を実装
    - _Requirements: 6.5, 12.4_

- [ ] 13. Checkpoint - Web Interface基本機能の動作確認
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 14. 参加者管理機能の実装
  - [ ] 14.1 参加者自動追加ロジック
    - Web InterfaceでタスクをクレームしたときにFirestoreに参加者を自動追加
    - 重複チェックを実装
    - _Requirements: 9.2_

  - [ ]* 14.2 参加者自動追加のプロパティテスト
    - **Property 24: Claiming task creates participant entry**
    - **Validates: Requirements 9.2**

  - [ ] 14.3 参加者カウント表示
    - リアルタイム参加者数の表示を実装
    - _Requirements: 9.3_

  - [ ]* 14.4 参加者カウントのプロパティテスト
    - **Property 25: Participant count matches list length**
    - **Validates: Requirements 9.3**

  - [ ] 14.4 参加者の支払い額設定機能
    - iOS Appで参加者ごとの期待支払い額を設定するUIを実装
    - _Requirements: 9.5_

  - [ ]* 14.5 支払い額設定のプロパティテスト
    - **Property 27: Setting expected payment persists value**
    - **Validates: Requirements 9.5**

- [ ] 15. URL共有とLINE統合
  - [ ] 15.1 共有URL生成ロジック
    - イベントIDベースのユニークURL生成を実装
    - クリップボードコピー機能を実装
    - _Requirements: 3.1, 3.2_

  - [ ] 15.2 LINE共有機能の実装
    - LINE URL Schemeを使用した共有を実装（iOS App）
    - LINE共有ボタンを実装（催促メッセージ用）
    - _Requirements: 3.3, 7.6_

  - [ ]* 15.3 LINE共有のユニットテスト
    - URL生成をテスト
    - LINE URL Schemeの構築をテスト
    - _Requirements: 3.3, 7.6_

- [ ] 16. セキュリティとプライバシーの強化
  - [ ] 16.1 Firebase Authenticationの実装
    - 匿名認証を実装
    - オプションでApple Sign-In / Google Sign-Inを実装
    - _Requirements: 11.1_

  - [ ]* 16.2 認証のプロパティテスト
    - **Property 34: Unauthorized access is denied**
    - **Validates: Requirements 11.2**

  - [ ] 16.3 HTTPS通信の確認
    - すべてのネットワークリクエストがHTTPSを使用していることを確認
    - App Transport Security設定を確認
    - _Requirements: 11.5_

  - [ ]* 16.4 HTTPS通信のプロパティテスト
    - **Property 36: All network URLs use HTTPS**
    - **Validates: Requirements 11.5**

  - [ ] 16.5 イベントデータのアクセス制御
    - Web InterfaceでイベントIDに基づくデータアクセスのみを許可
    - 他のイベントデータへのアクセスを防止
    - _Requirements: 11.3_

  - [ ]* 16.6 データアクセス制御のプロパティテスト
    - **Property 35: Event URL only returns data for that event**
    - **Validates: Requirements 11.3**

- [ ] 17. Checkpoint - セキュリティとプライバシーの検証
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 18. パフォーマンス最適化とポリッシュ
  - [ ] 18.1 Firestoreクエリの最適化
    - インデックスの作成
    - ページネーションの実装（大量データ対応）
    - _Requirements: 3.5, 5.1_

  - [ ] 18.2 画像とアセットの最適化
    - アイコンとイラストの追加
    - ローディングアニメーションの実装
    - _Requirements: 全体的なUX向上_

  - [ ] 18.3 アクセシビリティの向上
    - VoiceOver対応（iOS）
    - セマンティックHTML（Web）
    - カラーコントラストの確認
    - _Requirements: 全体的なアクセシビリティ_

  - [ ]* 18.4 アクセシビリティのユニットテスト
    - VoiceOverラベルをテスト
    - カラーコントラスト比をテスト
    - _Requirements: 全体的なアクセシビリティ_

- [ ] 19. 統合テストとエンドツーエンドテスト
  - [ ]* 19.1 iOS App統合テスト
    - イベント作成からURL共有までのフローをテスト
    - リアルタイム更新の動作をテスト
    - オフライン→オンライン復帰のシナリオをテスト
    - _Requirements: 全体的な統合_

  - [ ]* 19.2 Web Interface統合テスト
    - タスククレームから完了までのフローをテスト
    - 複数参加者の同時アクセスをテスト
    - _Requirements: 全体的な統合_

  - [ ]* 19.3 クロスプラットフォーム統合テスト
    - iOS Appでの変更がWeb Interfaceに反映されることをテスト
    - Web Interfaceでの変更がiOS Appに反映されることをテスト
    - _Requirements: 5.1, 5.2_

- [ ] 20. 最終チェックポイント - 全機能の動作確認
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- タスクに`*`が付いているものはオプションのテストタスクで、MVP開発時にはスキップ可能です
- 各タスクは具体的な要件番号を参照しており、トレーサビリティを確保しています
- チェックポイントタスクで段階的に検証を行い、問題の早期発見を促進します
- プロパティテストは設計ドキュメントの37個の正確性プロパティをカバーしています
- ユニットテストは具体的な例、エッジケース、エラー条件に焦点を当てています
