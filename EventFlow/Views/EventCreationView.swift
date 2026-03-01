//
//  EventCreationView.swift
//  EventFlow
//
//  イベント作成画面 - イベント基本情報の入力とAI生成のトリガー
//  Requirements: 1.1
//

import SwiftUI

/// イベント作成画面
/// イベントの基本情報を入力し、AIによるテンプレート生成をトリガーする
struct EventCreationView: View {
    
    // MARK: - State Properties
    
    @StateObject private var viewModel: EventViewModel
    
    @State private var title: String = ""
    @State private var eventType: String = ""
    @State private var participantCount: Int = 10
    @State private var eventDate: Date = Date()
    @State private var budget: String = ""
    
    @State private var showingError: Bool = false
    @State private var validationErrors: [String] = []
    
    // テンプレート編集用の状態
    @State private var editableTemplate: EventTemplate?
    
    // MARK: - Initialization
    
    init(viewModel: EventViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Form {
                // イベント基本情報セクション
                Section(header: Text("イベント情報")) {
                    // タイトル入力
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("イベント名", text: $title)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        if let error = validationError(for: "title") {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    // イベントタイプ入力
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("イベントタイプ（例: BBQ、飲み会）", text: $eventType)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        if let error = validationError(for: "eventType") {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    // 参加者数入力
                    VStack(alignment: .leading, spacing: 4) {
                        Stepper(value: $participantCount, in: 1...1000) {
                            HStack {
                                Text("参加者数")
                                Spacer()
                                Text("\(participantCount)人")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let error = validationError(for: "participantCount") {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    // 日時選択
                    DatePicker(
                        "開催日時",
                        selection: $eventDate,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    
                    // 予算入力
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("予算（1人あたり）")
                            Spacer()
                            TextField("金額", text: $budget)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                            Text("円")
                        }
                        
                        if let error = validationError(for: "budget") {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                // AI生成ボタンセクション
                Section {
                    Button(action: generateTemplate) {
                        HStack {
                            Spacer()
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .padding(.trailing, 8)
                                Text("生成中...")
                            } else {
                                Image(systemName: "sparkles")
                                Text("AIでイベントを生成")
                            }
                            Spacer()
                        }
                    }
                    .disabled(!isFormValid || viewModel.isLoading)
                }
                
                // ヘルプテキスト
                Section {
                    Text("AIがイベントタイプと参加者数に基づいて、買い物リスト、タスク、スケジュールを自動生成します。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // テンプレート表示・編集セクション
                if let template = editableTemplate {
                    // 買い物リストセクション
                    Section(header: HStack {
                        Text("買い物リスト")
                        Spacer()
                        Button(action: addShoppingItem) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }) {
                        ForEach($editableTemplate!.shoppingList) { $item in
                            ShoppingItemRow(item: $item, onDelete: {
                                deleteShoppingItem(item)
                            })
                        }
                    }
                    
                    // タスクリストセクション
                    Section(header: HStack {
                        Text("タスクリスト")
                        Spacer()
                        Button(action: addTask) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }) {
                        ForEach($editableTemplate!.tasks) { $task in
                            TaskRow(task: $task, onDelete: {
                                deleteTask(task)
                            })
                        }
                    }
                    
                    // スケジュールセクション
                    Section(header: HStack {
                        Text("スケジュール")
                        Spacer()
                        Button(action: addScheduleItem) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }) {
                        ForEach($editableTemplate!.schedule) { $scheduleItem in
                            ScheduleItemRow(scheduleItem: $scheduleItem, onDelete: {
                                deleteScheduleItem(scheduleItem)
                            })
                        }
                    }
                }
            }
            .navigationTitle("新規イベント作成")
            .navigationBarTitleDisplayMode(.large)
            .alert("エラー", isPresented: $showingError) {
                Button("OK", role: .cancel) {
                    showingError = false
                }
            } message: {
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                }
            }
            .onChange(of: viewModel.error) { newError in
                if newError != nil {
                    showingError = true
                }
            }
            .onChange(of: viewModel.generatedTemplate) { newTemplate in
                if let template = newTemplate {
                    editableTemplate = template
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// フォームのバリデーション状態
    private var isFormValid: Bool {
        validateForm()
        return validationErrors.isEmpty
    }
    
    /// フォーム全体のバリデーション
    @discardableResult
    private func validateForm() -> Bool {
        validationErrors.removeAll()
        
        // タイトルのバリデーション
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        if trimmedTitle.isEmpty {
            validationErrors.append("title:イベント名を入力してください")
        } else if trimmedTitle.count > 100 {
            validationErrors.append("title:イベント名は100文字以内で入力してください")
        }
        
        // イベントタイプのバリデーション
        let trimmedEventType = eventType.trimmingCharacters(in: .whitespaces)
        if trimmedEventType.isEmpty {
            validationErrors.append("eventType:イベントタイプを入力してください")
        } else if trimmedEventType.count > 50 {
            validationErrors.append("eventType:イベントタイプは50文字以内で入力してください")
        }
        
        // 参加者数のバリデーション
        if participantCount < 1 {
            validationErrors.append("participantCount:参加者数は1人以上である必要があります")
        } else if participantCount > 1000 {
            validationErrors.append("participantCount:参加者数は1000人以下である必要があります")
        }
        
        // 予算のバリデーション（オプション）
        if !budget.isEmpty {
            if let budgetValue = Double(budget) {
                if budgetValue < 0 {
                    validationErrors.append("budget:金額は0以上である必要があります")
                }
            } else {
                validationErrors.append("budget:有効な金額を入力してください")
            }
        }
        
        return validationErrors.isEmpty
    }
    
    /// 特定のフィールドのバリデーションエラーを取得
    /// - Parameter field: フィールド名
    /// - Returns: エラーメッセージ（存在する場合）
    private func validationError(for field: String) -> String? {
        return validationErrors.first { $0.hasPrefix("\(field):") }?
            .replacingOccurrences(of: "\(field):", with: "")
    }
    
    /// AIテンプレート生成を実行
    private func generateTemplate() {
        // バリデーション実行
        guard validateForm() else {
            return
        }
        
        // 予算の変換（オプション）
        let budgetValue: Double? = budget.isEmpty ? nil : Double(budget)
        
        // AI生成を実行
        Task {
            await viewModel.generateTemplate(
                eventType: eventType.trimmingCharacters(in: .whitespaces),
                participantCount: participantCount,
                budget: budgetValue
            )
        }
    }
    
    // MARK: - Template Editing Methods
    
    /// 買い物リストにアイテムを追加
    private func addShoppingItem() {
        guard editableTemplate != nil else { return }
        let newItem = ShoppingItem(item: "", quantity: "", estimatedCost: 0)
        editableTemplate?.shoppingList.append(newItem)
    }
    
    /// 買い物リストからアイテムを削除
    private func deleteShoppingItem(_ item: ShoppingItem) {
        editableTemplate?.shoppingList.removeAll { $0.id == item.id }
    }
    
    /// タスクリストにタスクを追加
    private func addTask() {
        guard editableTemplate != nil else { return }
        let newTask = TaskTemplate(title: "", description: "", priority: "medium")
        editableTemplate?.tasks.append(newTask)
    }
    
    /// タスクリストからタスクを削除
    private func deleteTask(_ task: TaskTemplate) {
        editableTemplate?.tasks.removeAll { $0.id == task.id }
    }
    
    /// スケジュールにアイテムを追加
    private func addScheduleItem() {
        guard editableTemplate != nil else { return }
        let newItem = ScheduleItem(time: "", activity: "")
        editableTemplate?.schedule.append(newItem)
    }
    
    /// スケジュールからアイテムを削除
    private func deleteScheduleItem(_ item: ScheduleItem) {
        editableTemplate?.schedule.removeAll { $0.id == item.id }
    }
}

// MARK: - Row Components

/// 買い物リストアイテムの行
struct ShoppingItemRow: View {
    @Binding var item: ShoppingItem
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("商品名", text: $item.item)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            
            HStack {
                TextField("数量", text: $item.quantity)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 100)
                
                Spacer()
                
                Text("予算:")
                    .foregroundColor(.secondary)
                TextField("金額", value: $item.estimatedCost, format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 80)
                Text("円")
            }
        }
        .padding(.vertical, 4)
    }
}

/// タスクの行
struct TaskRow: View {
    @Binding var task: TaskTemplate
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("タスク名", text: $task.title)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            
            TextField("説明", text: $task.description)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            HStack {
                Text("優先度:")
                    .foregroundColor(.secondary)
                
                Picker("優先度", selection: $task.priority) {
                    Text("高").tag("high")
                    Text("中").tag("medium")
                    Text("低").tag("low")
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            if let assignedTo = task.assignedTo, !assignedTo.isEmpty {
                HStack {
                    Image(systemName: "person.fill")
                        .foregroundColor(.blue)
                    Text("担当: \(assignedTo)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// スケジュールアイテムの行
struct ScheduleItemRow: View {
    @Binding var scheduleItem: ScheduleItem
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("時間 (HH:mm)", text: $scheduleItem.time)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 100)
                
                Spacer()
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            
            TextField("アクティビティ", text: $scheduleItem.activity)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#if DEBUG
struct EventCreationView_Previews: PreviewProvider {
    static var previews: some View {
        // プレビュー用のモックViewModel
        let mockRepository = MockEventRepository()
        let mockAIService = MockAIService()
        let viewModel = EventViewModel(
            eventRepository: mockRepository,
            aiService: mockAIService
        )
        
        return EventCreationView(viewModel: viewModel)
    }
}

// MARK: - Mock Objects for Preview

class MockEventRepository: EventRepository {
    func createEvent(_ event: Event) async throws -> String {
        return "mock-event-id"
    }
    
    func getEvent(id: String) async throws -> Event {
        return Event(
            id: id,
            title: "Mock Event",
            eventType: "BBQ",
            date: Date(),
            organizerId: "mock-organizer",
            participantCount: 10,
            budget: 5000,
            shareUrl: "https://eventflow.app/event/mock",
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    func updateEvent(_ event: Event) async throws {
        // Mock implementation
    }
    
    func deleteEvent(id: String) async throws {
        // Mock implementation
    }
    
    func observeEvent(id: String) -> AsyncStream<Event> {
        return AsyncStream { continuation in
            continuation.finish()
        }
    }
}

class MockAIService: AIService {
    func generateEventTemplate(eventType: String, participantCount: Int, budget: Double?) async throws -> EventTemplate {
        return EventTemplate(
            shoppingList: [
                ShoppingItem(item: "肉", quantity: "3kg", estimatedCost: 3000),
                ShoppingItem(item: "野菜", quantity: "適量", estimatedCost: 1500)
            ],
            tasks: [
                TaskTemplate(title: "買い出し", description: "食材の購入", priority: "high"),
                TaskTemplate(title: "場所取り", description: "BBQ場の確保", priority: "high")
            ],
            schedule: [
                ScheduleItem(time: "10:00", activity: "集合"),
                ScheduleItem(time: "11:00", activity: "BBQ開始")
            ]
        )
    }
    
    func generateReminderMessage(context: ReminderContext) async throws -> String {
        return "これはモックの催促メッセージです。"
    }
}
#endif
