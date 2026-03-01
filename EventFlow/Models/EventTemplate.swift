import Foundation

/// AIが生成するイベントテンプレート
struct EventTemplate: Codable {
    let shoppingList: [ShoppingItem]
    let tasks: [TaskTemplate]
    let schedule: [ScheduleItem]
}

/// 買い物リストのアイテム（テンプレート用）
struct ShoppingItem: Codable {
    let item: String
    let quantity: String
    let estimatedCost: Double
}

/// タスクテンプレート
struct TaskTemplate: Codable {
    let title: String
    let description: String
    let priority: String // "high", "medium", "low"
}

/// スケジュールアイテム
struct ScheduleItem: Codable {
    let time: String // "HH:mm" 形式
    let activity: String
}
