//
//  NetworkMonitor.swift
//  EventFlow
//
//  ネットワーク状態を監視し、接続状態の変化を通知
//  Requirements: 8.3
//

import Foundation
import Network

/// ネットワーク接続状態を監視するクラス
class NetworkMonitor: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = NetworkMonitor()
    
    // MARK: - Properties
    
    /// 現在のネットワーク接続状態
    @Published private(set) var isConnected: Bool = false
    
    /// ネットワーク接続タイプ
    @Published private(set) var connectionType: ConnectionType = .unknown
    
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.eventflow.networkmonitor")
    
    /// ネットワーク接続タイプ
    enum ConnectionType {
        case wifi
        case cellular
        case wiredEthernet
        case unknown
    }
    
    // MARK: - Initialization
    
    private init() {
        monitor = NWPathMonitor()
        startMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// ネットワーク監視を開始
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            let wasConnected = self.isConnected
            let isNowConnected = path.status == .satisfied
            
            DispatchQueue.main.async {
                self.isConnected = isNowConnected
                self.connectionType = self.determineConnectionType(from: path)
                
                #if DEBUG
                print("🌐 Network status changed: \(isNowConnected ? "Connected" : "Disconnected") (\(self.connectionType))")
                #endif
                
                // 再接続時の通知
                if !wasConnected && isNowConnected {
                    self.notifyReconnection()
                }
            }
        }
        
        monitor.start(queue: queue)
        
        #if DEBUG
        print("🌐 NetworkMonitor started")
        #endif
    }
    
    /// ネットワーク監視を停止
    func stopMonitoring() {
        monitor.cancel()
        
        #if DEBUG
        print("🌐 NetworkMonitor stopped")
        #endif
    }
    
    // MARK: - Private Methods
    
    /// ネットワーク接続タイプを判定
    private func determineConnectionType(from path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .wiredEthernet
        } else {
            return .unknown
        }
    }
    
    /// 再接続時の通知を送信
    private func notifyReconnection() {
        #if DEBUG
        print("🔄 Network reconnected - triggering sync")
        #endif
        
        // 同期マネージャーに通知を送信
        NotificationCenter.default.post(
            name: .networkReconnected,
            object: nil
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// ネットワーク再接続時の通知
    static let networkReconnected = Notification.Name("networkReconnected")
}
