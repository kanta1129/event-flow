//
//  EventDetailView.swift
//  EventFlow
//
//  イベント詳細画面 - イベント全体の状況表示と管理
//  Requirements: 3.1, 3.2, 5.3
//

import SwiftUI

/// イベント詳細画面
/// イベントの概要、進捗状況、タスク、参加者、買い物リストを表示・管理する
struct EventDetailView: View {
    
    // MARK: - State Properties
    
    @StateObject private var eventViewModel: EventViewModel
    @StateObject private var taskViewModel: TaskViewModel
    @StateObject private var participantViewModel: ParticipantViewModel
    
    @State private var selectedTab: DetailTab = .tasks
    @State private var showingShareSheet = false
    @State private var showingError = false
    
    let eventId: String
    
    // MARK: - Tab Definition
    
    enum DetailTab: String, CaseIterable {
        case tasks = "タスク"
        case participants = "参加者"
        case shopping = "買い物リスト"
        
        var icon: String {
            switch self {
            case .tasks: return "checklist"
            case .participants: return "person.3.fill"
            case .shopping: return "cart.fill"
            }
        }
    }
    
    // MARK: - Initialization
    
    init(
        eventId: String,
        eventViewModel: EventViewModel,
        taskViewModel: TaskViewModel,
        participantViewModel: ParticipantViewModel
    ) {
        self.eventId = eventId
        _eventViewModel = StateObject(wrappedValue: eventViewModel)
        _taskViewModel = StateObject(wrappedValue: taskViewModel)
        _participantViewModel = StateObject(wrappedValue: participantViewModel)
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // イベント概要セクション
                if let event = eventViewModel.event {
                    eventOverviewSection(event: event)
                }
                
                // 進捗インジケーターセクション
                progressIndicatorSection
                
                // タブセレクター
                tabSelector
                
                // タブコンテンツ
                tabContent
            }
            .padding()
        }
        .navigationTitle(eventViewModel.event?.title ?? "イベント詳細")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                shareButton
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = eventViewModel.shareEventURL() {
                ShareSheet(items: [url])
            }
        }
        .alert("エラー", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = eventViewModel.error {
                Text(error.localizedDescription)
            }
        }
        .onAppear {
            loadEventData()
        }
    }
    
    // MARK: - Event Overview Section
    
    /// イベント概要セクション
    /// Requirements: 3.1
    private func eventOverviewSection(event: Event) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // タイトル
            Text(event.title)
                .font(.title2)
                .fontWeight(.bold)
            
            // イベント情報グリッド
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                // イベントタイプ
                InfoCard(
                    icon: "tag.fill",
                    title: "タイプ",
                    value: event.eventType,
                    color: .blue
                )
                
                // 開催日時
                InfoCard(
                    icon: "calendar",
                    title: "開催日時",
                    value: formatDate(event.date),
                    color: .orange
                )
                
                // 参加者数
                InfoCard(
                    icon: "person.3.fill",
                    title: "参加者",
                    value: "\(participantViewModel.participantCount())人",
                    color: .green
                )
                
                // 予算
                InfoCard(
                    icon: "yensign.circle.fill",
                    title: "予算/人",
                    value: "¥\(Int(event.budget))",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Progress Indicator Section
    
    /// 進捗インジケーターセクション
    /// Requirements: 5.3
    private var progressIndicatorSection: some View {
        VStack(spacing: 16) {
            // タスク完了率
            ProgressIndicator(
                title: "タスク進捗",
                icon: "checklist",
                progress: taskViewModel.completionRate(),
                color: .blue,
                detail: "\(taskViewModel.completedTasksCount()) / \(taskViewModel.tasks.count) 完了"
            )
            
            // 支払い完了率
            ProgressIndicator(
                title: "集金進捗",
                icon: "yensign.circle",
                progress: participantViewModel.completionPercentage(),
                color: .green,
                detail: "¥\(Int(participantViewModel.totalCollected)) / ¥\(Int(participantViewModel.totalExpected))"
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Tab Selector
    
    /// タブセレクター
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(DetailTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20))
                        Text(tab.rawValue)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selectedTab == tab ?
                        Color.blue.opacity(0.1) :
                        Color.clear
                    )
                    .foregroundColor(selectedTab == tab ? .blue : .gray)
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Tab Content
    
    /// タブコンテンツ
    private var tabContent: some View {
        Group {
            switch selectedTab {
            case .tasks:
                tasksTabContent
            case .participants:
                participantsTabContent
            case .shopping:
                shoppingTabContent
            }
        }
        .transition(.opacity)
    }
    
    /// タスクタブのコンテンツ
    private var tasksTabContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if taskViewModel.tasks.isEmpty {
                emptyStateView(
                    icon: "checklist",
                    message: "タスクがまだありません"
                )
            } else {
                ForEach(taskViewModel.tasks) { task in
                    TaskCard(task: task)
                }
            }
        }
    }
    
    /// 参加者タブのコンテンツ
    private var participantsTabContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 集金サマリー
            paymentSummaryCard
            
            // ParticipantListViewの埋め込み版を使用
            ParticipantListView(
                participantViewModel: participantViewModel,
                eventId: eventId,
                eventDate: eventViewModel.event?.date,
                isEmbedded: true
            )
        }
    }
    
    /// 買い物リストタブのコンテンツ
    private var shoppingTabContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            emptyStateView(
                icon: "cart.fill",
                message: "買い物リストは今後実装予定です"
            )
        }
    }
    
    // MARK: - Payment Summary Card
    
    /// 集金サマリーカード
    private var paymentSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("集金状況")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("期待額")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("¥\(Int(participantViewModel.totalExpected))")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("回収済み")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("¥\(Int(participantViewModel.totalCollected))")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("未回収")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("¥\(Int(participantViewModel.outstandingPayment()))")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Share Button
    
    /// URL共有ボタン
    /// Requirements: 3.2
    private var shareButton: some View {
        Button(action: {
            showingShareSheet = true
        }) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 18))
        }
    }
    
    // MARK: - Helper Views
    
    /// 空状態ビュー
    private func emptyStateView(icon: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Private Methods
    
    /// イベントデータを読み込み
    /// Requirements: 5.1
    private func loadEventData() {
        // イベント情報の監視を開始
        eventViewModel.observeEvent(id: eventId)
        
        // タスクの監視を開始
        taskViewModel.observeTasks(eventId: eventId)
        
        // 参加者の監視を開始
        participantViewModel.observeParticipants(eventId: eventId)
    }
    
    /// 日付をフォーマット
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Views

/// 情報カード
struct InfoCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.body)
                .fontWeight(.semibold)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

/// 進捗インジケーター
struct ProgressIndicator: View {
    let title: String
    let icon: String
    let progress: Double
    let color: Color
    let detail: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.headline)
                    .foregroundColor(color)
            }
            
            ProgressView(value: progress)
                .tint(color)
            
            Text(detail)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

/// タスクカード
struct TaskCard: View {
    let task: Task
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // ステータスインジケーター
                Circle()
                    .fill(statusColor(task.status))
                    .frame(width: 12, height: 12)
                
                Text(task.title)
                    .font(.headline)
                
                Spacer()
                
                // 優先度バッジ
                Text(priorityText(task.priority))
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(priorityColor(task.priority).opacity(0.2))
                    .foregroundColor(priorityColor(task.priority))
                    .cornerRadius(4)
            }
            
            Text(task.description)
                .font(.body)
                .foregroundColor(.secondary)
            
            if let assignedTo = task.assignedTo {
                HStack {
                    Image(systemName: "person.fill")
                        .font(.caption)
                    Text("担当: \(assignedTo)")
                        .font(.caption)
                }
                .foregroundColor(.blue)
            }
            
            if let note = task.note, !note.isEmpty {
                HStack {
                    Image(systemName: "note.text")
                        .font(.caption)
                    Text(note)
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func statusColor(_ status: TaskStatus) -> Color {
        switch status {
        case .unassigned: return .gray
        case .assigned: return .blue
        case .inProgress: return .orange
        case .completed: return .green
        }
    }
    
    private func priorityColor(_ priority: TaskPriority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }
    
    private func priorityText(_ priority: TaskPriority) -> String {
        switch priority {
        case .high: return "高"
        case .medium: return "中"
        case .low: return "低"
        }
    }
}

/// 参加者カード
struct ParticipantCard: View {
    let participant: Participant
    
    var body: some View {
        HStack {
            // 参加者情報
            VStack(alignment: .leading, spacing: 4) {
                Text(participant.name)
                    .font(.headline)
                
                Text("期待額: ¥\(Int(participant.expectedPayment))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 支払いステータス
            HStack(spacing: 8) {
                if participant.paymentStatus == .paid {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("支払い済み")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                    Text("未払い")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

/// 共有シート（UIActivityViewController wrapper）
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No update needed
    }
}

// MARK: - Preview

#if DEBUG
struct EventDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            EventDetailView(
                eventId: "preview-event-id",
                eventViewModel: previewEventViewModel(),
                taskViewModel: previewTaskViewModel(),
                participantViewModel: previewParticipantViewModel()
            )
        }
    }
    
    static func previewEventViewModel() -> EventViewModel {
        let mockRepository = MockEventRepository()
        let mockAIService = MockAIService()
        let viewModel = EventViewModel(
            eventRepository: mockRepository,
            aiService: mockAIService
        )
        
        // プレビュー用のイベントデータを設定
        viewModel.event = Event(
            id: "preview-event-id",
            title: "夏のBBQパーティー",
            eventType: "BBQ",
            date: Date().addingTimeInterval(86400 * 7), // 1週間後
            organizerId: "preview-organizer",
            participantCount: 15,
            budget: 5000,
            shareUrl: "https://eventflow.app/event/preview",
            createdAt: Date(),
            updatedAt: Date()
        )
        
        return viewModel
    }
    
    static func previewTaskViewModel() -> TaskViewModel {
        let mockRepository = MockTaskRepository()
        let viewModel = TaskViewModel(taskRepository: mockRepository)
        
        // プレビュー用のタスクデータを設定
        viewModel.tasks = [
            Task(
                id: "task-1",
                title: "食材の買い出し",
                description: "肉、野菜、飲み物を購入",
                priority: .high,
                status: .completed,
                assignedTo: "田中さん",
                note: "スーパーで購入済み",
                createdAt: Date(),
                updatedAt: Date()
            ),
            Task(
                id: "task-2",
                title: "BBQ場の予約",
                description: "公園のBBQエリアを予約",
                priority: .high,
                status: .inProgress,
                assignedTo: "佐藤さん",
                note: nil,
                createdAt: Date(),
                updatedAt: Date()
            ),
            Task(
                id: "task-3",
                title: "調理器具の準備",
                description: "グリル、炭、着火剤を用意",
                priority: .medium,
                status: .assigned,
                assignedTo: "鈴木さん",
                note: nil,
                createdAt: Date(),
                updatedAt: Date()
            ),
            Task(
                id: "task-4",
                title: "ゴミ袋の準備",
                description: "大きめのゴミ袋を複数用意",
                priority: .low,
                status: .unassigned,
                assignedTo: nil,
                note: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
        ]
        
        return viewModel
    }
    
    static func previewParticipantViewModel() -> ParticipantViewModel {
        let mockRepository = MockParticipantRepository()
        let mockAIService = MockAIService()
        let viewModel = ParticipantViewModel(
            participantRepository: mockRepository,
            aiService: mockAIService
        )
        
        // プレビュー用の参加者データを設定
        viewModel.participants = [
            Participant(
                id: "participant-1",
                name: "田中太郎",
                expectedPayment: 5000,
                paymentStatus: .paid,
                paidAmount: 5000,
                joinedAt: Date(),
                updatedAt: Date()
            ),
            Participant(
                id: "participant-2",
                name: "佐藤花子",
                expectedPayment: 5000,
                paymentStatus: .paid,
                paidAmount: 5000,
                joinedAt: Date(),
                updatedAt: Date()
            ),
            Participant(
                id: "participant-3",
                name: "鈴木一郎",
                expectedPayment: 5000,
                paymentStatus: .unpaid,
                paidAmount: 0,
                joinedAt: Date(),
                updatedAt: Date()
            )
        ]
        
        // 集金計算を更新
        viewModel.totalExpected = 15000
        viewModel.totalCollected = 10000
        
        return viewModel
    }
}

// MARK: - Mock Repositories for Preview

class MockTaskRepository: TaskRepository {
    func addTask(_ task: Task, eventId: String) async throws -> String {
        return task.id
    }
    
    func getTask(taskId: String, eventId: String) async throws -> Task {
        // Mock implementation
        throw NSError(domain: "MockError", code: 404, userInfo: nil)
    }
    
    func updateTask(_ task: Task, eventId: String) async throws {
        // Mock implementation
    }
    
    func deleteTask(taskId: String, eventId: String) async throws {
        // Mock implementation
    }
    
    func observeTasks(eventId: String) -> AsyncStream<[Task]> {
        return AsyncStream { continuation in
            continuation.finish()
        }
    }
}

class MockParticipantRepository: ParticipantRepository {
    func addParticipant(_ participant: Participant, eventId: String) async throws -> String {
        return participant.id
    }
    
    func getParticipant(participantId: String, eventId: String) async throws -> Participant {
        // Mock implementation
        throw NSError(domain: "MockError", code: 404, userInfo: nil)
    }
    
    func updateParticipant(_ participant: Participant, eventId: String) async throws {
        // Mock implementation
    }
    
    func deleteParticipant(participantId: String, eventId: String) async throws {
        // Mock implementation
    }
    
    func observeParticipants(eventId: String) -> AsyncStream<[Participant]> {
        return AsyncStream { continuation in
            continuation.finish()
        }
    }
}
#endif
