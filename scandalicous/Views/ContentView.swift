//
//  ContentView.swift
//  Scandalicious
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @StateObject private var transactionManager = TransactionManager()
    @State private var selectedTab: Tab = .view
    @State private var showSignOutConfirmation = false
    
    enum Tab: Int, Hashable {
        case view = 0
        case scan = 1
        case dobby = 2
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ViewTab(showSignOutConfirmation: $showSignOutConfirmation)
                .tabItem {
                    Label("View", systemImage: "chart.pie.fill")
                }
                .tag(Tab.view)
            
            ScanTab()
                .tabItem {
                    Label("Scan", systemImage: "qrcode.viewfinder")
                }
                .tag(Tab.scan)
            
            ScandaLiciousTab(showSignOutConfirmation: $showSignOutConfirmation)
                .tabItem {
                    Label("Dobby", systemImage: "sparkles")
                }
                .tag(Tab.dobby)
        }
        .environmentObject(transactionManager)
        .preferredColorScheme(.dark)
        .onChange(of: selectedTab) { oldValue, newValue in
            print("🔄 Tab changed: \(oldValue.rawValue) → \(newValue.rawValue)")
        }
        .confirmationDialog("Sign Out", isPresented: $showSignOutConfirmation) {
            Button("Sign Out", role: .destructive) {
                do {
                    try authManager.signOut()
                } catch {
                    print("Error signing out: \(error.localizedDescription)")
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
    

}

// MARK: - View Tab
struct ViewTab: View {
    @Binding var showSignOutConfirmation: Bool
    
    var body: some View {
        NavigationStack {
            OverviewView(showSignOutConfirmation: $showSignOutConfirmation)
                .navigationBarTitleDisplayMode(.inline)
        }
        .id("ViewTab") // Prevent recreation
    }
}

// MARK: - Scan Tab
struct ScanTab: View {
    var body: some View {
        NavigationStack {
            ReceiptScanView()
                .toolbar(.hidden, for: .navigationBar)
        }
        .id("ScanTab") // Prevent recreation
    }
}

// MARK: - ScandaLicious Tab
struct ScandaLiciousTab: View {
    @Binding var showSignOutConfirmation: Bool
    
    var body: some View {
        NavigationStack {
            ScandaLiciousAIChatView(showSignOutConfirmation: $showSignOutConfirmation)
                .toolbarBackground(.hidden, for: .navigationBar)
        }
        .id("ScandaLiciousTab") // Prevent recreation
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationManager())
}


