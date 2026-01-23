//
//  ProfileView.swift
//  dobby-ios
//
//  Created by Gilles Moenaert on 20/01/2026.
//

import SwiftUI
import StoreKit
import FirebaseAuth

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var selectedGender: Gender = .notSpecified
    @State private var showManageSubscription = false

    enum Gender: String, CaseIterable {
        case male = "Male"
        case female = "Female"
        case notSpecified = "Prefer not to say"
    }

    var body: some View {
        List {
            // Personal Information
            Section {
                HStack {
                    Text("First Name")
                        .foregroundStyle(.primary)
                    Spacer()
                    TextField("First Name", text: $firstName)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Last Name")
                        .foregroundStyle(.primary)
                    Spacer()
                    TextField("Last Name", text: $lastName)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                }

                Picker("Gender", selection: $selectedGender) {
                    ForEach(Gender.allCases, id: \.self) { gender in
                        Text(gender.rawValue).tag(gender)
                    }
                }
            } header: {
                Text("Personal Information")
            }

            // Account
            Section {
                HStack {
                    Text("Email")
                    Spacer()
                    Text(authManager.user?.email ?? "Not available")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Account")
            }

            // Subscription
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Current Plan")
                            .foregroundStyle(.primary)
                        Spacer()
                        subscriptionStatusBadge
                    }

                    if case .subscribed(let expirationDate, _) = subscriptionManager.subscriptionStatus {
                        HStack {
                            Text("Renews On")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(formatDate(expirationDate))
                                .foregroundStyle(.secondary)
                        }
                    } else if case .inTrial(let expirationDate, _) = subscriptionManager.subscriptionStatus {
                        HStack {
                            Text("Trial Ends")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(formatDate(expirationDate))
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Spacer()
                        Button {
                            showManageSubscription = true
                        } label: {
                            Text("Manage Subscription")
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.bordered)
                        .tint(Color(red: 0.0, green: 0.48, blue: 1.0))
                        Spacer()
                    }
                }
            } header: {
                Text("Subscription")
            }

            // Sign Out
            Section {
                Button(role: .destructive) {
                    do {
                        try authManager.signOut()
                        dismiss()
                    } catch {
                        print("Error signing out: \(error.localizedDescription)")
                    }
                } label: {
                    HStack {
                        Spacer()
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .manageSubscriptionsSheet(isPresented: $showManageSubscription)
        .onAppear {
            Task {
                // Load products first, then check status
                await subscriptionManager.loadProducts()
                await subscriptionManager.updateSubscriptionStatus()
            }
        }
        .onChange(of: showManageSubscription) { oldValue, newValue in
            // Refresh subscription status when returning from manage subscription sheet
            if oldValue == true && newValue == false {
                Task {
                    // Sync with Apple servers to get latest subscription changes
                    try? await AppStore.sync()

                    // In StoreKit testing, add a small delay to allow changes to propagate
                    try? await Task.sleep(for: .milliseconds(500))

                    // Reload products to ensure we have latest info
                    await subscriptionManager.loadProducts()

                    // Update subscription status
                    await subscriptionManager.updateSubscriptionStatus()

                    // Force another refresh after a delay (for StoreKit testing)
                    try? await Task.sleep(for: .seconds(1))
                    await subscriptionManager.updateSubscriptionStatus()
                }
            }
        }
    }

    private var subscriptionStatusBadge: some View {
        Group {
            switch subscriptionManager.subscriptionStatus {
            case .subscribed(_, let productId):
                let planName = productId.contains("yearly") ? "Premium Yearly" : "Premium Monthly"
                Text(planName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.45, green: 0.15, blue: 0.85))
                    .clipShape(Capsule())
            case .inTrial(_, let productId):
                let planName = productId.contains("yearly") ? "Premium Yearly (Trial)" : "Premium Monthly (Trial)"
                Text(planName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.55, green: 0.25, blue: 0.95))
                    .clipShape(Capsule())
            case .expired:
                Text("Expired")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange)
                    .clipShape(Capsule())
            case .notSubscribed:
                Text("Free")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gray)
                    .clipShape(Capsule())
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(AuthenticationManager())
            .environmentObject(SubscriptionManager.shared)
    }
}
