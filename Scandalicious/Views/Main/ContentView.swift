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
    @StateObject private var dataManager = StoreDataManager()
    @State private var selectedTab: Tab = .view
    @State private var showSignOutConfirmation = false
    @State private var hasLoadedInitialData = false
    
    enum Tab: Int, Hashable {
        case view = 0
        case scan = 1
        case dobby = 2
    }
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                ViewTab(showSignOutConfirmation: $showSignOutConfirmation, dataManager: dataManager)
                    .tabItem {
                        Label("View", systemImage: "chart.pie.fill")
                    }
                    .tag(Tab.view)

                ScanTab()
                    .tabItem {
                        Label("Scan", systemImage: "qrcode.viewfinder")
                    }
                    .tag(Tab.scan)

                ScandaLiciousTab()
                    .tabItem {
                        Label("Dobby", systemImage: "sparkles")
                    }
                    .tag(Tab.dobby)
            }

            // Loading screen overlay
            if !hasLoadedInitialData {
                SyncLoadingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: hasLoadedInitialData)
        .environmentObject(transactionManager)
        .environmentObject(dataManager)
        .preferredColorScheme(.dark)
        .onAppear {
            // Configure data manager on first appear
            if !hasLoadedInitialData {
                dataManager.configure(with: transactionManager)

                // Fetch data in a persistent task
                Task {
                    print("🚀 App launched - fetching initial data")
                    await dataManager.fetchFromBackend(for: .month)
                    await MainActor.run {
                        hasLoadedInitialData = true
                    }
                    print("✅ Initial data loaded successfully")
                }
            }
        }
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
    @ObservedObject var dataManager: StoreDataManager
    
    var body: some View {
        NavigationStack {
            OverviewView(dataManager: dataManager, showSignOutConfirmation: $showSignOutConfirmation)
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
    @ObservedObject private var rateLimitManager = RateLimitManager.shared
    @State private var isTabVisible = false

    var body: some View {
        NavigationStack {
            ScandaLiciousAIChatView()
                .toolbarBackground(.hidden, for: .navigationBar)
        }
        .overlay(alignment: .top) {
            VStack {
                if isTabVisible && rateLimitManager.isReceiptUploading {
                    syncingStatusBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                } else if isTabVisible && rateLimitManager.showReceiptSynced {
                    syncedStatusBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: rateLimitManager.isReceiptUploading)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: rateLimitManager.showReceiptSynced)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isTabVisible)
        }
        .onAppear {
            // Delay slightly to trigger slide-in animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isTabVisible = true
                }
            }
        }
        .onDisappear {
            isTabVisible = false
        }
        .id("ScandaLiciousTab") // Prevent recreation
    }

    private var syncingStatusBanner: some View {
        HStack(spacing: 6) {
            SyncingArrowsView()
            Text("Syncing...")
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(.blue)
        .padding(.top, 12)
    }

    private var syncedStatusBanner: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.icloud.fill")
                .font(.system(size: 11))
            Text("Synced")
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(.green)
        .padding(.top, 12)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationManager())
}


