//
//  ContentView.swift
//  EventFlow
//
//  Created by Kiro
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("EventFlow")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("イベント幹事の負担を軽減")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    // イベント作成画面への遷移（後で実装）
                }) {
                    Text("新しいイベントを作成")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("ホーム")
        }
    }
}

#Preview {
    ContentView()
}
