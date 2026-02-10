//
//  EditCategoryBudgetsSheet.swift
//  Scandalicious
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

// MARK: - Edit Category Budgets Sheet

/// Full-screen sheet for editing category budget allocations.
/// Compact rows expand on tap for slider editing. Sort order is fixed to prevent layout jumps.
struct EditCategoryBudgetsSheet: View {
    let initialBudget: UserBudget
    let onSave: ([CategoryAllocation]) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var categoryAllocations: [EditableCategoryAllocation] = []
    @State private var targetBudget: Double = 0
    @State private var isSaving = false
    @State private var expandedCategoryId: UUID?
    @State private var smartAnchorCategory: String?
    @State private var showSmartAnchorSheet = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(white: 0.05).ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            targetBudgetHeader

                            categoryList

                            Spacer().frame(height: 100)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                    }
                    .onChange(of: expandedCategoryId) { newId in
                        if let newId {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    proxy.scrollTo(newId, anchor: .center)
                                }
                            }
                        }
                    }
                }

                VStack {
                    Spacer()
                    saveButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white.opacity(0.7))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: resetAllCategories) {
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
        .onAppear { setupInitialState() }
        .sheet(isPresented: $showSmartAnchorSheet) {
            if let categoryName = smartAnchorCategory {
                SmartAnchorSheetLoader(
                    categoryName: categoryName,
                    onSetBudget: { _, amount in
                        // Find the category and update its amount
                        if let index = categoryAllocations.firstIndex(where: { $0.category == categoryName }) {
                            handleCategoryEdit(at: index, newAmount: amount)
                        }
                    }
                )
            }
        }
    }

    // MARK: - Target Budget Header

    private var targetBudgetHeader: some View {
        VStack(spacing: 10) {
            Text("Target Monthly Budget")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.5))

            Text(String(format: "€%.0f", targetBudget))
                .font(.system(size: 42, weight: .bold, design: .rounded))
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

            let currentTotal = categoryAllocations.reduce(0) { $0 + $1.amount }
            let difference = currentTotal - targetBudget

            if abs(difference) < 0.5 {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                    Text("Budgets balanced")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(Color(red: 0.3, green: 0.8, blue: 0.5))
            } else {
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                    Text(String(format: "€%.0f %@", abs(difference), difference > 0 ? "over budget" : "under budget"))
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(Color(red: 1.0, green: 0.75, blue: 0.3))
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: - Category List (Flat, Fixed Order)

    private var budgetedIndices: [Int] {
        categoryAllocations.indices.filter { categoryAllocations[$0].amount > 0 || categoryAllocations[$0].originalAmount > 0 }
    }

    private var unbudgetedIndices: [Int] {
        categoryAllocations.indices.filter { categoryAllocations[$0].amount <= 0 && categoryAllocations[$0].originalAmount <= 0 }
    }

    private var categoryList: some View {
        VStack(spacing: 6) {
            // Budgeted categories
            if !budgetedIndices.isEmpty {
                ForEach(budgetedIndices, id: \.self) { index in
                    categoryRow(at: index)
                }
            }

            // Unbudgeted categories section
            if !unbudgetedIndices.isEmpty {
                HStack {
                    Text("Other Categories")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.35))
                        .textCase(.uppercase)
                    Spacer()
                }
                .padding(.top, 12)
                .padding(.bottom, 2)
                .padding(.horizontal, 4)

                ForEach(unbudgetedIndices, id: \.self) { index in
                    categoryRow(at: index)
                }
            }
        }
    }

    private func categoryRow(at index: Int) -> some View {
        let isExpanded = categoryAllocations[index].id == expandedCategoryId

        return CompactCategoryRow(
            allocation: $categoryAllocations[index],
            isExpanded: isExpanded,
            totalBudget: targetBudget,
            onTap: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    if isExpanded {
                        expandedCategoryId = nil
                    } else {
                        expandedCategoryId = categoryAllocations[index].id
                    }
                }
            },
            onAmountChanged: { newAmount in
                handleCategoryEdit(at: index, newAmount: newAmount)
            },
            onReset: {
                resetCategory(at: index)
            },
            onRemove: {
                removeCategory(at: index)
            },
            onSmartSuggest: {
                smartAnchorCategory = categoryAllocations[index].category
                showSmartAnchorSheet = true
            }
        )
        .id(categoryAllocations[index].id)
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
                    isLocked: false
                )
            }
        }

        // Ensure ALL categories from the registry are present (add missing ones with €0)
        let existingCategories = Set(categoryAllocations.map { $0.category })
        let registry = CategoryRegistryManager.shared
        for subCategory in registry.allSubCategories {
            if !existingCategories.contains(subCategory) {
                categoryAllocations.append(
                    EditableCategoryAllocation(
                        category: subCategory,
                        amount: 0,
                        originalAmount: 0,
                        isLocked: false
                    )
                )
            }
        }

        // Sort ONCE: categories with budget first (by amount desc), then €0 categories (registry order)
        let registryOrder = registry.allSubCategories
        categoryAllocations.sort { a, b in
            if a.originalAmount > 0 && b.originalAmount > 0 {
                return a.originalAmount > b.originalAmount
            }
            if a.originalAmount > 0 { return true }
            if b.originalAmount > 0 { return false }
            let aIdx = registryOrder.firstIndex(of: a.category) ?? Int.max
            let bIdx = registryOrder.firstIndex(of: b.category) ?? Int.max
            return aIdx < bIdx
        }
    }

    private func handleCategoryEdit(at index: Int, newAmount: Double) {
        categoryAllocations[index].amount = newAmount
        categoryAllocations[index].isLocked = true

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

    private func removeCategory(at index: Int) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            categoryAllocations[index].amount = 0
            categoryAllocations[index].isLocked = true
            expandedCategoryId = nil
        }
        recalculateNonLockedCategories()
    }

    private func resetCategory(at index: Int) {
        categoryAllocations[index].amount = categoryAllocations[index].originalAmount
        categoryAllocations[index].isLocked = false
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

        // Only save categories where a budget is actually set (amount > 0)
        let allocations = categoryAllocations
            .filter { $0.amount > 0 }
            .map { editable in
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

// MARK: - Compact Category Row (Accordion)

/// A compact row that shows category info at a glance, expanding to reveal a slider on tap.
struct CompactCategoryRow: View {
    @Binding var allocation: EditableCategoryAllocation
    let isExpanded: Bool
    let totalBudget: Double
    let onTap: () -> Void
    let onAmountChanged: (Double) -> Void
    let onReset: () -> Void
    var onRemove: (() -> Void)? = nil
    var onSmartSuggest: (() -> Void)? = nil

    private var percentage: Double {
        guard totalBudget > 0 else { return 0 }
        return (allocation.amount / totalBudget) * 100
    }

    private var sliderMax: Double {
        let base = allocation.originalAmount > 0 ? allocation.originalAmount * 3 : totalBudget * 0.25
        return max(50, min(totalBudget, base))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Compact header - always visible
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // Category icon
                    ZStack {
                        Circle()
                            .fill(allocation.category.categoryColor.opacity(0.2))
                            .frame(width: 36, height: 36)

                        Image(systemName: allocation.category.categoryIcon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(allocation.category.categoryColor)
                    }

                    // Name + bar
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 5) {
                            Text(allocation.category.normalizedCategoryName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            if allocation.isEdited {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))
                            }
                        }

                        // Thin progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white.opacity(0.08))
                                    .frame(height: 4)

                                RoundedRectangle(cornerRadius: 2)
                                    .fill(allocation.category.categoryColor)
                                    .frame(width: max(0, geometry.size.width * CGFloat(min(1.0, percentage / 100))), height: 4)
                            }
                        }
                        .frame(height: 4)
                    }

                    Spacer()

                    // Amount + percentage
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "€%.0f", allocation.amount))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text(String(format: "%.0f%%", percentage))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }

                    // Expand chevron
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.3))
                        .frame(width: 16)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(PlainButtonStyle())

            // Expanded controls
            if isExpanded {
                VStack(spacing: 12) {
                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.horizontal, 14)

                    // Stepper: [-] amount [+]
                    HStack(spacing: 16) {
                        Button(action: decrementAmount) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))
                        }
                        .disabled(allocation.amount <= 0)

                        Text(String(format: "€%.0f", allocation.amount))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(minWidth: 90)

                        Button(action: incrementAmount) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))
                        }
                        .disabled(allocation.amount >= totalBudget)
                    }
                    .frame(maxWidth: .infinity)

                    // Slider
                    VStack(spacing: 4) {
                        Slider(
                            value: Binding(
                                get: { min(allocation.amount, sliderMax) },
                                set: { newValue in
                                    let rounded = round(newValue / 5) * 5
                                    onAmountChanged(rounded)
                                }
                            ),
                            in: 0...sliderMax,
                            step: 5
                        )
                        .tint(allocation.category.categoryColor)

                        HStack {
                            Text("€0")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.25))
                            Spacer()
                            Text(String(format: "€%.0f", sliderMax))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.25))
                        }
                    }
                    .padding(.horizontal, 14)

                    // Action row: Smart Suggest + Reset + Remove
                    HStack(spacing: 12) {
                        if let onSmartSuggest {
                            Button(action: onSmartSuggest) {
                                HStack(spacing: 5) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text("Smart Suggest")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(.yellow.opacity(0.8))
                                .padding(.vertical, 6)
                            }
                        }

                        if allocation.isEdited {
                            Button(action: onReset) {
                                HStack(spacing: 5) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text("Reset to €\(String(format: "%.0f", allocation.originalAmount))")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.vertical, 6)
                            }
                        }

                        if let onRemove, allocation.amount > 0 {
                            Spacer()
                            Button(action: onRemove) {
                                HStack(spacing: 5) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text("Remove")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(Color(red: 1.0, green: 0.4, blue: 0.4))
                                .padding(.vertical, 6)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                }
                .padding(.bottom, 12)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isExpanded ? Color.white.opacity(0.07) : Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    allocation.isEdited
                        ? Color(red: 0.3, green: 0.7, blue: 1.0).opacity(0.3)
                        : (isExpanded ? Color.white.opacity(0.12) : Color.white.opacity(0.06)),
                    lineWidth: 1
                )
        )
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
