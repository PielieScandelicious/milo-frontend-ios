//
//  EditCategoryBudgetsSheet.swift
//  Scandalicious
//

import SwiftUI

// MARK: - Edit Category Budgets Sheet

/// Sheet for editing category budget targets (guardrails).
/// Categories are independent — amounts don't need to sum to the monthly budget.
struct EditCategoryBudgetsSheet: View {
    let initialBudget: UserBudget
    let onSave: ([CategoryAllocation]) -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: FocusField?

    @State private var categoryAllocations: [EditableCategoryAllocation] = []
    @State private var isSaving = false
    @State private var showCategoryPicker = false

    private enum FocusField: Hashable {
        case category(UUID)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(white: 0.06).ignoresSafeArea()
                    .onTapGesture { focusedField = nil }

                ScrollView {
                    VStack(spacing: 16) {
                        headerInfo
                        categoryList
                        addCategoryButton
                        infoText
                        Spacer().frame(height: 80)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)

                // Floating save button
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
        .onAppear { setupInitialState() }
        .sheet(isPresented: $showCategoryPicker) {
            CategoryPickerSheet(
                existingCategories: Set(categoryAllocations.map { $0.category })
            ) { category in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    let alloc = EditableCategoryAllocation(
                        category: category,
                        amount: 50,
                        originalAmount: 0
                    )
                    categoryAllocations.append(alloc)

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        focusedField = .category(alloc.id)
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var headerInfo: some View {
        VStack(spacing: 10) {
            Text("Monthly Budget")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.5))

            Text(String(format: "€%.0f", initialBudget.monthlyAmount))
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

            let targetCount = categoryAllocations.filter { $0.amount > 0 }.count
            Text("\(targetCount) category target\(targetCount == 1 ? "" : "s")")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.vertical, 12)
    }

    // MARK: - Category List

    private var categoryList: some View {
        Group {
            if !categoryAllocations.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(categoryAllocations.enumerated()), id: \.element.id) { index, _ in
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
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(white: 0.09))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.07), lineWidth: 0.5)
                )
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "tag")
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.15))

                    Text("No category targets yet")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.35))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(white: 0.09))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.07), lineWidth: 0.5)
                )
            }
        }
    }

    private func categoryRow(index: Int) -> some View {
        let alloc = categoryAllocations[index]

        return HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(alloc.category.categoryColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: alloc.category.categoryIcon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(alloc.category.categoryColor)
            }

            // Name + edit indicator
            VStack(alignment: .leading, spacing: 1) {
                Text(alloc.category.normalizedCategoryName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                if alloc.isEdited {
                    Text("Edited")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(red: 0.4, green: 0.65, blue: 1.0))
                }
            }

            Spacer()

            // Amount input pill
            HStack(spacing: 2) {
                Text("€")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))

                TextField("0", text: $categoryAllocations[index].amountText)
                    .keyboardType(.numberPad)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 52)
                    .multilineTextAlignment(.trailing)
                    .focused($focusedField, equals: .category(alloc.id))
                    .onChange(of: categoryAllocations[index].amountText) { _, newValue in
                        let filtered = newValue.filter { $0.isNumber }
                        if filtered != newValue {
                            categoryAllocations[index].amountText = filtered
                        }
                    }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(focusedField == .category(alloc.id) ? 0.1 : 0.05))
            )

            // Remove
            Button {
                focusedField = nil
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    categoryAllocations.remove(at: index)
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.2))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .id(alloc.id)
    }

    // MARK: - Add Category Button

    private var addCategoryButton: some View {
        Button(action: { showCategoryPicker = true }) {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                Text("Add category target")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(Color(red: 0.4, green: 0.65, blue: 1.0))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.4, green: 0.65, blue: 1.0).opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                Color(red: 0.4, green: 0.65, blue: 1.0).opacity(0.2),
                                style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                            )
                    )
            )
        }
    }

    // MARK: - Info Text

    private var infoText: some View {
        Text("Independent limits — they don't need to add up to your monthly budget.")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white.opacity(0.25))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button(action: handleSave) {
            Group {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Save Changes")
                        .font(.system(size: 17, weight: .bold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.35, green: 0.3, blue: 0.95), Color(red: 0.55, green: 0.4, blue: 1.0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .shadow(color: Color(red: 0.5, green: 0.3, blue: 1.0).opacity(0.3), radius: 12, y: 4)
        }
        .disabled(isSaving)
    }

    // MARK: - Logic

    private func setupInitialState() {
        if let allocations = initialBudget.categoryAllocations {
            categoryAllocations = allocations.map {
                EditableCategoryAllocation(
                    category: $0.category,
                    amount: $0.amount,
                    originalAmount: $0.amount
                )
            }
        }
    }

    private func handleSave() {
        focusedField = nil
        isSaving = true

        let allocations = categoryAllocations
            .filter { $0.amount > 0 }
            .map { CategoryAllocation(category: $0.category, amount: $0.amount) }

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
    var amountText: String
    let originalAmount: Double

    var amount: Double { Double(amountText) ?? 0 }
    var isEdited: Bool { abs(amount - originalAmount) > 0.5 }

    init(category: String, amount: Double, originalAmount: Double) {
        self.category = category
        self.amountText = amount > 0 ? String(format: "%.0f", amount) : ""
        self.originalAmount = originalAmount
    }
}

// MARK: - Preview

#Preview {
    let sampleBudget = UserBudget(
        id: "1",
        userId: "user1",
        monthlyAmount: 850,
        categoryAllocations: [
            CategoryAllocation(category: "Meat & Fish", amount: 200),
            CategoryAllocation(category: "Fresh Produce", amount: 150),
            CategoryAllocation(category: "Dairy & Eggs", amount: 100),
            CategoryAllocation(category: "Snacks & Sweets", amount: 80)
        ]
    )

    return EditCategoryBudgetsSheet(initialBudget: sampleBudget) { allocations in
        print("Saved allocations: \(allocations)")
    }
}
