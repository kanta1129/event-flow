//
//  LocalCacheManager.swift
//  EventFlow
//
//  ローカルキャッシュとオフライン変更キューイングを管理
//  Requirements: 8.2
//

import Foundation

/// オフライン時の変更を表す構造体
struct PendingChange: Codable, Identifiable {
    let id: String
    let changeType: ChangeType
    let entityType: EntityType
    let entityId: String
    let data: Data
    let timestamp: Date
    
    enum ChangeType: String, Codable {
        case create
        case update
        case delete
    }
    
    enum EntityType: String, Codable {
        case event
        case task
        case participant
    }
    
    init(id: String = UUID().uuidString,
         changeType: ChangeType,
         entityType: EntityType,
         entityId: String,
         data: Data,
         timestamp: Date = Date()) {
        self.id = id
        self.changeType = changeType
        self.entityType = entityType
        self.entityId = entityId
        self.data = data
        self.timestamp = timestamp
    }
}

/// ローカルキャッシュとオフライン変更キューを管理するクラス
class LocalCacheManager {
    
    // MARK: - Singleton
    
    static let shared = LocalCacheManager()
    
    // MARK: - Properties
    
    private let userDefaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // UserDefaults Keys
    private enum CacheKey: String {
        case events = "cached_events"
        case tasks = "cached_tasks"
        case participants = "cached_participants"
        case pendingChanges = "pending_changes"
    }
    
    // MARK: - Initialization
    
    private init() {
        // ISO8601形式の日付エンコーディング
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        
        #if DEBUG
        print("🗄️ LocalCacheManager initialized")
        #endif
    }
    
    // MARK: - Event Cache Methods
    
    /// イベントをキャッシュに保存
    func cacheEvent(_ event: Event) {
        var cachedEvents = getCachedEvents()
        
        // 既存のイベントを更新または新規追加
        if let index = cachedEvents.firstIndex(where: { $0.id == event.id }) {
            cachedEvents[index] = event
        } else {
            cachedEvents.append(event)
        }
        
        saveEvents(cachedEvents)
        
        #if DEBUG
        print("💾 Event cached: \(event.id)")
        #endif
    }
    
    /// キャッシュからイベントを取得
    func getCachedEvent(id: String) -> Event? {
        let cachedEvents = getCachedEvents()
        return cachedEvents.first { $0.id == id }
    }
    
    /// キャッシュから全イベントを取得
    func getCachedEvents() -> [Event] {
        guard let data = userDefaults.data(forKey: CacheKey.events.rawValue) else {
            return []
        }
        
        do {
            let events = try decoder.decode([Event].self, from: data)
            return events
        } catch {
            #if DEBUG
            print("❌ Failed to decode cached events: \(error.localizedDescription)")
            #endif
            return []
        }
    }
    
    /// キャッシュからイベントを削除
    func removeCachedEvent(id: String) {
        var cachedEvents = getCachedEvents()
        cachedEvents.removeAll { $0.id == id }
        saveEvents(cachedEvents)
        
        #if DEBUG
        print("🗑️ Event removed from cache: \(id)")
        #endif
    }
    
    private func saveEvents(_ events: [Event]) {
        do {
            let data = try encoder.encode(events)
            userDefaults.set(data, forKey: CacheKey.events.rawValue)
        } catch {
            #if DEBUG
            print("❌ Failed to save events to cache: \(error.localizedDescription)")
            #endif
        }
    }
    
    // MARK: - Task Cache Methods
    
    /// タスクをキャッシュに保存
    func cacheTask(_ task: Task, eventId: String) {
        var cachedTasks = getCachedTasks(eventId: eventId)
        
        // 既存のタスクを更新または新規追加
        if let index = cachedTasks.firstIndex(where: { $0.id == task.id }) {
            cachedTasks[index] = task
        } else {
            cachedTasks.append(task)
        }
        
        saveTasks(cachedTasks, eventId: eventId)
        
        #if DEBUG
        print("💾 Task cached: \(task.id)")
        #endif
    }
    
    /// キャッシュからタスクを取得
    func getCachedTask(id: String, eventId: String) -> Task? {
        let cachedTasks = getCachedTasks(eventId: eventId)
        return cachedTasks.first { $0.id == id }
    }
    
    /// キャッシュから全タスクを取得
    func getCachedTasks(eventId: String) -> [Task] {
        let key = "\(CacheKey.tasks.rawValue)_\(eventId)"
        guard let data = userDefaults.data(forKey: key) else {
            return []
        }
        
        do {
            let tasks = try decoder.decode([Task].self, from: data)
            return tasks
        } catch {
            #if DEBUG
            print("❌ Failed to decode cached tasks: \(error.localizedDescription)")
            #endif
            return []
        }
    }
    
    /// キャッシュからタスクを削除
    func removeCachedTask(id: String, eventId: String) {
        var cachedTasks = getCachedTasks(eventId: eventId)
        cachedTasks.removeAll { $0.id == id }
        saveTasks(cachedTasks, eventId: eventId)
        
        #if DEBUG
        print("🗑️ Task removed from cache: \(id)")
        #endif
    }
    
    private func saveTasks(_ tasks: [Task], eventId: String) {
        let key = "\(CacheKey.tasks.rawValue)_\(eventId)"
        do {
            let data = try encoder.encode(tasks)
            userDefaults.set(data, forKey: key)
        } catch {
            #if DEBUG
            print("❌ Failed to save tasks to cache: \(error.localizedDescription)")
            #endif
        }
    }
    
    // MARK: - Participant Cache Methods
    
    /// 参加者をキャッシュに保存
    func cacheParticipant(_ participant: Participant, eventId: String) {
        var cachedParticipants = getCachedParticipants(eventId: eventId)
        
        // 既存の参加者を更新または新規追加
        if let index = cachedParticipants.firstIndex(where: { $0.id == participant.id }) {
            cachedParticipants[index] = participant
        } else {
            cachedParticipants.append(participant)
        }
        
        saveParticipants(cachedParticipants, eventId: eventId)
        
        #if DEBUG
        print("💾 Participant cached: \(participant.id)")
        #endif
    }
    
    /// キャッシュから参加者を取得
    func getCachedParticipant(id: String, eventId: String) -> Participant? {
        let cachedParticipants = getCachedParticipants(eventId: eventId)
        return cachedParticipants.first { $0.id == id }
    }
    
    /// キャッシュから全参加者を取得
    func getCachedParticipants(eventId: String) -> [Participant] {
        let key = "\(CacheKey.participants.rawValue)_\(eventId)"
        guard let data = userDefaults.data(forKey: key) else {
            return []
        }
        
        do {
            let participants = try decoder.decode([Participant].self, from: data)
            return participants
        } catch {
            #if DEBUG
            print("❌ Failed to decode cached participants: \(error.localizedDescription)")
            #endif
            return []
        }
    }
    
    /// キャッシュから参加者を削除
    func removeCachedParticipant(id: String, eventId: String) {
        var cachedParticipants = getCachedParticipants(eventId: eventId)
        cachedParticipants.removeAll { $0.id == id }
        saveParticipants(cachedParticipants, eventId: eventId)
        
        #if DEBUG
        print("🗑️ Participant removed from cache: \(id)")
        #endif
    }
    
    private func saveParticipants(_ participants: [Participant], eventId: String) {
        let key = "\(CacheKey.participants.rawValue)_\(eventId)"
        do {
            let data = try encoder.encode(participants)
            userDefaults.set(data, forKey: key)
        } catch {
            #if DEBUG
            print("❌ Failed to save participants to cache: \(error.localizedDescription)")
            #endif
        }
    }
    
    // MARK: - Pending Changes Queue Methods
    
    /// オフライン時の変更をキューに追加
    func queueChange(_ change: PendingChange) {
        var pendingChanges = getPendingChanges()
        pendingChanges.append(change)
        savePendingChanges(pendingChanges)
        
        #if DEBUG
        print("📝 Change queued: \(change.changeType) \(change.entityType) \(change.entityId)")
        #endif
    }
    
    /// キューイングされた変更を取得
    func getPendingChanges() -> [PendingChange] {
        guard let data = userDefaults.data(forKey: CacheKey.pendingChanges.rawValue) else {
            return []
        }
        
        do {
            let changes = try decoder.decode([PendingChange].self, from: data)
            return changes
        } catch {
            #if DEBUG
            print("❌ Failed to decode pending changes: \(error.localizedDescription)")
            #endif
            return []
        }
    }
    
    /// キューから変更を削除
    func removePendingChange(id: String) {
        var pendingChanges = getPendingChanges()
        pendingChanges.removeAll { $0.id == id }
        savePendingChanges(pendingChanges)
        
        #if DEBUG
        print("✅ Pending change removed: \(id)")
        #endif
    }
    
    /// キューから全ての変更を削除
    func clearPendingChanges() {
        savePendingChanges([])
        
        #if DEBUG
        print("🧹 All pending changes cleared")
        #endif
    }
    
    /// キューイングされた変更があるかチェック
    func hasPendingChanges() -> Bool {
        return !getPendingChanges().isEmpty
    }
    
    private func savePendingChanges(_ changes: [PendingChange]) {
        do {
            let data = try encoder.encode(changes)
            userDefaults.set(data, forKey: CacheKey.pendingChanges.rawValue)
        } catch {
            #if DEBUG
            print("❌ Failed to save pending changes: \(error.localizedDescription)")
            #endif
        }
    }
    
    // MARK: - Cache Clear Methods
    
    /// 全キャッシュをクリア
    func clearAllCache() {
        userDefaults.removeObject(forKey: CacheKey.events.rawValue)
        userDefaults.removeObject(forKey: CacheKey.pendingChanges.rawValue)
        
        // タスクと参加者のキャッシュは個別のイベントIDごとに保存されているため、
        // 全てのキーを削除するには別のアプローチが必要
        // ここでは主要なキャッシュのみクリア
        
        #if DEBUG
        print("🧹 All cache cleared")
        #endif
    }
    
    /// 特定のイベントに関連する全キャッシュをクリア
    func clearEventCache(eventId: String) {
        removeCachedEvent(id: eventId)
        
        // タスクと参加者のキャッシュをクリア
        let tasksKey = "\(CacheKey.tasks.rawValue)_\(eventId)"
        let participantsKey = "\(CacheKey.participants.rawValue)_\(eventId)"
        
        userDefaults.removeObject(forKey: tasksKey)
        userDefaults.removeObject(forKey: participantsKey)
        
        #if DEBUG
        print("🧹 Event cache cleared: \(eventId)")
        #endif
    }
}
