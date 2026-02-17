//
//  OnboardingView.swift
//  Scandalicious
//
//  Created by Claude on 23/01/2026.
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var nickname = ""
    @State private var selectedGender: ProfileGender = .male
    @State private var age = ""
    @State private var selectedLanguage: ProfileLanguage = .english
<<<<<<< HEAD
=======
    @State private var selectedStores: Set<GroceryStore> = []
>>>>>>> f4b7918 (Add grocery store preferences, real store logos, and wallet pass logo picker)
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var appearAnimation = false

    private var onboardingGenders: [ProfileGender] {
        [.male, .female]
    }
<<<<<<< HEAD
=======

    // Grid layout: 3 columns
    private let storeColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
>>>>>>> f4b7918 (Add grocery store preferences, real store logos, and wallet pass logo picker)

    var body: some View {
        ZStack {
            // Premium gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.05, blue: 0.3),
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Hero
                    heroSection
                        .padding(.top, 50)
                        .padding(.bottom, 32)

                    // Compact form card
                    formCard
                        .padding(.horizontal, 24)
<<<<<<< HEAD
                        .padding(.bottom, 24)

=======
                        .padding(.bottom, 20)

                    // Store selection
                    storeSelectionCard
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)

>>>>>>> f4b7918 (Add grocery store preferences, real store logos, and wallet pass logo picker)
                    // Continue button
                    continueButton
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                }
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
        .alert(L("error"), isPresented: $showError) {
            Button(L("ok"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? L("unknown_error"))
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                appearAnimation = true
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.purple.opacity(0.4), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)

                MiloDachshundView(size: 72)
            }
            .opacity(appearAnimation ? 1 : 0)
            .scaleEffect(appearAnimation ? 1 : 0.5)

            Text(L("welcome"))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .opacity(appearAnimation ? 1 : 0)
                .offset(y: appearAnimation ? 0 : 20)

            Text(L("personalize_experience"))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .opacity(appearAnimation ? 1 : 0)
                .offset(y: appearAnimation ? 0 : 10)
        }
    }

    // MARK: - Form Card

    private var formCard: some View {
        VStack(spacing: 16) {
            // Nickname
            HStack(spacing: 12) {
                Image(systemName: "person.fill")
                    .font(.subheadline)
                    .foregroundStyle(.purple)
                    .frame(width: 20)

                TextField(L("nickname"), text: $nickname)
                    .foregroundStyle(.white)
                    .autocorrectionDisabled()
                    .textContentType(.nickname)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                    )
            )

            // Age
            HStack(spacing: 12) {
                Image(systemName: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.purple)
                    .frame(width: 20)

                TextField(L("age"), text: $age)
                    .foregroundStyle(.white)
                    .keyboardType(.numberPad)
                    .onChange(of: age) { _, newValue in
                        let filtered = newValue.filter { $0.isNumber }
                        if filtered.count > 3 { age = String(filtered.prefix(3)) }
                        else if filtered != newValue { age = filtered }
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                    )
            )

            // Gender
            HStack(spacing: 8) {
                ForEach(onboardingGenders, id: \.self) { gender in
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            selectedGender = gender
                        }
                    } label: {
                        Text(gender.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedGender == gender ? .white : .white.opacity(0.4))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedGender == gender
                                          ? LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                                          : LinearGradient(colors: [.white.opacity(0.07), .white.opacity(0.07)], startPoint: .leading, endPoint: .trailing)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Language
            HStack(spacing: 8) {
                ForEach(ProfileLanguage.allCases, id: \.self) { language in
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            selectedLanguage = language
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(language.flag)
                                .font(.callout)
                            Text(language.displayName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(selectedLanguage == language ? .white : .white.opacity(0.4))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedLanguage == language
                                      ? LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                                      : LinearGradient(colors: [.white.opacity(0.07), .white.opacity(0.07)], startPoint: .leading, endPoint: .trailing)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

<<<<<<< HEAD
=======
    // MARK: - Store Selection Card

    private var storeSelectionCard: some View {
        VStack(spacing: 14) {
            // Header
            HStack {
                Image(systemName: "storefront.fill")
                    .font(.subheadline)
                    .foregroundStyle(.purple)
                Text(L("select_stores"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        if selectedStores.count == GroceryStore.allCases.count {
                            selectedStores.removeAll()
                        } else {
                            selectedStores = Set(GroceryStore.allCases)
                        }
                    }
                } label: {
                    Text(selectedStores.count == GroceryStore.allCases.count ? L("deselect_all") : L("select_all"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.purple)
                }
                .buttonStyle(.plain)
            }

            Text(L("select_stores_subtitle"))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .leading)

            // Store grid
            LazyVGrid(columns: storeColumns, spacing: 10) {
                let stores = GroceryStore.allCases
                let remainder = stores.count % 3
                let gridStores = remainder == 1 ? Array(stores.dropLast()) : stores

                ForEach(gridStores) { store in
                    StoreChipView(
                        store: store,
                        isSelected: selectedStores.contains(store),
                        onTap: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                if selectedStores.contains(store) {
                                    selectedStores.remove(store)
                                } else {
                                    selectedStores.insert(store)
                                }
                            }
                        }
                    )
                }

                // Center last item if the last row has only 1 item
                if remainder == 1, let lastStore = stores.last {
                    Color.clear.frame(height: 1)
                    StoreChipView(
                        store: lastStore,
                        isSelected: selectedStores.contains(lastStore),
                        onTap: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                if selectedStores.contains(lastStore) {
                                    selectedStores.remove(lastStore)
                                } else {
                                    selectedStores.insert(lastStore)
                                }
                            }
                        }
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

>>>>>>> f4b7918 (Add grocery store preferences, real store logos, and wallet pass logo picker)
    // MARK: - Continue Button

    private var continueButton: some View {
        Button {
            saveProfile()
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(L("get_started"))
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.right")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                canContinue
                ? LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                : LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: canContinue ? .purple.opacity(0.4) : .clear, radius: 12, x: 0, y: 6)
        }
        .disabled(!canContinue || isLoading)
        .opacity(canContinue ? 1 : 0.6)
    }

    // MARK: - Logic

    private var canContinue: Bool {
        !nickname.trimmingCharacters(in: .whitespaces).isEmpty &&
        !age.isEmpty &&
        (Int(age) ?? 0) > 0
    }

    private func saveProfile() {
        guard canContinue else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let trimmedNickname = nickname.trimmingCharacters(in: .whitespaces)
                let ageValue = Int(age)
<<<<<<< HEAD
=======
                let storeValues = selectedStores.isEmpty ? nil : selectedStores.map(\.rawValue)
>>>>>>> f4b7918 (Add grocery store preferences, real store logos, and wallet pass logo picker)

                let profile = try await ProfileAPIService().updateProfile(
                    nickname: trimmedNickname,
                    gender: selectedGender.rawValue,
                    age: ageValue,
<<<<<<< HEAD
                    language: selectedLanguage.rawValue
=======
                    language: selectedLanguage.rawValue,
                    preferredStores: storeValues
>>>>>>> f4b7918 (Add grocery store preferences, real store logos, and wallet pass logo picker)
                )

                await MainActor.run {
                    LanguageManager.shared.currentLanguage = selectedLanguage
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

// MARK: - Store Chip View

struct StoreChipView: View {
    let store: GroceryStore
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(store.logoImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 60, maxHeight: 30)
                    .frame(height: 30)
                Text(store.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.45))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected
                          ? store.accentColor.opacity(0.25)
                          : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                isSelected ? store.accentColor.opacity(0.6) : Color.white.opacity(0.08),
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AuthenticationManager())
}
