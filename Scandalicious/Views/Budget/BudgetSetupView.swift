//
//  BudgetSetupView.swift
//  Scandalicious
//

import SwiftUI

// MARK: - Editable Target (local)

private struct EditableTarget: Identifiable {
    let id = UUID()
    let category: String
    var amountText: String

    var amount: Double { Double(amountText) ?? 0 }

    init(category: String, amount: Double = 50) {
        self.category = category
        self.amountText = amount > 0 ? String(format: "%.0f", amount) : ""
    }
}

// MARK: - Budget Setup View

struct BudgetSetupView: View {
    @ObservedObject var viewModel: BudgetViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: FocusField?

    @State private var monthlyAmountText = "500"
    @State private var categoryTargets: [EditableTarget] = []
    @State private var isSmartBudget = true
    @State private var showCategoryPicker = false
    @State private var showSuccessSheet = false

    private enum FocusField: Hashable {
        case monthly
        case category(UUID)
    }

    private var monthlyAmount: Double {
        Double(monthlyAmountText) ?? 0
    }

    private var isEditing: Bool {
        viewModel.currentBudget != nil
    }

    private var canSave: Bool {
        monthlyAmount > 0 && !viewModel.isSaving
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(white: 0.06).ignoresSafeArea()
                    .onTapGesture { focusedField = nil }

                ScrollView {
                    VStack(spacing: 20) {
                        monthlySection
                        categorySection
                        autoRenewToggle
                        saveButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(isEditing ? "Edit Budget" : "Set Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white.opacity(0.6))
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                        .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { loadExistingBudget() }
        .sheet(isPresented: $showCategoryPicker) {
            CategoryPickerSheet(
                existingCategories: Set(categoryTargets.map { $0.category })
            ) { category in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    categoryTargets.append(EditableTarget(category: category))
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    if let last = categoryTargets.last {
                        focusedField = .category(last.id)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showSuccessSheet) {
            BudgetCreatedSheet(
                budgetAmount: monthlyAmount,
                monthlySavings: 0,
                categoryAllocations: categoryTargets
                    .filter { $0.amount > 0 }
                    .map { CategoryAllocation(category: $0.category, amount: $0.amount) },
                onDismiss: {
                    showSuccessSheet = false
                    dismiss()
                }
            )
        }
    }

    // MARK: - Monthly Section

    private var monthlySection: some View {
        VStack(spacing: 16) {
            Text("Monthly grocery budget")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.5))

            HStack(spacing: 4) {
                Text("€")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))

                TextField("0", text: $monthlyAmountText)
                    .keyboardType(.numberPad)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
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
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .background(cardBackground)
        .overlay(cardBorder)
        .contentShape(Rectangle())
        .onTapGesture { focusedField = .monthly }
    }

    // MARK: - Category Section

    private var categorySection: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Category targets")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Text("Optional")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.06)))
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, categoryTargets.isEmpty ? 4 : 12)

            // Category rows
            if !categoryTargets.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(categoryTargets.enumerated()), id: \.element.id) { index, _ in
                        VStack(spacing: 0) {
                            if index > 0 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.06))
                                    .frame(height: 0.5)
                                    .padding(.leading, 56)
                            }
                            categoryRow(index: index)
                        }
                    }
                }
            }

            // Add button
            Button(action: { showCategoryPicker = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("Add category")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(Color(red: 0.4, green: 0.65, blue: 1.0))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }

            // Info text
            Text(categoryTargets.isEmpty
                 ? "Set limits on categories you want to keep an eye on."
                 : "Independent limits — they don't need to add up to your monthly budget.")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.25))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 14)
        }
        .background(cardBackground)
        .overlay(cardBorder)
    }

    private func categoryRow(index: Int) -> some View {
        let target = categoryTargets[index]

        return HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(target.category.categoryColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: target.category.categoryIcon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(target.category.categoryColor)
            }

            // Name
            Text(target.category.normalizedCategoryName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()

            // Amount input pill
            HStack(spacing: 2) {
                Text("€")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))

                TextField("0", text: $categoryTargets[index].amountText)
                    .keyboardType(.numberPad)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 52)
                    .multilineTextAlignment(.trailing)
                    .focused($focusedField, equals: .category(target.id))
                    .onChange(of: categoryTargets[index].amountText) { _, newValue in
                        let filtered = newValue.filter { $0.isNumber }
                        if filtered != newValue {
                            categoryTargets[index].amountText = filtered
                        }
                    }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(focusedField == .category(target.id) ? 0.1 : 0.05))
            )

            // Remove
            Button {
                focusedField = nil
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    let _ = categoryTargets.remove(at: index)
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.2))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Auto-Renew Toggle

    private var autoRenewToggle: some View {
        HStack(spacing: 14) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(red: 0.4, green: 0.65, blue: 1.0))
                .frame(width: 40, height: 40)
                .background(
                    Circle().fill(Color(red: 0.4, green: 0.65, blue: 1.0).opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Auto-renew monthly")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Text("Reuse this budget every month")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
            }

            Spacer()

            Toggle("", isOn: $isSmartBudget)
                .labelsHidden()
                .tint(Color(red: 0.4, green: 0.65, blue: 1.0))
        }
        .padding(14)
        .background(cardBackground)
        .overlay(cardBorder)
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button(action: saveBudget) {
            Group {
                if viewModel.isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(isEditing ? "Update Budget" : "Create Budget")
                        .font(.system(size: 17, weight: .bold))
                }
            }
            .foregroundColor(canSave ? .white : .white.opacity(0.35))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: canSave
                                ? [Color(red: 0.35, green: 0.3, blue: 0.95), Color(red: 0.55, green: 0.4, blue: 1.0)]
                                : [Color(white: 0.12), Color(white: 0.12)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
        }
        .disabled(!canSave)
        .shadow(
            color: canSave ? Color(red: 0.5, green: 0.3, blue: 1.0).opacity(0.3) : .clear,
            radius: 12, y: 4
        )
        .padding(.top, 8)
    }

    // MARK: - Card Styling

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color(white: 0.09))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 20)
            .stroke(Color.white.opacity(0.07), lineWidth: 0.5)
    }

    // MARK: - Actions

    private func loadExistingBudget() {
        guard let budget = viewModel.currentBudget else { return }
        monthlyAmountText = String(format: "%.0f", budget.monthlyAmount)
        categoryTargets = (budget.categoryAllocations ?? []).map {
            EditableTarget(category: $0.category, amount: $0.amount)
        }
        isSmartBudget = budget.isSmartBudget
    }

    private func saveBudget() {
        focusedField = nil

        Task {
            let allocations: [CategoryAllocation]? = {
                let targets = categoryTargets
                    .filter { $0.amount > 0 }
                    .map { CategoryAllocation(category: $0.category, amount: $0.amount) }
                return targets.isEmpty ? nil : targets
            }()

            let success: Bool

            if isEditing {
                success = await viewModel.updateBudgetFull(request: UpdateBudgetRequest(
                    monthlyAmount: monthlyAmount,
                    categoryAllocations: allocations,
                    isSmartBudget: isSmartBudget
                ))
            } else {
                success = await viewModel.createBudget(
                    amount: monthlyAmount,
                    categoryAllocations: allocations,
                    isSmartBudget: isSmartBudget
                )
            }

            if success {
                if isEditing {
                    dismiss()
                } else {
                    showSuccessSheet = true
                }
            }
        }
    }
}

// MARK: - Category Picker Sheet

struct CategoryPickerSheet: View {
    let existingCategories: Set<String>
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var registry: CategoryRegistryManager { CategoryRegistryManager.shared }

    private var availableCategories: [String] {
        let all = registry.allSubCategories.filter { !existingCategories.contains($0) }
        if searchText.isEmpty { return all }
        return all.filter { $0.lowercased().contains(searchText.lowercased()) }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(white: 0.06).ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Search
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.35))

                            TextField("Search categories", text: $searchText)
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.06))
                        )
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)

                        // List
                        ForEach(availableCategories, id: \.self) { category in
                            Button {
                                onSelect(category)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(category.categoryColor.opacity(0.15))
                                            .frame(width: 38, height: 38)

                                        Image(systemName: category.categoryIcon)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(category.categoryColor)
                                    }

                                    Text(category.normalizedCategoryName)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.white)

                                    Spacer()

                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white.opacity(0.2))
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                            }

                            if category != availableCategories.last {
                                Rectangle()
                                    .fill(Color.white.opacity(0.05))
                                    .frame(height: 0.5)
                                    .padding(.leading, 70)
                            }
                        }

                        if availableCategories.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white.opacity(0.2))

                                Text("No categories found")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        }
                    }
                }
            }
            .navigationTitle("Add Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Preview

#Preview {
    BudgetSetupView(viewModel: BudgetViewModel())
}
