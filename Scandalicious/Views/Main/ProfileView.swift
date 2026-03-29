//
//  ProfileView.swift
//  dobby-ios
//
//  Created by Gilles Moenaert on 20/01/2026.
//

import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthenticationManager

    @State private var nickname = ""
    @State private var instagramHandle = ""
    @State private var selectedGender: Gender = .notSpecified
    @State private var age = ""
    @State private var householdNumber = ""
    @State private var selectedLanguage: ProfileLanguage?
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var showSaveSuccess = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var hasUnsavedChanges = false

    // Store original values to detect changes
    @State private var originalNickname = ""
    @State private var originalInstagramHandle = ""
    @State private var originalGender: Gender = .notSpecified
    @State private var originalAge = ""
    @State private var originalHouseholdNumber = ""
    @State private var originalLanguage: ProfileLanguage?

    enum Gender: String, CaseIterable {
        case male = "Male"
        case female = "Female"
        case notSpecified = "X"

        var displayName: String {
            switch self {
            case .male: return L("gender_male")
            case .female: return L("gender_female")
            case .notSpecified: return L("gender_x")
            }
        }

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
                    Text(L("nickname"))
                        .foregroundStyle(.primary)
                    Spacer()
                    TextField(L("nickname"), text: $nickname)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                        .disabled(isLoading || isSaving)
                        .onChange(of: nickname) { _, _ in
                            checkForChanges()
                        }
                }

                Picker("Gender", selection: $selectedGender) {
                    ForEach(Gender.allCases, id: \.self) { gender in
                        Text(gender.displayName).tag(gender)
                    }
                }
                .disabled(isLoading || isSaving)
                .onChange(of: selectedGender) { _, _ in
                    checkForChanges()
                }

                HStack {
                    Text(L("age"))
                        .foregroundStyle(.primary)
                    Spacer()
                    TextField(L("age"), text: $age)
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

                HStack {
                    Text(L("household_number"))
                        .foregroundStyle(.primary)
                    Spacer()
                    TextField(L("household_number"), text: $householdNumber)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                        .keyboardType(.numberPad)
                        .disabled(isLoading || isSaving)
                        .onChange(of: householdNumber) { _, newValue in
                            let filtered = newValue.filter { $0.isNumber }
                            if filtered.count > 2 { householdNumber = String(filtered.prefix(2)) }
                            else if filtered != newValue { householdNumber = filtered }
                            checkForChanges()
                        }
                }

                Picker(L("language"), selection: $selectedLanguage) {
                    Text(L("not_set")).tag(ProfileLanguage?.none)
                    ForEach(ProfileLanguage.allCases, id: \.self) { language in
                        Text("\(language.flag) \(language.displayName)").tag(ProfileLanguage?.some(language))
                    }
                }
                .disabled(isLoading || isSaving)
                .onChange(of: selectedLanguage) { _, _ in
                    checkForChanges()
                }

                HStack {
                    Image(systemName: "camera.fill")
                        .foregroundStyle(.primary)
                        .frame(width: 20)
                    Text("@")
                        .foregroundStyle(.secondary)
                    TextField("Instagram handle", text: $instagramHandle)
                        .foregroundStyle(.secondary)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .disabled(isLoading || isSaving)
                        .onChange(of: instagramHandle) { _, _ in
                            checkForChanges()
                        }
                }
            } header: {
                Text(L("personal_information"))
            }

            // Save Button (if changes)
            if hasUnsavedChanges {
                Section {
                    Button {
                        saveProfile()
                    } label: {
                        if isSaving {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                Text(L("saving"))
                                Spacer()
                            }
                        } else {
                            HStack {
                                Spacer()
                                Text(L("save_changes"))
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .disabled(isSaving)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            }

            // Account
            Section {
                HStack {
                    Text(L("email"))
                    Spacer()
                    Text(authManager.user?.email ?? L("not_available"))
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(L("account"))
            }

            // Insights
            Section {
                NavigationLink {
                    YearInReviewView()
                } label: {
                    Label(L("year_in_review"), systemImage: "calendar.badge.clock")
                }
            } header: {
                Text(L("insights"))
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
                        Label(L("sign_out"), systemImage: "rectangle.portrait.and.arrow.right")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle(L("profile"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(L("done")) {
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
        .alert(L("success"), isPresented: $showSaveSuccess) {
            Button(L("ok"), role: .cancel) {}
        } message: {
            Text(L("profile_updated"))
        }
        .alert(L("error"), isPresented: $showError) {
            Button(L("ok"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? L("unknown_error"))
        }
        .onAppear {
            Task {
                await loadProfile()
            }
        }
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
                instagramHandle = profile.instagramHandle ?? ""
                selectedGender = Gender.from(apiValue: profile.gender)
                age = profile.age != nil ? "\(profile.age!)" : ""
                householdNumber = profile.householdNumber != nil ? "\(profile.householdNumber!)" : ""
                selectedLanguage = ProfileLanguage.from(apiValue: profile.language)
                LanguageManager.shared.syncFromProfile(profile.language)

                // Store original values
                originalNickname = nickname
                originalInstagramHandle = instagramHandle
                originalGender = selectedGender
                originalAge = age
                originalHouseholdNumber = householdNumber
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
                let trimmedInstagramHandle = instagramHandle.trimmingCharacters(in: .whitespaces)
                let ageValue = Int(age)
                let householdValue = Int(householdNumber)
                let profile = try await ProfileAPIService().updateProfile(
                    nickname: trimmedNickname.isEmpty ? nil : trimmedNickname,
                    gender: selectedGender.apiValue,
                    age: ageValue,
                    householdNumber: householdValue,
                    language: selectedLanguage?.rawValue,
                    instagramHandle: trimmedInstagramHandle.isEmpty ? nil : trimmedInstagramHandle
                )

                await MainActor.run {
                    // Update original values
                    originalNickname = nickname
                    originalInstagramHandle = instagramHandle
                    originalGender = selectedGender
                    originalAge = age
                    originalHouseholdNumber = householdNumber
                    originalLanguage = selectedLanguage

                    if let lang = selectedLanguage {
                        LanguageManager.shared.currentLanguage = lang
                    }
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
                           instagramHandle != originalInstagramHandle ||
                           selectedGender != originalGender ||
                           age != originalAge ||
                           householdNumber != originalHouseholdNumber ||
                           selectedLanguage != originalLanguage
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(AuthenticationManager())
    }
}
