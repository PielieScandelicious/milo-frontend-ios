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

    @State private var nickname = ""
    @State private var selectedGender: Gender = .notSpecified
    @State private var age = ""
    @State private var selectedLanguage: ProfileLanguage?
    @State private var showManageSubscription = false
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var showSaveSuccess = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var hasUnsavedChanges = false

    // Store original values to detect changes
    @State private var originalNickname = ""
    @State private var originalGender: Gender = .notSpecified
    @State private var originalAge = ""
    @State private var originalLanguage: ProfileLanguage?

    enum Gender: String, CaseIterable {
        case male = "Male"
        case female = "Female"
        case notSpecified = "X"

        var apiValue: String {
            switch self {
            case .male: return "male"
            case .female: return "female"
            case .notSpecified: return "prefer_not_to_say"
            }
        }

        static func from(apiValue: String?) -> Gender {
            guard let apiValue = apiValue else { return .notSpecified }
            switch apiValue {
            case "male": return .male
            case "female": return .female
            default: return .notSpecified
            }
        }
    }

    var body: some View {
        List {
            // Personal Information
            Section {
                HStack {
                    Text("Nickname")
                        .foregroundStyle(.primary)
                    Spacer()
                    TextField("Nickname", text: $nickname)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                        .disabled(isLoading || isSaving)
                        .onChange(of: nickname) { _, _ in
                            checkForChanges()
                        }
                }

                Picker("Gender", selection: $selectedGender) {
                    ForEach(Gender.allCases, id: \.self) { gender in
                        Text(gender.rawValue).tag(gender)
                    }
                }
                .disabled(isLoading || isSaving)
                .onChange(of: selectedGender) { _, _ in
                    checkForChanges()
                }

                HStack {
                    Text("Age")
                        .foregroundStyle(.primary)
                    Spacer()
                    TextField("Age", text: $age)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                        .keyboardType(.numberPad)
                        .disabled(isLoading || isSaving)
                        .onChange(of: age) { _, newValue in
                            let filtered = newValue.filter { $0.isNumber }
                            if filtered.count > 3 { age = String(filtered.prefix(3)) }
                            else if filtered != newValue { age = filtered }
                            checkForChanges()
                        }
                }

                Picker("Language", selection: $selectedLanguage) {
                    Text("Not set").tag(ProfileLanguage?.none)
                    ForEach(ProfileLanguage.allCases, id: \.self) { language in
                        Text("\(language.flag) \(language.displayName)").tag(ProfileLanguage?.some(language))
                    }
                }
                .disabled(isLoading || isSaving)
                .onChange(of: selectedLanguage) { _, _ in
                    checkForChanges()
                }
            } header: {
                Text("Personal Information")
            } footer: {
                if hasUnsavedChanges {
                    Button {
                        saveProfile()
                    } label: {
                        if isSaving {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                Text("Saving...")
                            }
                        } else {
                            Text("Save Changes")
                                .fontWeight(.semibold)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .disabled(isSaving)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                }
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

            // Insights
            Section {
                NavigationLink {
                    YearInReviewView()
                } label: {
                    Label("Year in Review", systemImage: "calendar.badge.clock")
                }
            } header: {
                Text("Insights")
            }

            // Sign Out
            Section {
                Button(role: .destructive) {
                    do {
                        try authManager.signOut()
                        dismiss()
                    } catch {
                        // Error signing out - silently ignore
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
        .overlay {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
        }
        .alert("Success", isPresented: $showSaveSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your profile has been updated successfully")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .manageSubscriptionsSheet(isPresented: $showManageSubscription)
        .onAppear {
            Task {
                // Load products first, then check status
                await subscriptionManager.loadProducts()
                await subscriptionManager.updateSubscriptionStatus()

                // Load profile data
                await loadProfile()
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

    // MARK: - Profile Data Management

    private func loadProfile() async {
        await MainActor.run {
            isLoading = true
        }

        do {
            let profile = try await ProfileAPIService().getProfile()
            await MainActor.run {
                nickname = profile.nickname ?? ""
                selectedGender = Gender.from(apiValue: profile.gender)
                age = profile.age != nil ? "\(profile.age!)" : ""
                selectedLanguage = ProfileLanguage.from(apiValue: profile.language)

                // Store original values
                originalNickname = nickname
                originalGender = selectedGender
                originalAge = age
                originalLanguage = selectedLanguage

                hasUnsavedChanges = false
                isLoading = false
            }
        } catch {
            // If profile not found, that's okay - user hasn't filled it out yet
            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func saveProfile() {
        guard hasUnsavedChanges else { return }

        isSaving = true
        errorMessage = nil

        Task {
            do {
                let trimmedNickname = nickname.trimmingCharacters(in: .whitespaces)
                let ageValue = Int(age)

                let profile = try await ProfileAPIService().updateProfile(
                    nickname: trimmedNickname.isEmpty ? nil : trimmedNickname,
                    gender: selectedGender.apiValue,
                    age: ageValue,
                    language: selectedLanguage?.rawValue
                )

                await MainActor.run {
                    // Update original values
                    originalNickname = nickname
                    originalGender = selectedGender
                    originalAge = age
                    originalLanguage = selectedLanguage

                    hasUnsavedChanges = false
                    isSaving = false
                    showSaveSuccess = true

                    // Update profile completion status
                    if profile.profileCompleted {
                        authManager.markProfileAsCompleted()
                    }
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func checkForChanges() {
        hasUnsavedChanges = nickname != originalNickname ||
                           selectedGender != originalGender ||
                           age != originalAge ||
                           selectedLanguage != originalLanguage
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(AuthenticationManager())
            .environmentObject(SubscriptionManager.shared)
    }
}
