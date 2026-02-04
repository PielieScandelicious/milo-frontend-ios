//
//  EditCategoryBudgetsSheet.swift
//  Scandalicious
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

// MARK: - Edit Category Budgets Sheet

/// Full-screen sheet allowing users to customize their category budget allocations
/// Features auto-adjustment of non-locked categories to maintain target budget
struct EditCategoryBudgetsSheet: View {
    let initialBudget: UserBudget
    let onSave: ([CategoryAllocation]) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var categoryAllocations: [EditableCategoryAllocation] = []
    @State private var targetBudget: Double = 0
    @State private var showResetAllConfirmation = false
    @State private var isSaving = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(white: 0.05).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Target Budget Header
                        targetBudgetHeader

                        // Instructions
                        instructionsCard

                        // Category List
                        categoryList

                        Spacer().frame(height: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }

                // Floating Save Button
                VStack {
                    Spacer()
                    saveButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                }
            }
            .navigationTitle("Edit Category Budgets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white.opacity(0.7))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showResetAllConfirmation = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Reset All")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))
                    }
                    .disabled(!hasAnyEdits)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            setupInitialState()
        }
        .alert("Reset All Changes?", isPresented: $showResetAllConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset All", role: .destructive) {
                resetAllCategories()
            }
        } message: {
            Text("This will reset all category budgets to their AI-suggested amounts.")
        }
    }

    // MARK: - Target Budget Header

    private var targetBudgetHeader: some View {
        VStack(spacing: 12) {
            Text("Target Monthly Budget")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))

            Text(String(format: "€%.0f", targetBudget))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.3, green: 0.7, blue: 1.0),
                            Color(red: 0.5, green: 0.4, blue: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            // Total validation
            let currentTotal = categoryAllocations.reduce(0) { $0 + $1.amount }
            let difference = currentTotal - targetBudget

            if abs(difference) < 0.5 {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                    Text("Budgets balanced")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(Color(red: 0.3, green: 0.8, blue: 0.5))
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                    Text(String(format: "€%.0f %@", abs(difference), difference > 0 ? "over budget" : "under budget"))
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(Color(red: 1.0, green: 0.75, blue: 0.3))
            }
        }
        .padding(.vertical, 20)
    }

    // MARK: - Instructions Card

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))

                Text("How it works")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                instructionRow(icon: "slider.horizontal.3", text: "Tap any category to edit its budget")
                instructionRow(icon: "arrow.triangle.2.circlepath", text: "Other categories adjust automatically")
                instructionRow(icon: "lock.fill", text: "Edited categories show a blue badge")
                instructionRow(icon: "arrow.counterclockwise", text: "Reset individual or all categories")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.3, green: 0.7, blue: 1.0).opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(red: 0.3, green: 0.7, blue: 1.0).opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func instructionRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))
                .frame(width: 16)

            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
    }

    // MARK: - Category List (Grouped)

    /// Group categories by their parent group using CategoryRegistryManager
    private var groupedCategoryIndices: [(group: String, indices: [Int])] {
        let registry = CategoryRegistryManager.shared
        var groups: [String: [Int]] = [:]

        for index in categoryAllocations.indices {
            let group = registry.groupForSubCategory(categoryAllocations[index].category)
            groups[group, default: []].append(index)
        }

        return groups
            .map { (group: $0.key, indices: $0.value) }
            .sorted { group1, group2 in
                let total1 = group1.indices.reduce(0.0) { $0 + categoryAllocations[$1].amount }
                let total2 = group2.indices.reduce(0.0) { $0 + categoryAllocations[$1].amount }
                return total1 > total2
            }
    }

    private var categoryList: some View {
        let grouped = groupedCategoryIndices

        return VStack(spacing: 20) {
            if grouped.count <= 1 {
                VStack(spacing: 12) {
                    ForEach(categoryAllocations.indices, id: \.self) { index in
                        EditableCategoryCard(
                            allocation: $categoryAllocations[index],
                            totalBudget: targetBudget,
                            onAmountChanged: { newAmount in
                                handleCategoryEdit(at: index, newAmount: newAmount)
                            },
                            onReset: {
                                resetCategory(at: index)
                            }
                        )
                    }
                }
            } else {
                ForEach(grouped, id: \.group) { section in
                    VStack(alignment: .leading, spacing: 12) {
                        let registry = CategoryRegistryManager.shared
                        let groupTotal = section.indices.reduce(0.0) { $0 + categoryAllocations[$1].amount }

                        HStack(spacing: 8) {
                            Image(systemName: registry.iconForGroup(section.group))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(registry.colorForGroup(section.group))

                            Text(section.group)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)

                            Text("(\(section.indices.count))")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.4))

                            Spacer()

                            Text(String(format: "€%.0f", groupTotal))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.horizontal, 4)
                        .padding(.top, 4)

                        ForEach(section.indices, id: \.self) { index in
                            EditableCategoryCard(
                                allocation: $categoryAllocations[index],
                                totalBudget: targetBudget,
                                onAmountChanged: { newAmount in
                                    handleCategoryEdit(at: index, newAmount: newAmount)
                                },
                                onReset: {
                                    resetCategory(at: index)
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button(action: handleSave) {
            HStack(spacing: 10) {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))

                    Text("Save Changes")
                        .font(.system(size: 17, weight: .bold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.4, green: 0.3, blue: 0.95),
                        Color(red: 0.6, green: 0.4, blue: 1.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: Color(red: 0.5, green: 0.3, blue: 1.0).opacity(0.4), radius: 12, y: 4)
        }
        .disabled(isSaving)
    }

    // MARK: - Helper Properties

    private var hasAnyEdits: Bool {
        categoryAllocations.contains { $0.isEdited }
    }

    // MARK: - Setup & Logic

    private func setupInitialState() {
        targetBudget = initialBudget.monthlyAmount

        if let allocations = initialBudget.categoryAllocations {
            categoryAllocations = allocations.map { allocation in
                EditableCategoryAllocation(
                    category: allocation.category,
                    amount: allocation.amount,
                    originalAmount: allocation.amount,
                    isLocked: allocation.isLocked
                )
            }
        }
    }

    private func handleCategoryEdit(at index: Int, newAmount: Double) {
        // Mark this category as edited (locked)
        categoryAllocations[index].amount = newAmount
        categoryAllocations[index].isLocked = true

        // Calculate how much we need to redistribute
        let lockedTotal = categoryAllocations.filter { $0.isLocked }.reduce(0) { $0 + $1.amount }
        let remainingBudget = targetBudget - lockedTotal

        // Get non-locked categories
        let nonLockedIndices = categoryAllocations.indices.filter { !categoryAllocations[$0].isLocked }

        guard !nonLockedIndices.isEmpty && remainingBudget > 0 else {
            // If all are locked or no budget remaining, just return
            return
        }

        // Calculate total original amount for non-locked categories
        let nonLockedOriginalTotal = nonLockedIndices.reduce(0.0) { total, idx in
            total + categoryAllocations[idx].originalAmount
        }

        guard nonLockedOriginalTotal > 0 else { return }

        // Redistribute proportionally based on original amounts
        for idx in nonLockedIndices {
            let proportion = categoryAllocations[idx].originalAmount / nonLockedOriginalTotal
            categoryAllocations[idx].amount = max(0, remainingBudget * proportion)
        }
    }

    private func resetCategory(at index: Int) {
        categoryAllocations[index].amount = categoryAllocations[index].originalAmount
        categoryAllocations[index].isLocked = false

        // Recalculate all non-locked categories
        recalculateNonLockedCategories()
    }

    private func resetAllCategories() {
        for index in categoryAllocations.indices {
            categoryAllocations[index].amount = categoryAllocations[index].originalAmount
            categoryAllocations[index].isLocked = false
        }
    }

    private func recalculateNonLockedCategories() {
        let lockedTotal = categoryAllocations.filter { $0.isLocked }.reduce(0) { $0 + $1.amount }
        let remainingBudget = targetBudget - lockedTotal

        let nonLockedIndices = categoryAllocations.indices.filter { !categoryAllocations[$0].isLocked }

        guard !nonLockedIndices.isEmpty && remainingBudget > 0 else { return }

        let nonLockedOriginalTotal = nonLockedIndices.reduce(0.0) { total, idx in
            total + categoryAllocations[idx].originalAmount
        }

        guard nonLockedOriginalTotal > 0 else { return }

        for idx in nonLockedIndices {
            let proportion = categoryAllocations[idx].originalAmount / nonLockedOriginalTotal
            categoryAllocations[idx].amount = max(0, remainingBudget * proportion)
        }
    }

    private func handleSave() {
        isSaving = true

        // Convert back to CategoryAllocation
        let allocations = categoryAllocations.map { editable in
            CategoryAllocation(
                category: editable.category,
                amount: editable.amount,
                isLocked: editable.isLocked
            )
        }

        onSave(allocations)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSaving = false
            dismiss()
        }
    }
}

// MARK: - Editable Category Allocation

struct EditableCategoryAllocation: Identifiable {
    let id = UUID()
    let category: String
    var amount: Double
    let originalAmount: Double
    var isLocked: Bool

    var isEdited: Bool {
        abs(amount - originalAmount) > 0.5 || isLocked
    }
}

// MARK: - Editable Category Card

struct EditableCategoryCard: View {
    @Binding var allocation: EditableCategoryAllocation
    let totalBudget: Double
    let onAmountChanged: (Double) -> Void
    let onReset: () -> Void

    @State private var isEditing = false
    @State private var localAmount: Double = 0
    @FocusState private var isFocused: Bool

    private var percentage: Double {
        guard totalBudget > 0 else { return 0 }
        return (allocation.amount / totalBudget) * 100
    }

    private var categoryIcon: String {
        allocation.category.categoryIcon
    }

    var body: some View {
        VStack(spacing: 14) {
            // Header
            HStack(spacing: 12) {
                // Category icon
                ZStack {
                    Circle()
                        .fill(allocation.category.categoryColor.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: categoryIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(allocation.category.categoryColor)
                }

                // Category name and percentage
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(allocation.category)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)

                        // Edited badge
                        if allocation.isEdited {
                            HStack(spacing: 3) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 10))
                                Text("Edited")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color(red: 0.3, green: 0.7, blue: 1.0).opacity(0.15))
                            )
                        }
                    }

                    Text(String(format: "%.1f%% of budget", percentage))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                // Reset button (only show if edited)
                if allocation.isEdited {
                    Button(action: onReset) {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }

            // Amount Editor
            HStack(spacing: 12) {
                // Minus button
                Button(action: { decrementAmount() }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))
                }
                .disabled(allocation.amount <= 5)

                // Amount display (tappable to edit)
                Button(action: { startEditing() }) {
                    Text(String(format: "€%.0f", allocation.amount))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(minWidth: 120)
                }

                // Plus button
                Button(action: { incrementAmount() }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))
                }
                .disabled(allocation.amount >= totalBudget)
            }
            .frame(maxWidth: .infinity)

            // Slider
            VStack(spacing: 6) {
                Slider(
                    value: Binding(
                        get: { allocation.amount },
                        set: { newValue in
                            let roundedValue = round(newValue / 5) * 5
                            onAmountChanged(roundedValue)
                        }
                    ),
                    in: 0...min(totalBudget, allocation.originalAmount * 3),
                    step: 5
                )
                .tint(allocation.category.categoryColor)

                // Min/Max labels
                HStack {
                    Text("€0")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))

                    Spacer()

                    Text(String(format: "€%.0f", min(totalBudget, allocation.originalAmount * 3)))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    allocation.isEdited ? Color(red: 0.3, green: 0.7, blue: 1.0).opacity(0.4) : Color.white.opacity(0.08),
                    lineWidth: allocation.isEdited ? 2 : 1
                )
        )
        .onAppear {
            localAmount = allocation.amount
        }
    }

    private func startEditing() {
        isEditing = true
        localAmount = allocation.amount
        isFocused = true
    }

    private func incrementAmount() {
        let newAmount = min(totalBudget, allocation.amount + 5)
        onAmountChanged(newAmount)
    }

    private func decrementAmount() {
        let newAmount = max(0, allocation.amount - 5)
        onAmountChanged(newAmount)
    }
}

// MARK: - Preview

#Preview {
    let sampleBudget = UserBudget(
        id: "1",
        userId: "user1",
        monthlyAmount: 850,
        categoryAllocations: [
            CategoryAllocation(category: "Meat & Fish", amount: 200, isLocked: false),
            CategoryAllocation(category: "Fresh Produce", amount: 150, isLocked: false),
            CategoryAllocation(category: "Dairy & Eggs", amount: 100, isLocked: false),
            CategoryAllocation(category: "Snacks & Sweets", amount: 80, isLocked: false),
            CategoryAllocation(category: "Bakery", amount: 70, isLocked: false),
            CategoryAllocation(category: "Household", amount: 120, isLocked: false),
            CategoryAllocation(category: "Frozen", amount: 60, isLocked: false),
            CategoryAllocation(category: "Drinks (Soft/Soda)", amount: 70, isLocked: false)
        ],
        notificationsEnabled: true,
        alertThresholds: [0.5, 0.75, 0.9]
    )

    return EditCategoryBudgetsSheet(initialBudget: sampleBudget) { allocations in
        print("Saved allocations: \(allocations)")
    }
}
