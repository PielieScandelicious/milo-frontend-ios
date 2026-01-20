//
//  ContentView.swift
//  dobby-ios
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @StateObject private var transactionManager = TransactionManager()
    @State private var selectedTab = 0
    @State private var showSignOutConfirmation = false
    
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
            
            ProfileTab(showSignOutConfirmation: $showSignOutConfirmation)
                .tabItem {
                    Label("Profile", systemImage: "person.circle.fill")
                }
                .tag(3)
        }
        .environmentObject(transactionManager)
        .preferredColorScheme(.dark)
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
