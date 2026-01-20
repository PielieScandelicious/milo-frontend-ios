//
//  ContentView.swift
//  dobby-ios
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var transactionManager = TransactionManager()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ViewTab()
                .tabItem {
                    Label("View", systemImage: "chart.pie.fill")
                }
                .tag(0)
            
            ScanTab()
                .tabItem {
                    Label("Scan", systemImage: "qrcode.viewfinder")
                }
                .tag(1)
            
            DobbyTab()
                .tabItem {
                    Label("Dobby", systemImage: "sparkles")
                }
                .tag(2)
        }
        .environmentObject(transactionManager)
        .preferredColorScheme(.dark)
    }
    

}

// MARK: - View Tab
struct ViewTab: View {
    var body: some View {
        NavigationStack {
            OverviewView()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - Scan Tab
struct ScanTab: View {
    var body: some View {
        NavigationStack {
            ReceiptScanView()
                .toolbar(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - Dobby Tab
struct DobbyTab: View {
    var body: some View {
        NavigationStack {
            DobbyAIChatView()
                .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

#Preview {
    ContentView()
}
