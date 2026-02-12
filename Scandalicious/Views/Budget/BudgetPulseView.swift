//
//  BudgetPulseView.swift
//  Scandalicious
//
//  Created by Claude on 31/01/2026.
//

import SwiftUI

// MARK: - Budget Mode

private enum BudgetMode {
    case total       // Single monthly amount
    case byCategory  // Per-category limits
}

// MARK: - Inline Target

private struct InlineTarget: Identifiable {
    let id = UUID()
    let category: String
    var amountText: String

    var amount: Double { Double(amountText) ?? 0 }

    init(category: String, amount: Double = 50) {
        self.category = category
        self.amountText = amount > 0 ? String(format: "%.0f", amount) : ""
    }
}

// MARK: - Budget Pulse View

/// The main budget widget - collapsible, showing current budget progress
struct BudgetPulseView: View {
    @ObservedObject var viewModel: BudgetViewModel
    @Binding var isExpanded: Bool

    @State private var showingCategoryDetail = false
    @State private var showDeleteConfirmation = false
    @State private var categoryToRemove: String?

    // Inline setup / editing
    @State private var isSettingUp = false
    @State private var showingModeChooser = false
    @State private var selectedMode: BudgetMode? = nil
    @State private var isMonthlyConfigured = false
    @State private var isCategoriesConfigured = false
    @State private var monthlyAmountText = "500"
    @State private var inlineTargets: [InlineTarget] = []
    @State private var isSmartBudget = true
    @State private var showCategoryPicker = false
    @FocusState private var focusedField: FocusField?

    private enum FocusField: Hashable {
        case monthly
        case category(UUID)
    }

    private var monthlyAmount: Double { Double(monthlyAmountText) ?? 0 }
    private var hasExistingBudget: Bool { viewModel.currentBudget != nil }
    private var canSave: Bool { monthlyAmount > 0 && !viewModel.isSaving }

    // MARK: - Card Styling

    private var premiumCardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(white: 0.08))
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.05),
                            Color.white.opacity(0.02),
                            Color.white.opacity(0.01)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    private var premiumCardBorder: some View {
        RoundedRectangle(cornerRadius: 24)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.15),
                        Color.white.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    // MARK: - Body

    var body: some View {
        contentView
            .background(premiumCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(premiumCardBorder)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isSettingUp)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isExpanded)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showingModeChooser)
            .onReceive(NotificationCenter.default.publisher(for: .budgetDeleted)) { _ in
                isExpanded = false
                showingCategoryDetail = false
                isSettingUp = false
                showingModeChooser = false
                selectedMode = nil
                isMonthlyConfigured = false
                isCategoriesConfigured = false
            }
            .sheet(isPresented: $showCategoryPicker) {
                CategoryPickerSheet(
                    existingCategories: Set(inlineTargets.map { $0.category })
                ) { category in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        inlineTargets.append(InlineTarget(category: category))
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        if let last = inlineTargets.last {
                            focusedField = .category(last.id)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCategoryDetail) {
                if let progress = viewModel.state.progress {
                    CategoryBudgetDetailView(progress: progress) { category in
                        categoryToRemove = category
                    }
                }
            }
            .alert("Remove Budget?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) {
                    Task { @MainActor in
                        let _ = await viewModel.deleteBudget()
                    }
                }
            } message: {
                Text("This will remove your budget tracking. You can set a new budget anytime.")
            }
            .confirmationDialog(
                "Remove \(categoryToRemove?.normalizedCategoryName ?? "") target?",
                isPresented: Binding(
                    get: { categoryToRemove != nil },
                    set: { if !$0 { categoryToRemove = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Remove Target", role: .destructive) {
                    if let category = categoryToRemove {
                        removeCategoryTarget(category)
                        categoryToRemove = nil
                    }
                }
                Button("Cancel", role: .cancel) { categoryToRemove = nil }
            } message: {
                Text("This category will no longer be tracked against a target.")
            }
    }

    // MARK: - Content View

    private var contentView: some View {
        VStack(spacing: 0) {
            if isSettingUp {
                inlineSetupView
            } else {
                switch viewModel.state {
                case .idle, .loading:
                    loadingView
                        .transition(.opacity)

                case .noBudget:
                    noBudgetView
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))

                case .active(let progress):
                    activeBudgetView(progress)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))

                case .error(let message):
                    errorView(message)
                        .transition(.opacity)
                }
            }
        }
    }

    // MARK: - Inline Setup View

    private var inlineSetupView: some View {
        VStack(spacing: 0) {
            if showingModeChooser && !hasExistingBudget {
                modeChooserView
            } else if selectedMode == .byCategory || (hasExistingBudget && viewModel.currentBudget?.categoryAllocations?.isEmpty == false) {
                categoryBudgetSetupView
            } else {
                totalBudgetSetupView
            }
        }
    }

    // MARK: - Mode Chooser

    private var canCreateBudget: Bool {
        (isMonthlyConfigured || isCategoriesConfigured) && !viewModel.isSaving
    }

    private var modeChooserView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Set Budget")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Button(action: cancelSetup) {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 6)

            Text("How do you want to track your groceries?")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

            // Option cards
            VStack(spacing: 10) {
                // Total budget option
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        selectedMode = .total
                        showingModeChooser = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        focusedField = .monthly
                    }
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: isMonthlyConfigured
                                            ? [Color(red: 0.2, green: 0.75, blue: 0.5).opacity(0.25), Color(red: 0.15, green: 0.6, blue: 0.4).opacity(0.15)]
                                            : [Color(red: 0.2, green: 0.75, blue: 0.5).opacity(0.15), Color(red: 0.15, green: 0.6, blue: 0.4).opacity(0.08)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 44, height: 44)

                            Image(systemName: isMonthlyConfigured ? "checkmark.circle.fill" : "dollarsign.circle.fill")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(Color(red: 0.25, green: 0.8, blue: 0.55))
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Total monthly budget")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)

                            if isMonthlyConfigured {
                                Text(String(format: "€%.0f / month", monthlyAmount))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color(red: 0.3, green: 0.8, blue: 0.5))
                            } else {
                                Text("Set one amount for all groceries")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }

                        Spacer()

                        Image(systemName: isMonthlyConfigured ? "pencil" : "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.25))
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(isMonthlyConfigured ? 0.06 : 0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(
                                        isMonthlyConfigured
                                            ? Color(red: 0.25, green: 0.8, blue: 0.55).opacity(0.2)
                                            : Color.white.opacity(0.06),
                                        lineWidth: isMonthlyConfigured ? 1 : 0.5
                                    )
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())

                // By category option
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        selectedMode = .byCategory
                        showingModeChooser = false
                    }
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: isCategoriesConfigured
                                            ? [Color(red: 0.4, green: 0.5, blue: 1.0).opacity(0.25), Color(red: 0.3, green: 0.4, blue: 0.9).opacity(0.15)]
                                            : [Color(red: 0.4, green: 0.5, blue: 1.0).opacity(0.15), Color(red: 0.3, green: 0.4, blue: 0.9).opacity(0.08)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 44, height: 44)

                            Image(systemName: isCategoriesConfigured ? "checkmark.circle.fill" : "square.grid.2x2.fill")
                                .font(.system(size: isCategoriesConfigured ? 22 : 20, weight: .medium))
                                .foregroundColor(Color(red: 0.5, green: 0.6, blue: 1.0))
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Budget by category")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)

                            if isCategoriesConfigured {
                                let count = inlineTargets.filter { $0.amount > 0 }.count
                                Text("\(count) categor\(count == 1 ? "y" : "ies") · \(String(format: "€%.0f", categoryBudgetTotal))")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color(red: 0.5, green: 0.6, blue: 1.0))
                            } else {
                                Text("Set limits per category")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }

                        Spacer()

                        Image(systemName: isCategoriesConfigured ? "pencil" : "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.25))
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(isCategoriesConfigured ? 0.06 : 0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(
                                        isCategoriesConfigured
                                            ? Color(red: 0.5, green: 0.6, blue: 1.0).opacity(0.2)
                                            : Color.white.opacity(0.06),
                                        lineWidth: isCategoriesConfigured ? 1 : 0.5
                                    )
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)

            // Auto-renew (show once at least one is configured)
            if isMonthlyConfigured || isCategoriesConfigured {
                autoRenewRow
                    .padding(.top, 8)
            }

            // Create Budget button
            Button(action: createFinalBudget) {
                Group {
                    if viewModel.isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text("Create Budget")
                            .font(.system(size: 15, weight: .bold))
                    }
                }
                .foregroundColor(canCreateBudget ? .white : .white.opacity(0.3))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            canCreateBudget
                                ? LinearGradient(
                                    colors: [Color(red: 0.15, green: 0.7, blue: 0.4), Color(red: 0.2, green: 0.8, blue: 0.45)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(
                                    colors: [Color.white.opacity(0.06), Color.white.opacity(0.06)],
                                    startPoint: .leading, endPoint: .trailing)
                        )
                )
                .shadow(color: canCreateBudget ? Color(red: 0.15, green: 0.7, blue: 0.4).opacity(0.3) : .clear, radius: 8, y: 3)
            }
            .disabled(!canCreateBudget)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 18)
        }
    }

    // MARK: - Total Budget Setup

    private var totalBudgetSetupView: some View {
        VStack(spacing: 0) {
            // Header
            setupHeader(title: hasExistingBudget ? "Edit Budget" : "Monthly Budget")

            // Monthly amount
            VStack(spacing: 6) {
                Text("MONTHLY BUDGET")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.white.opacity(0.3))

                HStack(spacing: 2) {
                    Text("€")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.3))
                        .offset(y: -3)

                    TextField("0", text: $monthlyAmountText)
                        .keyboardType(.numberPad)
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: true, vertical: false)
                        .focused($focusedField, equals: .monthly)
                        .onChange(of: monthlyAmountText) { _, newValue in
                            let filtered = newValue.filter { $0.isNumber }
                            if filtered != newValue { monthlyAmountText = filtered }
                            if let val = Double(filtered), val > 99999 {
                                monthlyAmountText = "99999"
                            }
                        }
                }

                Text("per month")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.2))
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 16)
            .contentShape(Rectangle())
            .onTapGesture { focusedField = .monthly }

            // Auto-renew only shown when editing (for new budgets it's on the chooser)
            if hasExistingBudget {
                autoRenewRow
            }

            saveSetupButton
        }
    }

    // MARK: - Category Budget Setup

    private var categoryBudgetSetupView: some View {
        VStack(spacing: 0) {
            // Header
            setupHeader(title: hasExistingBudget ? "Edit Budget" : "Category Budgets")

            // Category list
            if inlineTargets.isEmpty {
                // Empty state — prompt to add
                VStack(spacing: 10) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(.white.opacity(0.15))

                    Text("Add categories you want to track")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.35))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                // Category total
                HStack {
                    Text("TOTAL")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.0)
                        .foregroundColor(.white.opacity(0.3))

                    Spacer()

                    Text(String(format: "€%.0f", categoryBudgetTotal))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

                ForEach(Array(inlineTargets.enumerated()), id: \.element.id) { index, _ in
                    setupCategoryRow(index: index)
                }
                .padding(.bottom, 4)
            }

            // Add category
            Button(action: { showCategoryPicker = true }) {
                HStack(spacing: 5) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                    Text("Add category")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(Color(red: 0.45, green: 0.6, blue: 1.0))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red: 0.4, green: 0.55, blue: 1.0).opacity(0.06))
                )
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 4)

            // Auto-renew only shown when editing (for new budgets it's on the chooser)
            if hasExistingBudget {
                autoRenewRow
            }

            saveCategoryButton
        }
    }

    // MARK: - Shared Setup Components

    private func setupHeader(title: String) -> some View {
        HStack {
            if !hasExistingBudget && selectedMode != nil {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        showingModeChooser = true
                        selectedMode = nil
                        focusedField = nil
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            Button(action: cancelSetup) {
                Text("Cancel")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var autoRenewRow: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                isSmartBudget.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isSmartBudget ? Color(red: 0.45, green: 0.6, blue: 1.0) : .white.opacity(0.2))

                Text("Auto-renew")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSmartBudget ? Color(red: 0.45, green: 0.6, blue: 1.0).opacity(0.85) : .white.opacity(0.25))

                Spacer()

                ZStack(alignment: isSmartBudget ? .trailing : .leading) {
                    Capsule()
                        .fill(isSmartBudget
                              ? Color(red: 0.35, green: 0.5, blue: 1.0).opacity(0.5)
                              : Color.white.opacity(0.08))
                        .frame(width: 34, height: 20)

                    Circle()
                        .fill(isSmartBudget
                              ? Color(red: 0.45, green: 0.6, blue: 1.0)
                              : Color.white.opacity(0.25))
                        .frame(width: 16, height: 16)
                        .padding(.horizontal, 2)
                        .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    private var saveSetupButton: some View {
        Group {
            if hasExistingBudget {
                // Editing: save directly to backend
                Button(action: saveInlineBudget) {
                    Group {
                        if viewModel.isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text("Save")
                                .font(.system(size: 15, weight: .bold))
                        }
                    }
                    .foregroundColor(canSave ? .white : .white.opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                canSave
                                    ? LinearGradient(
                                        colors: [Color(red: 0.15, green: 0.7, blue: 0.4), Color(red: 0.2, green: 0.8, blue: 0.45)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing)
                                    : LinearGradient(
                                        colors: [Color.white.opacity(0.06), Color.white.opacity(0.06)],
                                        startPoint: .leading, endPoint: .trailing)
                            )
                    )
                    .shadow(color: canSave ? Color(red: 0.15, green: 0.7, blue: 0.4).opacity(0.3) : .clear, radius: 8, y: 3)
                }
                .disabled(!canSave)
            } else {
                // New budget: confirm and return to chooser
                Button(action: confirmMonthlySetup) {
                    Text("Done")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(canSave ? .white : .white.opacity(0.3))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(
                                    canSave
                                        ? LinearGradient(
                                            colors: [Color(red: 0.15, green: 0.7, blue: 0.4), Color(red: 0.2, green: 0.8, blue: 0.45)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing)
                                        : LinearGradient(
                                            colors: [Color.white.opacity(0.06), Color.white.opacity(0.06)],
                                            startPoint: .leading, endPoint: .trailing)
                                )
                        )
                        .shadow(color: canSave ? Color(red: 0.15, green: 0.7, blue: 0.4).opacity(0.3) : .clear, radius: 8, y: 3)
                }
                .disabled(!canSave)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 18)
    }

    private var categoryBudgetTotal: Double {
        inlineTargets.reduce(0) { $0 + $1.amount }
    }

    private var canSaveCategories: Bool {
        !inlineTargets.isEmpty && categoryBudgetTotal > 0 && !viewModel.isSaving
    }

    private var saveCategoryButton: some View {
        Group {
            if hasExistingBudget {
                // Editing: save directly to backend
                Button(action: saveCategoryBudget) {
                    Group {
                        if viewModel.isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text("Save")
                                .font(.system(size: 15, weight: .bold))
                        }
                    }
                    .foregroundColor(canSaveCategories ? .white : .white.opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                canSaveCategories
                                    ? LinearGradient(
                                        colors: [Color(red: 0.15, green: 0.7, blue: 0.4), Color(red: 0.2, green: 0.8, blue: 0.45)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing)
                                    : LinearGradient(
                                        colors: [Color.white.opacity(0.06), Color.white.opacity(0.06)],
                                        startPoint: .leading, endPoint: .trailing)
                            )
                    )
                    .shadow(color: canSaveCategories ? Color(red: 0.15, green: 0.7, blue: 0.4).opacity(0.3) : .clear, radius: 8, y: 3)
                }
                .disabled(!canSaveCategories)
            } else {
                // New budget: confirm and return to chooser
                Button(action: confirmCategorySetup) {
                    Text("Done")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(canSaveCategories ? .white : .white.opacity(0.3))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(
                                    canSaveCategories
                                        ? LinearGradient(
                                            colors: [Color(red: 0.15, green: 0.7, blue: 0.4), Color(red: 0.2, green: 0.8, blue: 0.45)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing)
                                        : LinearGradient(
                                            colors: [Color.white.opacity(0.06), Color.white.opacity(0.06)],
                                            startPoint: .leading, endPoint: .trailing)
                                )
                        )
                        .shadow(color: canSaveCategories ? Color(red: 0.15, green: 0.7, blue: 0.4).opacity(0.3) : .clear, radius: 8, y: 3)
                }
                .disabled(!canSaveCategories)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 18)
    }

    private func setupCategoryRow(index: Int) -> some View {
        let target = inlineTargets[index]

        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(target.category.categoryColor.opacity(0.15))
                    .frame(width: 32, height: 32)

                Image(systemName: target.category.categoryIcon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(target.category.categoryColor)
            }

            Text(target.category.normalizedCategoryName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()

            HStack(spacing: 2) {
                Text("€")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))

                TextField("0", text: $inlineTargets[index].amountText)
                    .keyboardType(.numberPad)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 44)
                    .multilineTextAlignment(.trailing)
                    .focused($focusedField, equals: .category(target.id))
                    .onChange(of: inlineTargets[index].amountText) { _, newValue in
                        let filtered = newValue.filter { $0.isNumber }
                        if filtered != newValue {
                            inlineTargets[index].amountText = filtered
                        }
                    }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(focusedField == .category(target.id) ? 0.1 : 0.05))
            )

            Button {
                focusedField = nil
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    let _ = inlineTargets.remove(at: index)
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.2))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 5)
    }

    // MARK: - Setup Actions

    private func startInlineSetup() {
        if let budget = viewModel.currentBudget {
            monthlyAmountText = String(format: "%.0f", budget.monthlyAmount)
            inlineTargets = (budget.categoryAllocations ?? []).map {
                InlineTarget(category: $0.category, amount: $0.amount)
            }
            isSmartBudget = budget.isSmartBudget
            // Editing: skip the chooser, go straight to form
            showingModeChooser = false
            let hasCats = !(budget.categoryAllocations ?? []).isEmpty
            selectedMode = hasCats ? .byCategory : .total
        } else {
            monthlyAmountText = "500"
            inlineTargets = []
            isSmartBudget = true
            // New budget: show the mode chooser
            showingModeChooser = true
            selectedMode = nil
        }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            isSettingUp = true
            isExpanded = true
        }
    }

    private func cancelSetup() {
        focusedField = nil
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isSettingUp = false
            showingModeChooser = false
            selectedMode = nil
            isMonthlyConfigured = false
            isCategoriesConfigured = false
            if !viewModel.state.hasBudget {
                isExpanded = false
            }
        }
    }

    /// "Done" in the total-budget sub-form → mark configured, return to chooser
    private func confirmMonthlySetup() {
        focusedField = nil
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isMonthlyConfigured = true
            showingModeChooser = true
            selectedMode = nil
        }
    }

    /// "Done" in the category sub-form → mark configured, return to chooser
    private func confirmCategorySetup() {
        focusedField = nil
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isCategoriesConfigured = true
            showingModeChooser = true
            selectedMode = nil
        }
    }

    /// "Create Budget" on the chooser → actually save to backend
    private func createFinalBudget() {
        focusedField = nil

        Task {
            let amount: Double
            let allocations: [CategoryAllocation]?

            if isCategoriesConfigured {
                let cats = inlineTargets
                    .filter { $0.amount > 0 }
                    .map { CategoryAllocation(category: $0.category, amount: $0.amount) }
                allocations = cats.isEmpty ? nil : cats

                // If monthly is also configured, use that amount; otherwise sum categories
                amount = isMonthlyConfigured ? monthlyAmount : cats.reduce(0.0) { $0 + $1.amount }
            } else {
                // Monthly only
                amount = monthlyAmount
                allocations = nil
            }

            let success = await viewModel.createBudget(
                amount: amount,
                categoryAllocations: allocations,
                isSmartBudget: isSmartBudget
            )

            if success {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    isSettingUp = false
                    showingModeChooser = false
                    selectedMode = nil
                    isMonthlyConfigured = false
                    isCategoriesConfigured = false
                }
            }
        }
    }

    /// Direct save when editing an existing budget (total mode)
    private func saveInlineBudget() {
        focusedField = nil

        Task {
            let success = await viewModel.updateBudgetFull(request: UpdateBudgetRequest(
                monthlyAmount: monthlyAmount,
                categoryAllocations: nil,
                isSmartBudget: isSmartBudget
            ))

            if success {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    isSettingUp = false
                    selectedMode = nil
                }
            }
        }
    }

    /// Direct save when editing an existing budget (category mode)
    private func saveCategoryBudget() {
        focusedField = nil

        Task {
            let allocations = inlineTargets
                .filter { $0.amount > 0 }
                .map { CategoryAllocation(category: $0.category, amount: $0.amount) }

            let total = allocations.reduce(0.0) { $0 + $1.amount }

            let success = await viewModel.updateBudgetFull(request: UpdateBudgetRequest(
                monthlyAmount: total,
                categoryAllocations: allocations,
                isSmartBudget: isSmartBudget
            ))

            if success {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    isSettingUp = false
                    selectedMode = nil
                }
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        HStack(spacing: 14) {
            SkeletonCircle(size: 44)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    SkeletonRect(width: 60, height: 18)
                    SkeletonRect(width: 20, height: 14)
                    SkeletonRect(width: 50, height: 16)
                }
                SkeletonRect(width: 120, height: 12)
            }

            Spacer()

            SkeletonRect(width: 14, height: 14, cornerRadius: 4)
        }
        .padding(16)
        .shimmer()
    }

    // MARK: - No Budget View

    private var noBudgetView: some View {
        Group {
            if viewModel.isCurrentMonth {
                Button(action: { startInlineSetup() }) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 44, height: 44)

                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Set Budget")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)

                            Text("Track your spending and stay on track")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                pastMonthBudgetHistoryView
            }
        }
    }

    // MARK: - Past Month Budget History View

    private var pastMonthBudgetHistoryView: some View {
        Group {
            if let history = pastMonthHistoryForSelectedPeriod {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(history.displayMonth)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)

                            if history.wasSmartBudget {
                                HStack(spacing: 4) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 10, weight: .semibold))
                                    Text("Budget")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))
                            }
                        }

                        Spacer()

                        if history.wasDeleted {
                            HStack(spacing: 4) {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 10, weight: .semibold))
                                Text("Deleted")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(Color(red: 1.0, green: 0.55, blue: 0.3))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(red: 1.0, green: 0.55, blue: 0.3).opacity(0.15))
                            .cornerRadius(6)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Monthly Budget")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))

                        Text(String(format: "€%.0f", history.monthlyAmount))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }

                    if let allocations = history.categoryAllocations, !allocations.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Category Targets")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))

                            VStack(spacing: 4) {
                                ForEach(allocations.prefix(4)) { allocation in
                                    HStack {
                                        Circle()
                                            .fill(allocation.category.categoryColor)
                                            .frame(width: 6, height: 6)

                                        Text(allocation.category.normalizedCategoryName)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white.opacity(0.8))

                                        Spacer()

                                        Text(String(format: "€%.0f", allocation.amount))
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                            .foregroundColor(.white)
                                    }
                                }

                                if allocations.count > 4 {
                                    Text("+ \(allocations.count - 4) more")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                            }
                        }
                    }
                }
                .padding(16)
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.3))

                    Text("No budget was set for this month")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))

                    Spacer()
                }
                .padding(16)
            }
        }
    }

    private var pastMonthHistoryForSelectedPeriod: BudgetHistory? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        guard let date = dateFormatter.date(from: viewModel.selectedPeriod) else {
            return nil
        }

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "yyyy-MM"
        let monthString = monthFormatter.string(from: date)

        return viewModel.budgetHistory.first { $0.month == monthString }
    }

    // MARK: - Active Budget View

    private func activeBudgetView(_ progress: BudgetProgress) -> some View {
        VStack(spacing: 0) {
            collapsedHeader(progress)

            if isExpanded {
                expandedContent(progress)
            }
        }
    }

    private func collapsedHeader(_ progress: BudgetProgress) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        }) {
            HStack(spacing: 14) {
                MiniBudgetRing(
                    spendRatio: progress.spendRatio,
                    paceStatus: progress.paceStatus,
                    size: 44
                )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(String(format: "€%.0f", progress.currentSpend))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("of")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))

                        Text(String(format: "€%.0f", progress.budget.monthlyAmount))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }

                    HStack(spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: progress.paceStatus.icon)
                                .font(.system(size: 11, weight: .semibold))

                            Text(progress.paceStatus.displayText)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(progress.paceStatus.color)

                        Text("•")
                            .foregroundColor(.white.opacity(0.3))

                        Text("\(progress.daysRemaining) days left")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }

                Spacer()

                if isExpanded {
                    Button(action: { startInlineSetup() }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { showDeleteConfirmation = true }) {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.trailing, 4)
                }

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func expandedContent(_ progress: BudgetProgress) -> some View {
        VStack(spacing: 16) {
            // Large ring
            BudgetRingView(progress: progress, size: 160)
                .padding(.vertical, 8)

            // Stats row — no dividers
            HStack(spacing: 0) {
                statItem(
                    title: "Remaining",
                    value: String(format: "€%.0f", progress.remainingBudget),
                    color: progress.remainingBudget > 0 ? .green : .red
                )

                statItem(
                    title: "Daily Budget",
                    value: String(format: "€%.0f", progress.dailyBudgetRemaining),
                    color: .white
                )

                statItem(
                    title: "Projected",
                    value: String(format: "€%.0f", progress.projectedEndOfMonth),
                    color: progress.projectedOverUnder > 0 ? .orange : .green
                )
            }
            .padding(.horizontal, 8)

            // Progress bar
            VStack(spacing: 6) {
                BudgetProgressBar(progress: progress, height: 10)

                HStack {
                    Text("Day \(progress.daysElapsed)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))

                    Spacer()

                    Text("Day \(progress.daysInMonth)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding(.horizontal, 16)

            // Category breakdown — seamless, no dividers
            if !progress.categoryProgress.isEmpty {
                VStack(spacing: 4) {
                    HStack {
                        Text("Categories")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))

                        Spacer()

                        Button(action: { showingCategoryDetail = true }) {
                            HStack(spacing: 4) {
                                Text(progress.categoryProgress.count > 5
                                     ? "See All (\(progress.categoryProgress.count))"
                                     : "Details")
                                    .font(.system(size: 12, weight: .semibold))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(.white.opacity(0.35))
                        }
                    }
                    .padding(.horizontal, 16)

                    let sorted = progress.categoryProgress
                        .sorted { $0.currentSpend > $1.currentSpend }
                        .prefix(5)

                    ForEach(Array(sorted), id: \.id) { cat in
                        compactCategoryRow(cat)
                    }
                }
            }
        }
        .padding(.bottom, 16)
    }

    // MARK: - Compact Category Row (progress display)

    private func compactCategoryRow(_ cat: CategoryBudgetProgress) -> some View {
        let statusColor: Color = {
            if cat.isOverBudget { return Color(red: 1.0, green: 0.4, blue: 0.4) }
            else if cat.spendRatio > 0.85 { return Color(red: 1.0, green: 0.75, blue: 0.3) }
            else { return Color(red: 0.3, green: 0.8, blue: 0.5) }
        }()

        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(cat.category.categoryColor.opacity(0.15))
                    .frame(width: 34, height: 34)

                Image(systemName: cat.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(cat.category.categoryColor)
            }

            Text(cat.category.normalizedCategoryName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                HStack(spacing: 3) {
                    Text(String(format: "€%.0f", cat.currentSpend))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(cat.isOverBudget ? statusColor : .white)

                    Text("/")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.25))

                    Text(String(format: "€%.0f", cat.budgetAmount))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.45))
                }

                Text(cat.isOverBudget
                     ? String(format: "€%.0f over", cat.overAmount)
                     : String(format: "€%.0f left", cat.remainingAmount))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(cat.isOverBudget ? statusColor : .white.opacity(0.35))
            }

            // Quick remove
            Button {
                categoryToRemove = cat.category
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.12))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private func statItem(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color)

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Remove Category Target

    private func removeCategoryTarget(_ category: String) {
        guard let budget = viewModel.currentBudget,
              let allocations = budget.categoryAllocations else { return }

        let updated = allocations.filter { $0.category != category }
        Task {
            let _ = await viewModel.updateCategoryAllocations(updated)
        }
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Couldn't load budget")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer()

            Button(action: { Task { await viewModel.loadBudget() } }) {
                Text("Retry")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))
            }
        }
        .padding(16)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(white: 0.05).ignoresSafeArea()

        VStack(spacing: 20) {
            BudgetPulseView(viewModel: {
                let vm = BudgetViewModel()
                let budget = UserBudget(
                    id: "1",
                    userId: "user1",
                    monthlyAmount: 850,
                    categoryAllocations: nil
                )
                let progress = BudgetProgress(
                    budget: budget,
                    currentSpend: 623,
                    daysElapsed: 21,
                    daysInMonth: 31,
                    categoryProgress: [
                        CategoryBudgetProgress(category: "Fresh Produce", budgetAmount: 100, currentSpend: 85),
                        CategoryBudgetProgress(category: "Meat & Fish", budgetAmount: 150, currentSpend: 140),
                        CategoryBudgetProgress(category: "Snacks & Sweets", budgetAmount: 60, currentSpend: 72),
                    ]
                )
                vm.state = .active(progress)
                return vm
            }(), isExpanded: .constant(false))
            .padding(.horizontal)

            BudgetPulseView(viewModel: {
                let vm = BudgetViewModel()
                vm.state = .noBudget
                return vm
            }(), isExpanded: .constant(false))
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top, 20)
    }
}
