import Foundation

/// AIが生成するイベントテンプレート
struct EventTemplate: Codable {
    var shoppingList: [ShoppingItem]
    var tasks: [TaskTemplate]
    var schedule: [ScheduleItem]
}

/// 買い物リストのアイテム（テンプレート用）
struct ShoppingItem: Identifiable, Codable {
    var id: String = UUID().uuidString
    var item: String
    var quantity: String
    var estimatedCost: Double
    
    enum CodingKeys: String, CodingKey {
        case item, quantity, estimatedCost
    }
    
    init(id: String = UUID().uuidString, item: String, quantity: String, estimatedCost: Double) {
        self.id = id
        self.item = item
        self.quantity = quantity
        self.estimatedCost = estimatedCost
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID().uuidString
        self.item = try container.decode(String.self, forKey: .item)
        self.quantity = try container.decode(String.self, forKey: .quantity)
        self.estimatedCost = try container.decode(Double.self, forKey: .estimatedCost)
    }
}

/// タスクテンプレート
struct TaskTemplate: Identifiable, Codable {
    var id: String = UUID().uuidString
    var title: String
    var description: String
    var priority: String // "high", "medium", "low"
    var assignedTo: String? = nil
    
    enum CodingKeys: String, CodingKey {
        case title, description, priority, assignedTo
    }
    
    init(id: String = UUID().uuidString, title: String, description: String, priority: String, assignedTo: String? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.priority = priority
        self.assignedTo = assignedTo
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID().uuidString
        self.title = try container.decode(String.self, forKey: .title)
        self.description = try container.decode(String.self, forKey: .description)
        self.priority = try container.decode(String.self, forKey: .priority)
        self.assignedTo = try container.decodeIfPresent(String.self, forKey: .assignedTo)
    }
}

/// スケジュールアイテム
struct ScheduleItem: Identifiable, Codable {
    var id: String = UUID().uuidString
    var time: String // "HH:mm" 形式
    var activity: String
    
    enum CodingKeys: String, CodingKey {
        case time, activity
    }
    
    init(id: String = UUID().uuidString, time: String, activity: String) {
        self.id = id
        self.time = time
        self.activity = activity
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID().uuidString
        self.time = try container.decode(String.self, forKey: .time)
        self.activity = try container.decode(String.self, forKey: .activity)
    }
}

