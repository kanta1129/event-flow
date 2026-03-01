# Requirements Document

## Introduction

EventFlow（イベントフロー）は、イベント幹事の負担を劇的に軽減するiOSアプリケーションです。「企画から集金まで、幹事の頭の中をすべて可視化するコマンドセンター」をコンセプトに、AIによる自動化、参加者の巻き込み、リアルタイムステータス管理を実現します。

## Glossary

- **EventFlow_App**: 幹事が使用するiOSネイティブアプリケーション
- **Web_Interface**: 参加者がブラウザからアクセスする軽量インターフェース
- **Event_Organizer**: イベントを企画・管理する幹事ユーザー
- **Event_Participant**: イベントに参加する一般ユーザー
- **AI_Generator**: Gemini APIを使用したイベント情報自動生成システム
- **Task**: イベント運営に必要な個別の作業（買い出し、場所取りなど）
- **Event_Template**: AIが生成するイベント計画の雛形
- **Payment_Status**: 参加者の支払い状況（未払い、支払い済み）
- **Task_Status**: タスクの進行状況（未着手、進行中、完了）
- **Firestore**: リアルタイムデータ同期を提供するFirebaseのデータベース
- **Reminder_Message**: 未払いや未完了タスクに対する催促メッセージ

## Requirements

### Requirement 1: AIによるイベントテンプレート生成

**User Story:** As an Event_Organizer, I want to generate event plans automatically from a brief description, so that I can save time on initial planning.

#### Acceptance Criteria

1. WHEN an Event_Organizer inputs event details (type, participant count), THE AI_Generator SHALL generate an Event_Template within 10 seconds
2. THE Event_Template SHALL include a shopping list with specific quantities
3. THE Event_Template SHALL include role assignments for participants
4. THE Event_Template SHALL include a time schedule for the event day
5. WHEN the AI_Generator fails to connect to Gemini API, THE EventFlow_App SHALL display an error message and allow retry

### Requirement 2: イベントテンプレートの編集

**User Story:** As an Event_Organizer, I want to edit AI-generated templates, so that I can customize plans to fit my specific needs.

#### Acceptance Criteria

1. THE EventFlow_App SHALL allow Event_Organizer to add new items to the shopping list
2. THE EventFlow_App SHALL allow Event_Organizer to remove items from the shopping list
3. THE EventFlow_App SHALL allow Event_Organizer to modify quantities in the shopping list
4. THE EventFlow_App SHALL allow Event_Organizer to add new Tasks
5. THE EventFlow_App SHALL allow Event_Organizer to edit Task descriptions
6. THE EventFlow_App SHALL allow Event_Organizer to delete Tasks
7. THE EventFlow_App SHALL allow Event_Organizer to modify the time schedule
8. WHEN an Event_Organizer saves changes, THE EventFlow_App SHALL persist changes to Firestore within 2 seconds

### Requirement 3: 参加者へのタスク共有

**User Story:** As an Event_Organizer, I want to share tasks with participants via a web link, so that they can volunteer without installing an app.

#### Acceptance Criteria

1. WHEN an Event_Organizer completes an Event_Template, THE EventFlow_App SHALL generate a unique shareable URL
2. THE EventFlow_App SHALL allow Event_Organizer to copy the URL to clipboard
3. THE EventFlow_App SHALL provide a direct share option to LINE
4. WHEN an Event_Participant opens the URL, THE Web_Interface SHALL display without requiring app installation
5. THE Web_Interface SHALL load within 3 seconds on standard mobile networks

### Requirement 4: スワイプ式タスク選択

**User Story:** As an Event_Participant, I want to claim tasks using an intuitive swipe interface, so that I can quickly volunteer for responsibilities.

#### Acceptance Criteria

1. THE Web_Interface SHALL display Tasks in a swipeable card format
2. WHEN an Event_Participant swipes right on a Task, THE Web_Interface SHALL assign that Task to the participant
3. WHEN an Event_Participant swipes left on a Task, THE Web_Interface SHALL show the next Task
4. WHEN a Task is assigned, THE Web_Interface SHALL update Firestore within 1 second
5. WHEN a Task is already assigned to another participant, THE Web_Interface SHALL display the Task as unavailable
6. THE Web_Interface SHALL allow Event_Participant to enter their name before claiming Tasks

### Requirement 5: リアルタイムステータス表示

**User Story:** As an Event_Organizer, I want to see real-time updates of task and payment status, so that I can monitor event preparation progress.

#### Acceptance Criteria

1. WHEN Task_Status changes in Firestore, THE EventFlow_App SHALL update the display within 2 seconds
2. WHEN Payment_Status changes in Firestore, THE EventFlow_App SHALL update the display within 2 seconds
3. THE EventFlow_App SHALL display a visual progress indicator for overall event preparation
4. THE EventFlow_App SHALL display individual Task_Status for each Task
5. THE EventFlow_App SHALL display Payment_Status for each Event_Participant
6. THE EventFlow_App SHALL use color coding to distinguish between different status types

### Requirement 6: 参加者によるステータス更新

**User Story:** As an Event_Participant, I want to update my task and payment status from the web interface, so that the organizer knows my progress.

#### Acceptance Criteria

1. THE Web_Interface SHALL allow Event_Participant to mark assigned Tasks as completed
2. THE Web_Interface SHALL allow Event_Participant to mark payment as completed
3. THE Web_Interface SHALL allow Event_Participant to add notes to Task updates
4. WHEN an Event_Participant updates status, THE Web_Interface SHALL save changes to Firestore within 1 second
5. THE Web_Interface SHALL display confirmation when status update succeeds

### Requirement 7: 自動催促メッセージ生成

**User Story:** As an Event_Organizer, I want to generate polite reminder messages automatically, so that I can follow up without awkwardness.

#### Acceptance Criteria

1. WHEN an Event_Organizer selects a participant with incomplete tasks, THE AI_Generator SHALL generate a Reminder_Message within 5 seconds
2. WHEN an Event_Organizer selects a participant with unpaid status, THE AI_Generator SHALL generate a Reminder_Message within 5 seconds
3. THE Reminder_Message SHALL use polite and non-confrontational language
4. THE EventFlow_App SHALL allow Event_Organizer to edit the Reminder_Message before sending
5. THE EventFlow_App SHALL provide a copy-to-clipboard option for the Reminder_Message
6. THE EventFlow_App SHALL provide a direct share option to LINE for the Reminder_Message

### Requirement 8: イベントデータの永続化

**User Story:** As an Event_Organizer, I want my event data to be saved reliably, so that I don't lose information if the app closes.

#### Acceptance Criteria

1. WHEN an Event_Organizer creates an event, THE EventFlow_App SHALL save event data to Firestore within 2 seconds
2. WHEN the EventFlow_App loses network connection, THE EventFlow_App SHALL queue changes locally
3. WHEN network connection is restored, THE EventFlow_App SHALL synchronize queued changes to Firestore
4. THE EventFlow_App SHALL allow Event_Organizer to access past events
5. THE EventFlow_App SHALL maintain event data for at least 90 days after event date

### Requirement 9: 参加者リスト管理

**User Story:** As an Event_Organizer, I want to manage the list of participants, so that I can track who is involved in the event.

#### Acceptance Criteria

1. THE EventFlow_App SHALL allow Event_Organizer to add participants manually
2. THE EventFlow_App SHALL automatically add participants when they claim Tasks via Web_Interface
3. THE EventFlow_App SHALL display participant count in real-time
4. THE EventFlow_App SHALL allow Event_Organizer to remove participants
5. THE EventFlow_App SHALL allow Event_Organizer to set expected payment amount per participant

### Requirement 10: 集金トラッキング

**User Story:** As an Event_Organizer, I want to track payment collection, so that I know who has paid and how much is outstanding.

#### Acceptance Criteria

1. THE EventFlow_App SHALL display total expected payment amount
2. THE EventFlow_App SHALL display total collected payment amount
3. THE EventFlow_App SHALL display outstanding payment amount
4. THE EventFlow_App SHALL display Payment_Status for each Event_Participant
5. THE EventFlow_App SHALL calculate payment completion percentage
6. THE EventFlow_App SHALL highlight participants with unpaid status

### Requirement 11: データセキュリティとプライバシー

**User Story:** As an Event_Organizer, I want participant data to be secure, so that privacy is protected.

#### Acceptance Criteria

1. THE EventFlow_App SHALL require authentication before accessing event data
2. THE Firestore SHALL enforce access rules that prevent unauthorized data access
3. WHEN an Event_Participant accesses Web_Interface, THE Web_Interface SHALL only display data for that specific event
4. THE EventFlow_App SHALL not store payment card information
5. THE EventFlow_App SHALL use HTTPS for all network communications

### Requirement 12: エラーハンドリング

**User Story:** As a user, I want clear error messages when something goes wrong, so that I understand what happened and what to do next.

#### Acceptance Criteria

1. WHEN network connection is unavailable, THE EventFlow_App SHALL display a descriptive error message
2. WHEN Gemini API returns an error, THE EventFlow_App SHALL display a descriptive error message
3. WHEN Firestore operation fails, THE EventFlow_App SHALL display a descriptive error message and offer retry option
4. WHEN Web_Interface fails to load event data, THE Web_Interface SHALL display a descriptive error message
5. THE EventFlow_App SHALL log errors for debugging purposes
