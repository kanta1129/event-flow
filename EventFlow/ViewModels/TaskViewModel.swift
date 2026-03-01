//
//  TaskViewModel.swift
//  EventFlow
//
//  タスク管理のビジネスロジックと状態管理を担当するViewModel
//  Requirements: 2.4, 2.5, 2.6, 5.1, 5.4
//

import Foundation
import Combine

/// タスク管理のViewModel
/// ObservableObjectプロトコルに準拠し、SwiftUIビューとバインド可能
@MainActor
class TaskViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// タスクのリスト
    @Published var tasks: [Task] = []
    
    /// ローディング状態
    @Published var isLoading: Bool = false
    
    /// エラー情報
    @Published var error: Error?
    
    // MARK: - Dependencies
    
    private let taskRepository: TaskRepository
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var currentEventId: String?
    
    // MARK: - Initialization
    
    /// TaskViewModelの初期化
    /// - Parameter taskRepository: タスクデータアクセス用のリポジトリ
    init(taskRepository: TaskRepository) {
        self.taskRepository = taskRepository
    }
    
    // MARK: - Public Methods
    
    /// タスクを追加
    /// Requirements: 2.4
    /// - Parameters:
    ///   - task: 追加するタスク
    ///   - eventId: タスクが属するイベントのID
    func addTask(_ task: Task, eventId: String) async {
        isLoading = true
        error = nil
        
        do {
            _ = try await taskRepository.addTask(task, eventId: eventId)
            // リアルタイムリスナーが自動的にタスクリストを更新するため、
            // ここでは明示的にtasks配列を更新しない
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }
    
    /// タスクを更新
    /// Requirements: 2.5
    /// - Parameters:
    ///   - task: 更新するタスク
    ///   - eventId: タスクが属するイベントのID
    func updateTask(_ task: Task, eventId: String) async {
        isLoading = true
        error = nil
        
        do {
            try await taskRepository.updateTask(task, eventId: eventId)
            // リアルタイムリスナーが自動的にタスクリストを更新するため、
            // ここでは明示的にtasks配列を更新しない
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }
    
    /// タスクを削除
    /// Requirements: 2.6
    /// - Parameters:
    ///   - taskId: 削除するタスクのID
    ///   - eventId: タスクが属するイベントのID
    func deleteTask(taskId: String, eventId: String) async {
        isLoading = true
        error = nil
        
        do {
            try await taskRepository.deleteTask(taskId: taskId, eventId: eventId)
            // リアルタイムリスナーが自動的にタスクリストを更新するため、
            // ここでは明示的にtasks配列を更新しない
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }
    
    /// タスクのリアルタイム監視を開始
    /// Requirements: 5.1, 5.4
    /// - Parameter eventId: 監視するイベントのID
    func observeTasks(eventId: String) {
        // 既存のリスナーをクリア
        cancellables.removeAll()
        currentEventId = eventId
        
        let stream = taskRepository.observeTasks(eventId: eventId)
        
        Task {
            for await tasks in stream {
                self.tasks = tasks
            }
        }
    }
    
    /// タスクの監視を停止
    func stopObserving() {
        cancellables.removeAll()
        currentEventId = nil
        tasks = []
    }
    
    /// 特定のステータスのタスクをフィルタリング
    /// - Parameter status: フィルタリングするステータス
    /// - Returns: 指定されたステータスのタスクの配列
    func tasks(withStatus status: TaskStatus) -> [Task] {
        return tasks.filter { $0.status == status }
    }
    
    /// 特定の優先度のタスクをフィルタリング
    /// - Parameter priority: フィルタリングする優先度
    /// - Returns: 指定された優先度のタスクの配列
    func tasks(withPriority priority: TaskPriority) -> [Task] {
        return tasks.filter { $0.priority == priority }
    }
    
    /// 完了したタスクの数を取得
    /// - Returns: 完了したタスクの数
    func completedTasksCount() -> Int {
        return tasks.filter { $0.status == .completed }.count
    }
    
    /// タスクの完了率を計算
    /// Requirements: 5.1
    /// - Returns: 完了率（0.0〜1.0）
    func completionRate() -> Double {
        guard !tasks.isEmpty else {
            return 0.0
        }
        let completedCount = completedTasksCount()
        return Double(completedCount) / Double(tasks.count)
    }
}
