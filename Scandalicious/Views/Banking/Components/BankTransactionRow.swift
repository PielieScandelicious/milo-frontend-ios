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
    let onToggleSelection: () -> Void
    let onCategoryChange: (GroceryCategory) -> Void

    @State private var showingCategoryPicker = false

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

            // Transaction Info
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.counterpartyName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(formatDate(transaction.bookingDate))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))

                    if let description = transaction.description, !description.isEmpty {
                        Text(description)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.4))
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Amount
            VStack(alignment: .trailing, spacing: 4) {
                Text(transaction.displayAmount)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(transaction.amountColor)

                // Category Button
                Button {
                    showingCategoryPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: category.icon)
                            .font(.system(size: 10))

                        Text(category.rawValue)
                            .font(.system(size: 10, weight: .medium))

                        // Confidence indicator
                        if let confidence = transaction.categoryConfidence, confidence > 0.7 {
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
        .sheet(isPresented: $showingCategoryPicker) {
            CategoryPickerSheet(
                selectedCategory: category,
                onSelect: { newCategory in
                    onCategoryChange(newCategory)
                    showingCategoryPicker = false
                }
            )
            .presentationDetents([.medium])
        }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
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
                amount: -45.67,
                currency: "EUR",
                creditorName: "Colruyt",
                debtorName: nil,
                bookingDate: Date(),
                description: "Weekly groceries",
                status: .pending,
                suggestedCategory: "Fresh Produce",
                categoryConfidence: 0.85
            ),
            isSelected: true,
            category: .freshProduce,
            onToggleSelection: {},
            onCategoryChange: { _ in }
        )

        BankTransactionRow(
            transaction: BankTransactionResponse(
                id: "2",
                accountId: "acc1",
                amount: 150.00,
                currency: "EUR",
                creditorName: nil,
                debtorName: "Salary Payment",
                bookingDate: Date().addingTimeInterval(-86400),
                description: nil,
                status: .pending,
                suggestedCategory: nil,
                categoryConfidence: nil
            ),
            isSelected: false,
            category: .other,
            onToggleSelection: {},
            onCategoryChange: { _ in }
        )
    }
    .padding()
    .background(Color(white: 0.08))
}
