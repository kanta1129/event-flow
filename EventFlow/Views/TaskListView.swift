//
//  TaskListView.swift
//  EventFlow
//
//  タスク一覧表示と管理画面
//  Requirements: 2.4, 2.5, 2.6, 5.1, 5.4, 5.6
//

import SwiftUI

/// タスク一覧表示と管理画面
/// タスクの追加、編集、削除、ステータス別表示を提供
struct TaskListView: View {
    
    // MARK: - State Properties
    
    @ObservedObject var taskViewModel: TaskViewModel
    let eventId: String
    
    @State private var showingAddTask = false
    @State private var editingTask: Task?
    @State private var filterStatus: TaskStatus?
    @State private var showingDeleteConfirmation = false
    @State private var taskToDelete: Task?
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // フィルターセクション
            filterSection
            
            // タスクリスト
            if filteredTasks.isEmpty {
                emptyStateView
            } else {
                taskList
            }
        }
        .navigationTitle("タスク")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                addButton
            }
        }
        .sheet(isPresented: $showingAddTask) {
            TaskFormView(
                eventId: eventId,
                taskViewModel: taskViewModel,
                mode: .add
            )
        }
        .sheet(item: $editingTask) { task in
            TaskFormView(
                eventId: eventId,
                taskViewModel: taskViewModel,
                mode: .edit(task)
            )
        }
        .alert("タスクを削除", isPresented: $showingDeleteConfirmation) {
            Button("キャンセル", role: .cancel) {}
            Button("削除", role: .destructive) {
                if let task = taskToDelete {
                    deleteTask(task)
                }
            }
        } message: {
            if let task = taskToDelete {
                Text("「\(task.title)」を削除してもよろしいですか？")
            }
        }
    }
    
    // MARK: - Filter Section
    
    /// フィルターセクション
    /// Requirements: 5.4
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // すべて表示
                FilterChip(
                    title: "すべて",
                    count: taskViewModel.tasks.count,
                    isSelected: filterStatus == nil,
                    color: .gray
                ) {
                    filterStatus = nil
                }
                
                // 未割り当て
                FilterChip(
                    title: "未割り当て",
                    count: taskViewModel.tasks(withStatus: .unassigned).count,
                    isSelected: filterStatus == .unassigned,
                    color: .gray
                ) {
                    filterStatus = .unassigned
                }
                
                // 割り当て済み
                FilterChip(
                    title: "割り当て済み",
                    count: taskViewModel.tasks(withStatus: .assigned).count,
                    isSelected: filterStatus == .assigned,
                    color: .blue
                ) {
                    filterStatus = .assigned
                }
                
                // 進行中
                FilterChip(
                    title: "進行中",
                    count: taskViewModel.tasks(withStatus: .inProgress).count,
                    isSelected: filterStatus == .inProgress,
                    color: .orange
                ) {
                    filterStatus = .inProgress
                }
                
                // 完了
                FilterChip(
                    title: "完了",
                    count: taskViewModel.tasks(withStatus: .completed).count,
                    isSelected: filterStatus == .completed,
                    color: .green
                ) {
                    filterStatus = .completed
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Task List
    
    /// タスクリスト
    /// Requirements: 5.1, 5.4, 5.6
    private var taskList: some View {
        List {
            ForEach(filteredTasks) { task in
                TaskRowView(task: task)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingTask = task
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        // 削除アクション
                        Button(role: .destructive) {
                            taskToDelete = task
                            showingDeleteConfirmation = true
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                        
                        // 編集アクション
                        Button {
                            editingTask = task
                        } label: {
                            Label("編集", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - Empty State View
    
    /// 空状態ビュー
    /// Requirements: 5.6
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checklist")
                .font(.system(size: 64))
                .foregroundColor(.gray.opacity(0.5))
            
            Text(emptyStateMessage)
                .font(.headline)
                .foregroundColor(.secondary)
            
            if filterStatus != nil {
                Button("フィルターをクリア") {
                    filterStatus = nil
                }
                .buttonStyle(.bordered)
            } else {
                Button("最初のタスクを追加") {
                    showingAddTask = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Add Button
    
    /// タスク追加ボタン
    /// Requirements: 2.4
    private var addButton: some View {
        Button(action: {
            showingAddTask = true
        }) {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
        }
    }
    
    // MARK: - Computed Properties
    
    /// フィルタリングされたタスク
    private var filteredTasks: [Task] {
        if let status = filterStatus {
            return taskViewModel.tasks(withStatus: status)
        }
        return taskViewModel.tasks
    }
    
    /// 空状態メッセージ
    private var emptyStateMessage: String {
        if let status = filterStatus {
            switch status {
            case .unassigned:
                return "未割り当てのタスクはありません"
            case .assigned:
                return "割り当て済みのタスクはありません"
            case .inProgress:
                return "進行中のタスクはありません"
            case .completed:
                return "完了したタスクはありません"
            }
        }
        return "タスクがまだありません"
    }
    
    // MARK: - Private Methods
    
    /// タスクを削除
    /// Requirements: 2.6
    private func deleteTask(_ task: Task) {
        Task {
            await taskViewModel.deleteTask(taskId: task.id, eventId: eventId)
        }
    }
}

// MARK: - Supporting Views

/// フィルターチップ
struct FilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        isSelected ? Color.white.opacity(0.3) : color.opacity(0.2)
                    )
                    .cornerRadius(8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected ? color : Color(.systemGray5)
            )
            .foregroundColor(
                isSelected ? .white : .primary
            )
            .cornerRadius(20)
        }
    }
}

/// タスク行ビュー
/// Requirements: 5.4, 5.6
struct TaskRowView: View {
    let task: Task
    
    var body: some View {
        HStack(spacing: 12) {
            // ステータスインジケーター
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: 6) {
                // タイトルと優先度
                HStack {
                    Text(task.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // 優先度バッジ
                    PriorityBadge(priority: task.priority)
                }
                
                // 説明
                Text(task.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                // 担当者とメモ
                HStack(spacing: 12) {
                    if let assignedTo = task.assignedTo {
                        Label(assignedTo, systemImage: "person.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    if let note = task.note, !note.isEmpty {
                        Label("メモあり", systemImage: "note.text")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    /// ステータスカラー
    /// Requirements: 5.6
    private var statusColor: Color {
        switch task.status {
        case .unassigned: return .gray
        case .assigned: return .blue
        case .inProgress: return .orange
        case .completed: return .green
        }
    }
}

/// 優先度バッジ
struct PriorityBadge: View {
    let priority: TaskPriority
    
    var body: some View {
        Text(priorityText)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(priorityColor.opacity(0.2))
            .foregroundColor(priorityColor)
            .cornerRadius(6)
    }
    
    private var priorityText: String {
        switch priority {
        case .high: return "高"
        case .medium: return "中"
        case .low: return "低"
        }
    }
    
    private var priorityColor: Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }
}

/// タスクフォームビュー
/// Requirements: 2.4, 2.5
struct TaskFormView: View {
    
    enum Mode {
        case add
        case edit(Task)
        
        var title: String {
            switch self {
            case .add: return "タスクを追加"
            case .edit: return "タスクを編集"
            }
        }
    }
    
    let eventId: String
    @ObservedObject var taskViewModel: TaskViewModel
    let mode: Mode
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var priority: TaskPriority = .medium
    @State private var status: TaskStatus = .unassigned
    @State private var assignedTo: String = ""
    @State private var note: String = ""
    @State private var isSaving = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本情報") {
                    TextField("タイトル", text: $title)
                    
                    TextField("説明", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("詳細") {
                    Picker("優先度", selection: $priority) {
                        Text("高").tag(TaskPriority.high)
                        Text("中").tag(TaskPriority.medium)
                        Text("低").tag(TaskPriority.low)
                    }
                    
                    Picker("ステータス", selection: $status) {
                        Text("未割り当て").tag(TaskStatus.unassigned)
                        Text("割り当て済み").tag(TaskStatus.assigned)
                        Text("進行中").tag(TaskStatus.inProgress)
                        Text("完了").tag(TaskStatus.completed)
                    }
                }
                
                Section("担当者") {
                    TextField("担当者名（任意）", text: $assignedTo)
                }
                
                Section("メモ") {
                    TextField("メモ（任意）", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveTask()
                    }
                    .disabled(!isValid || isSaving)
                }
            }
            .onAppear {
                loadTaskData()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !description.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    // MARK: - Private Methods
    
    private func loadTaskData() {
        if case .edit(let task) = mode {
            title = task.title
            description = task.description
            priority = task.priority
            status = task.status
            assignedTo = task.assignedTo ?? ""
            note = task.note ?? ""
        }
    }
    
    private func saveTask() {
        isSaving = true
        
        Task {
            switch mode {
            case .add:
                let newTask = Task(
                    id: UUID().uuidString,
                    title: title.trimmingCharacters(in: .whitespaces),
                    description: description.trimmingCharacters(in: .whitespaces),
                    priority: priority,
                    status: status,
                    assignedTo: assignedTo.isEmpty ? nil : assignedTo,
                    note: note.isEmpty ? nil : note,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                await taskViewModel.addTask(newTask, eventId: eventId)
                
            case .edit(let existingTask):
                let updatedTask = Task(
                    id: existingTask.id,
                    title: title.trimmingCharacters(in: .whitespaces),
                    description: description.trimmingCharacters(in: .whitespaces),
                    priority: priority,
                    status: status,
                    assignedTo: assignedTo.isEmpty ? nil : assignedTo,
                    note: note.isEmpty ? nil : note,
                    createdAt: existingTask.createdAt,
                    updatedAt: Date()
                )
                await taskViewModel.updateTask(updatedTask, eventId: eventId)
            }
            
            isSaving = false
            dismiss()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct TaskListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TaskListView(
                taskViewModel: previewTaskViewModel(),
                eventId: "preview-event-id"
            )
        }
    }
    
    static func previewTaskViewModel() -> TaskViewModel {
        let mockRepository = MockTaskRepository()
        let viewModel = TaskViewModel(taskRepository: mockRepository)
        
        viewModel.tasks = [
            Task(
                id: "1",
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
                id: "2",
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
                id: "3",
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
                id: "4",
                title: "ゴミ袋の準備",
                description: "大きめのゴミ袋を複数用意",
                priority: .low,
                status: .unassigned,
                assignedTo: nil,
                note: nil,
                createdAt: Date(),
                updatedAt: Date()
            ),
            Task(
                id: "5",
                title: "テーブルと椅子の手配",
                description: "折りたたみテーブル2台、椅子10脚",
                priority: .medium,
                status: .unassigned,
                assignedTo: nil,
                note: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
        ]
        
        return viewModel
    }
}

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
#endif
