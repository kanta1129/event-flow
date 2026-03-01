//
//  EventViewModel.swift
//  EventFlow
//
//  イベント管理のビジネスロジックと状態管理を担当するViewModel
//  Requirements: 1.1, 2.8, 3.1
//

import Foundation
import Combine

/// イベント管理のViewModel
/// ObservableObjectプロトコルに準拠し、SwiftUIビューとバインド可能
@MainActor
class EventViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 現在のイベント
    @Published var event: Event?
    
    /// ローディング状態
    @Published var isLoading: Bool = false
    
    /// エラー情報
    @Published var error: Error?
    
    // MARK: - Dependencies
    
    private let eventRepository: EventRepository
    private let aiService: AIService
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// EventViewModelの初期化
    /// - Parameters:
    ///   - eventRepository: イベントデータアクセス用のリポジトリ
    ///   - aiService: AI生成サービス
    init(eventRepository: EventRepository, aiService: AIService) {
        self.eventRepository = eventRepository
        self.aiService = aiService
    }
    
    // MARK: - Public Methods
    
    /// AIを使用してイベントテンプレートを生成
    /// Requirements: 1.1, 1.2, 1.3, 1.4
    /// - Parameters:
    ///   - eventType: イベントのタイプ（例: "BBQ", "飲み会"）
    ///   - participantCount: 参加者数
    ///   - budget: 予算（オプション）
    func generateTemplate(eventType: String, participantCount: Int, budget: Double? = nil) async {
        isLoading = true
        error = nil
        
        do {
            let template = try await aiService.generateEventTemplate(
                eventType: eventType,
                participantCount: participantCount,
                budget: budget
            )
            
            // テンプレートからイベントを作成
            // 注: 実際のイベント作成は別の関数で行うため、ここでは一時的な処理
            // テンプレートデータは後続の処理で使用される
            
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }
    
    /// イベントを更新
    /// Requirements: 2.8
    /// - Parameter event: 更新するイベント
    func updateEvent(_ event: Event) async {
        isLoading = true
        error = nil
        
        do {
            try await eventRepository.updateEvent(event)
            self.event = event
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }
    
    /// イベントの共有URLを生成
    /// Requirements: 3.1
    /// - Returns: イベント共有用のユニークURL
    func shareEventURL() -> URL? {
        guard let event = event else {
            return nil
        }
        
        // イベントIDベースのユニークURL生成
        // 本番環境では実際のドメインを使用
        let baseURL = "https://eventflow.app/event"
        let urlString = "\(baseURL)/\(event.id)"
        
        return URL(string: urlString)
    }
    
    /// イベントを削除
    /// - Throws: データベースエラー
    func deleteEvent() async {
        guard let event = event else {
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            try await eventRepository.deleteEvent(id: event.id)
            self.event = nil
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }
    
    /// イベントを読み込み
    /// - Parameter id: イベントID
    func loadEvent(id: String) async {
        isLoading = true
        error = nil
        
        do {
            let event = try await eventRepository.getEvent(id: id)
            self.event = event
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }
    
    /// イベントのリアルタイム監視を開始
    /// Requirements: 5.1
    /// - Parameter id: 監視するイベントID
    func observeEvent(id: String) {
        let stream = eventRepository.observeEvent(id: id)
        
        Task {
            for await event in stream {
                self.event = event
            }
        }
    }
}
