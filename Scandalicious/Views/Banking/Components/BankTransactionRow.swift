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
    let category: String
    let customDescription: String?
    let onToggleSelection: () -> Void
    let onCategoryChange: (String) -> Void
    let onDescriptionChange: (String) -> Void

    @State private var showingEditSheet = false

    private var categoryColor: Color {
        CategoryRegistryManager.shared.colorForSubCategory(category)
    }

    private var categoryIcon: String {
        category.categoryIcon
    }

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
                        Image(systemName: categoryIcon)
                            .font(.system(size: 10))

                        Text(category)
                            .font(.system(size: 10, weight: .medium))

                        // Confidence indicator (only if no override)
                        if customDescription == nil,
                           let confidence = transaction.categoryConfidence, confidence > 0.7 {
                            Image(systemName: "sparkles")
                                .font(.system(size: 8))
                        }
                    }
                    .foregroundColor(categoryColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(categoryColor.opacity(0.15))
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
    let selectedCategory: String
    let currentDescription: String
    let onSave: (String, String) -> Void
    let onCancel: () -> Void

    @State private var editedCategory: String
    @State private var editedDescription: String
    @State private var categorySearchQuery: String = ""
    @FocusState private var isDescriptionFocused: Bool

    init(
        transaction: BankTransactionResponse,
        selectedCategory: String,
        currentDescription: String,
        onSave: @escaping (String, String) -> Void,
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

    /// Get all categories grouped by group from the registry
    private var groupedCategories: [(group: String, subCategories: [String])] {
        let registry = CategoryRegistryManager.shared
        guard let hierarchy = registry.hierarchy else {
            // Fallback: just show current category
            return []
        }

        var result: [(group: String, subCategories: [String])] = []
        for group in hierarchy.groups {
            var subs: [String] = []
            for category in group.categories {
                for sub in category.subCategories {
                    if categorySearchQuery.isEmpty || sub.localizedCaseInsensitiveContains(categorySearchQuery) {
                        subs.append(sub)
                    }
                }
            }
            if !subs.isEmpty {
                result.append((group: group.name, subCategories: subs))
            }
        }
        return result
    }

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

            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.4))

                TextField("Search categories...", text: $categorySearchQuery)
                    .font(.system(size: 14))
                    .foregroundColor(.white)

                if !categorySearchQuery.isEmpty {
                    Button {
                        categorySearchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(white: 0.12))
            )

            // Grouped category list
            let groups = groupedCategories
            if groups.isEmpty && !categorySearchQuery.isEmpty {
                Text("No matching categories")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 16) {
                    ForEach(groups, id: \.group) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            // Group header
                            let registry = CategoryRegistryManager.shared
                            HStack(spacing: 6) {
                                Image(systemName: registry.iconForGroup(section.group))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(registry.colorForGroup(section.group))

                                Text(section.group)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white.opacity(0.7))
                            }

                            // Sub-categories in this group
                            FlowLayout(spacing: 8) {
                                ForEach(section.subCategories, id: \.self) { subCategory in
                                    let isSelected = subCategory == editedCategory
                                    let color = registry.colorForGroup(section.group)

                                    Button {
                                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                            editedCategory = subCategory
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: subCategory.categoryIcon)
                                                .font(.system(size: 11))

                                            Text(subCategory)
                                                .font(.system(size: 12, weight: .medium))
                                        }
                                        .foregroundColor(isSelected ? .white : color)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(isSelected ? color : color.opacity(0.15))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(isSelected ? color : Color.clear, lineWidth: 1.5)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
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

// MARK: - Flow Layout (for wrapping category chips)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }

        return (positions, CGSize(width: maxX, height: currentY + lineHeight))
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
                suggestedCategory: "Pantry Staples (Pasta/Rice/Oil)",
                categoryConfidence: 0.85,
                createdAt: nil
            ),
            isSelected: true,
            category: "Pantry Staples (Pasta/Rice/Oil)",
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
                amount: -13.99,
                currency: "EUR",
                creditorName: "Netflix Services",
                debtorName: nil,
                bookingDate: "2026-01-31",
                valueDate: nil,
                description: "Netflix subscription",
                status: .pending,
                importedTransactionId: nil,
                suggestedCategory: "Streaming Video (Netflix/Hulu)",
                categoryConfidence: 0.95,
                createdAt: nil
            ),
            isSelected: false,
            category: "Streaming Video (Netflix/Hulu)",
            customDescription: nil,
            onToggleSelection: {},
            onCategoryChange: { _ in },
            onDescriptionChange: { _ in }
        )
    }
    .padding()
    .background(Color(white: 0.08))
}
