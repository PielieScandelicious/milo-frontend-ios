//
//  OnboardingView.swift
//  Scandalicious
//
//  Created by Claude on 23/01/2026.
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var selectedGender: ProfileGender = .preferNotToSay
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Welcome Header
                    VStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.purple.gradient)

                        Text("Welcome to Scandalicious!")
                            .font(.title.bold())

                        Text("Let's personalize your experience")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)

                    // Form
                    VStack(spacing: 20) {
                        // First Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("First Name")
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)

                            TextField("Enter your first name", text: $firstName)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.givenName)
                                .autocorrectionDisabled()
                        }

                        // Last Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Last Name")
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)

                            TextField("Enter your last name", text: $lastName)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.familyName)
                                .autocorrectionDisabled()
                        }

                        // Gender
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Gender")
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)

                            Picker("Gender", selection: $selectedGender) {
                                ForEach(ProfileGender.allCases, id: \.self) { gender in
                                    Text(gender.displayName).tag(gender)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    .padding(.horizontal, 24)

                    // Continue Button
                    Button {
                        saveProfile()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Continue")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 50)
                    .background(canContinue ? Color.purple : Color.gray)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(!canContinue || isLoading)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                    // Skip Button
                    Button {
                        skipOnboarding()
                    } label: {
                        Text("Skip for now")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .disabled(isLoading)
                }
                .padding(.bottom, 40)
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled()
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }

    private var canContinue: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func saveProfile() {
        guard canContinue else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let trimmedFirstName = firstName.trimmingCharacters(in: .whitespaces)
                let trimmedLastName = lastName.trimmingCharacters(in: .whitespaces)

                let profile = try await ProfileAPIService().updateProfile(
                    firstName: trimmedFirstName,
                    lastName: trimmedLastName,
                    gender: selectedGender.rawValue
                )

                await MainActor.run {
                    authManager.markProfileAsCompleted()
                    isLoading = false
                }

                print("✅ Profile created successfully: \(profile)")
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
                print("❌ Error creating profile: \(error)")
            }
        }
    }

    private func skipOnboarding() {
        // Mark profile as completed even if skipped
        authManager.markProfileAsCompleted()
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AuthenticationManager())
}
