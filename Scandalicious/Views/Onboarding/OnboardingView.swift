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
                        Text("Welcome to Milo")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(.purple.gradient)

                        Text("Let's personalize your experience")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)

                    // Form
                    VStack(spacing: 24) {
                        // First Name
                        VStack(alignment: .leading, spacing: 10) {
                            Text("First Name")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)

                            TextField("Enter your first name", text: $firstName)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(14)
                                .textContentType(.givenName)
                                .autocorrectionDisabled()
                        }

                        // Last Name
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Last Name")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)

                            TextField("Enter your last name", text: $lastName)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(14)
                                .textContentType(.familyName)
                                .autocorrectionDisabled()
                        }

                        // Gender
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Gender")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)

                            Picker("Gender", selection: $selectedGender) {
                                ForEach(ProfileGender.allCases, id: \.self) { gender in
                                    Text(gender.displayName).tag(gender)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.vertical, 4)
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
                    .frame(height: 56)
                    .background(
                        canContinue ?
                        LinearGradient(
                            colors: [Color.purple, Color.purple.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ) :
                        LinearGradient(
                            colors: [Color.gray, Color.gray],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: canContinue ? Color.purple.opacity(0.3) : Color.clear, radius: 10, x: 0, y: 5)
                    .disabled(!canContinue || isLoading)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                }
                .padding(.bottom, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled()
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
        .preferredColorScheme(.dark)
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
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AuthenticationManager())
}
