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
        case scandaLicious = 2
        case profile = 3
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ViewTab()
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
                    Label("ScandaLicious", systemImage: "sparkles")
                }
                .tag(Tab.scandaLicious)
            
            ProfileTab(showSignOutConfirmation: $showSignOutConfirmation)
                .tabItem {
                    Label("Profile", systemImage: "person.circle.fill")
                }
                .tag(Tab.profile)
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
    var body: some View {
        NavigationStack {
            OverviewView()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .navigationBar)
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
    var body: some View {
        NavigationStack {
            ScandaLiciousAIChatView()
                .toolbarBackground(.hidden, for: .navigationBar)
        }
        .id("ScandaLiciousTab") // Prevent recreation
    }
}

// MARK: - Profile Tab
struct ProfileTab: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @Binding var showSignOutConfirmation: Bool
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let user = authManager.user {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(user.email ?? "No email")
                                .font(.headline)
                            
                            Text("User ID: \(user.uid)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section {
                    NavigationLink {
                        AuthDebugView()
                    } label: {
                        Label("Auth Debug", systemImage: "ant.fill")
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        showSignOutConfirmation = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationManager())
}


