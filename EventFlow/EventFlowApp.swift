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
    
    init() {
        // Firebase初期化
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
