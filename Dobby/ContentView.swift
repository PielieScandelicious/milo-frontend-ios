//
//  ContentView.swift
//  Dobby
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var transactionManager = TransactionManager()
    
    var body: some View {
        TabView {
            ViewTab()
                .tabItem {
                    Label("View", systemImage: "eye")
                }
            
            ScanTab()
                .tabItem {
                    Label("Scan", systemImage: "qrcode.viewfinder")
                }
            
            DobbyTab()
                .tabItem {
                    Label("Dobby", systemImage: "sparkles")
                }
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
                .navigationBarHidden(true)
        }
    }
}

// MARK: - Scan Tab
struct ScanTab: View {
    var body: some View {
        NavigationStack {
            ReceiptScanView()
                .navigationBarHidden(true)
        }
    }
}

// MARK: - Dobby Tab
struct DobbyTab: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.05).ignoresSafeArea()
                
                VStack {
                    // Empty content
                }
            }
            .navigationTitle("Dobby")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    ContentView()
}
