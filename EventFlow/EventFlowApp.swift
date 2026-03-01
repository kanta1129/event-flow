//
//  EventFlowApp.swift
//  EventFlow
//
//  Created by Kiro
//

import SwiftUI
import FirebaseCore

@main
struct EventFlowApp: App {
    
    // NetworkMonitorを初期化（アプリ起動時に監視開始）
    private let networkMonitor = NetworkMonitor.shared
    
    init() {
        // Firebase初期化
        FirebaseApp.configure()
        
        // ネットワーク監視を開始
        networkMonitor.startMonitoring()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
