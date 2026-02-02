//
//  BankTransactionRow.swift
//  Scandalicious
//
//  Created by Claude on 01/02/2026.
//

import SwiftUI

struct BankTransactionRow: View {
    let transaction: BankTransactionResponse
    let isSelected: Bool
    let category: GroceryCategory
    let customDescription: String?
    let onToggleSelection: () -> Void
    let onCategoryChange: (GroceryCategory) -> Void
    let onDescriptionChange: (String) -> Void

    @State private var showingEditSheet = false

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button {
                onToggleSelection()
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? Color(red: 0.3, green: 0.7, blue: 1.0) : .white.opacity(0.3))
            }
            .buttonStyle(.plain)

            // Transaction Info - Tappable for editing
            Button {
                showingEditSheet = true
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.counterpartyName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(formatDate(transaction.bookingDateParsed))
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))

                        // Show custom description or original
                        let displayDescription = customDescription ?? transaction.description
                        if let description = displayDescription, !description.isEmpty {
                            HStack(spacing: 4) {
                                Text(description)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.4))
                                    .lineLimit(1)

                                // Edit indicator if custom
                                if customDescription != nil {
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0).opacity(0.6))
                                }
                            }
                        } else {
                            HStack(spacing: 4) {
                                Text("Add description")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.3))
                                    .italic()

                                Image(systemName: "plus.circle")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.3))
                            }
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Amount
            VStack(alignment: .trailing, spacing: 4) {
                Text(transaction.displayAmount)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(transaction.amountColor)

                // Category Button
                Button {
                    showingEditSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: category.icon)
                            .font(.system(size: 10))

                        Text(category.rawValue)
                            .font(.system(size: 10, weight: .medium))

                        // Confidence indicator (only if no override)
                        if customDescription == nil,
                           let confidence = transaction.categoryConfidence, confidence > 0.7 {
                            Image(systemName: "sparkles")
                                .font(.system(size: 8))
                        }
                    }
                    .foregroundColor(category.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(category.color.opacity(0.15))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color(red: 0.3, green: 0.7, blue: 1.0).opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
        .sheet(isPresented: $showingEditSheet) {
            TransactionEditSheet(
                transaction: transaction,
                selectedCategory: category,
                currentDescription: customDescription ?? transaction.description ?? "",
                onSave: { newCategory, newDescription in
                    onCategoryChange(newCategory)
                    onDescriptionChange(newDescription)
                    showingEditSheet = false
                },
                onCancel: {
                    showingEditSheet = false
                }
            )
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Transaction Edit Sheet

struct TransactionEditSheet: View {
    let transaction: BankTransactionResponse
    let selectedCategory: GroceryCategory
    let currentDescription: String
    let onSave: (GroceryCategory, String) -> Void
    let onCancel: () -> Void

    @State private var editedCategory: GroceryCategory
    @State private var editedDescription: String
    @FocusState private var isDescriptionFocused: Bool

    init(
        transaction: BankTransactionResponse,
        selectedCategory: GroceryCategory,
        currentDescription: String,
        onSave: @escaping (GroceryCategory, String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.transaction = transaction
        self.selectedCategory = selectedCategory
        self.currentDescription = currentDescription
        self.onSave = onSave
        self.onCancel = onCancel
        _editedCategory = State(initialValue: selectedCategory)
        _editedDescription = State(initialValue: currentDescription)
    }

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Transaction Summary
                    transactionSummary

                    // Description Field
                    descriptionSection

                    // Category Picker
                    categorySection
                }
                .padding()
            }
            .background(Color(white: 0.08))
            .navigationTitle("Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.white.opacity(0.6))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(editedCategory, editedDescription)
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Transaction Summary

    private var transactionSummary: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.counterpartyName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)

                    Text(formatDate(transaction.bookingDateParsed))
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                Text(transaction.displayAmount)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(transaction.amountColor)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.12))
        )
    }

    // MARK: - Description Section

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.6))

            TextField("Add a description...", text: $editedDescription)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(white: 0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    isDescriptionFocused ? Color(red: 0.3, green: 0.7, blue: 1.0).opacity(0.5) : Color.white.opacity(0.1),
                                    lineWidth: 1
                                )
                        )
                )
                .focused($isDescriptionFocused)

            Text("This will be saved as the item name in your spending overview")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.4))
        }
    }

    // MARK: - Category Section

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.6))

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(GroceryCategory.allCases) { category in
                    CategoryPickerItem(
                        category: category,
                        isSelected: category == editedCategory,
                        onTap: {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                editedCategory = category
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Category Picker Sheet

struct CategoryPickerSheet: View {
    let selectedCategory: GroceryCategory
    let onSelect: (GroceryCategory) -> Void

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(GroceryCategory.allCases) { category in
                        CategoryPickerItem(
                            category: category,
                            isSelected: category == selectedCategory,
                            onTap: {
                                onSelect(category)
                            }
                        )
                    }
                }
                .padding()
            }
            .background(Color(white: 0.08))
            .navigationTitle("Select Category")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Category Picker Item

struct CategoryPickerItem: View {
    let category: GroceryCategory
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(category.color.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: category.icon)
                        .font(.system(size: 18))
                        .foregroundColor(category.color)
                }

                Text(category.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: isSelected ? 0.2 : 0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? category.color : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack {
        BankTransactionRow(
            transaction: BankTransactionResponse(
                id: "1",
                accountId: "acc1",
                transactionId: "txn1",
                amount: -45.67,
                currency: "EUR",
                creditorName: "Colruyt",
                debtorName: nil,
                bookingDate: "2026-02-01",
                valueDate: "2026-02-01",
                description: "Weekly groceries",
                status: .pending,
                importedTransactionId: nil,
                suggestedCategory: "Fresh Produce",
                categoryConfidence: 0.85,
                createdAt: nil
            ),
            isSelected: true,
            category: .freshProduce,
            customDescription: nil,
            onToggleSelection: {},
            onCategoryChange: { _ in },
            onDescriptionChange: { _ in }
        )

        BankTransactionRow(
            transaction: BankTransactionResponse(
                id: "2",
                accountId: "acc1",
                transactionId: "txn2",
                amount: 150.00,
                currency: "EUR",
                creditorName: nil,
                debtorName: "Salary Payment",
                bookingDate: "2026-01-31",
                valueDate: nil,
                description: nil,
                status: .pending,
                importedTransactionId: nil,
                suggestedCategory: nil,
                categoryConfidence: nil,
                createdAt: nil
            ),
            isSelected: false,
            category: .other,
            customDescription: "Custom description",
            onToggleSelection: {},
            onCategoryChange: { _ in },
            onDescriptionChange: { _ in }
        )
    }
    .padding()
    .background(Color(white: 0.08))
}
