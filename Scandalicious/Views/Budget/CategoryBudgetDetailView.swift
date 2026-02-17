//
//  CategoryBudgetDetailView.swift
//  Scandalicious
//
//  Created by Claude on 31/01/2026.
//

import SwiftUI

// MARK: - Category Budget Detail View

/// Full-screen view showing detailed budget breakdown by category
struct CategoryBudgetDetailView: View {
    let progress: BudgetProgress
    var onRemoveCategory: ((String) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var sortOrder: CategorySortOrder = .worstFirst
    @State private var selectedCategory: CategoryBudgetProgress?
    @State private var showingEditSheet = false
    @State private var categoryToRemove: String?

    enum CategorySortOrder: String, CaseIterable {
        case worstFirst = "needs_attention"
        case bestFirst = "on_track_first"
        case highestSpend = "highest_spend"
        case byGroup = "by_group"
        case alphabetical = "a_z"
    }

    private var sortedCategories: [CategoryBudgetProgress] {
        switch sortOrder {
        case .worstFirst:
            return progress.categoryProgress.sorted {
                if $0.spendRatio != $1.spendRatio { return $0.spendRatio > $1.spendRatio }
                return $0.currentSpend > $1.currentSpend
            }
        case .bestFirst:
            return progress.categoryProgress.sorted {
                if $0.spendRatio != $1.spendRatio { return $0.spendRatio < $1.spendRatio }
                return $0.currentSpend < $1.currentSpend
            }
        case .highestSpend:
            return progress.categoryProgress.sorted { $0.currentSpend > $1.currentSpend }
        case .byGroup:
            return progress.categoryProgress.sorted { $0.currentSpend > $1.currentSpend }
        case .alphabetical:
            return progress.categoryProgress.sorted { $0.category < $1.category }
        }
    }

    /// Group categories by their parent group for "By Group" sort mode
    private var groupedCategories: [(group: String, categories: [CategoryBudgetProgress])] {
        let registry = CategoryRegistryManager.shared
        var groups: [String: [CategoryBudgetProgress]] = [:]

        for cat in progress.categoryProgress {
            let group = registry.groupForCategory(cat.category)
            groups[group, default: []].append(cat)
        }

        return groups
            .map { (group: $0.key, categories: $0.value.sorted { $0.currentSpend > $1.currentSpend }) }
            .sorted { group1, group2 in
                let total1 = group1.categories.reduce(0) { $0 + $1.currentSpend }
                let total2 = group2.categories.reduce(0) { $0 + $1.currentSpend }
                return total1 > total2
            }
    }

    private var overBudgetCategories: [CategoryBudgetProgress] {
        progress.categoryProgress.filter { $0.isOverBudget || $0.displayedPercent >= 100 }
    }

    private var warningCategories: [CategoryBudgetProgress] {
        progress.categoryProgress.filter { $0.isWarning }
    }

    private var onTrackCategories: [CategoryBudgetProgress] {
        progress.categoryProgress.filter { !$0.isOverBudget && !$0.isWarning && $0.displayedPercent < 100 }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(white: 0.05).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Summary header
                        summaryHeader

                        // Quick status overview
                        statusOverview

                        // Sort picker
                        sortPicker

                        // Category list
                        categoryList
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingEditSheet = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 14, weight: .semibold))
                            Text(L("edit"))
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("done")) { dismiss() }
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingEditSheet) {
            EditCategoryBudgetsSheet(initialBudget: progress.budget) { updatedAllocations in
                NotificationCenter.default.post(
                    name: .budgetCategoryAllocationsUpdated,
                    object: nil,
                    userInfo: ["allocations": updatedAllocations]
                )
            }
        }
        .confirmationDialog(
            "Remove \(categoryToRemove.map { CategoryRegistryManager.shared.displayNameForCategory($0) } ?? "") target?",
            isPresented: Binding(
                get: { categoryToRemove != nil },
                set: { if !$0 { categoryToRemove = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(L("remove_target"), role: .destructive) {
                if let category = categoryToRemove {
                    onRemoveCategory?(category)
                    categoryToRemove = nil
                }
            }
            Button(L("cancel"), role: .cancel) { categoryToRemove = nil }
        } message: {
            Text(L("remove_category_confirm"))
        }
    }

    // MARK: - Summary Header

    private var summaryHeader: some View {
        VStack(spacing: 16) {
            // Main budget ring (smaller)
            BudgetRingView(progress: progress, size: 100, showDetails: false)

            VStack(spacing: 4) {
                Text(String(format: "€%.0f of €%.0f", progress.currentSpend, progress.budget.monthlyAmount))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                HStack(spacing: 6) {
                    Image(systemName: progress.paceStatus.icon)
                        .font(.system(size: 12, weight: .semibold))
                    Text(progress.paceStatus.displayText)
                        .font(.system(size: 13, weight: .semibold))
                    Text("•")
                        .foregroundColor(.white.opacity(0.3))
                    Text("\(progress.daysRemaining) \(L("days_left"))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
                .foregroundColor(progress.paceStatus.color)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Status Overview

    private var statusOverview: some View {
        HStack(spacing: 0) {
            statusCard(
                count: overBudgetCategories.count,
                label: L("over_budget"),
                color: Color(red: 1.0, green: 0.4, blue: 0.4),
                icon: "exclamationmark.triangle.fill"
            )

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 0.5)
                .padding(.vertical, 10)

            statusCard(
                count: warningCategories.count,
                label: L("warning"),
                color: Color(red: 1.0, green: 0.75, blue: 0.3),
                icon: "exclamationmark.circle.fill"
            )

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 0.5)
                .padding(.vertical, 10)

            statusCard(
                count: onTrackCategories.count,
                label: L("on_track"),
                color: Color(red: 0.3, green: 0.8, blue: 0.5),
                icon: "checkmark.circle.fill"
            )
        }
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(white: 0.08))
                .overlay(
                    LinearGradient(
                        colors: [Color.white.opacity(0.05), Color.white.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }

    private func statusCard(count: Int, label: String, color: Color, icon: String) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text("\(count)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            }
            .foregroundColor(color)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: - Sort Picker

    private var sortPicker: some View {
        HStack {
            Text("Sort by")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.5))

            Spacer()

            Menu {
                ForEach(CategorySortOrder.allCases, id: \.self) { order in
                    Button(action: { sortOrder = order }) {
                        HStack {
                            Text(L(order.rawValue))
                            if sortOrder == order {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(L(sortOrder.rawValue))
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Category List

    private var premiumCardBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color(white: 0.08))
            .overlay(
                LinearGradient(
                    colors: [Color.white.opacity(0.05), Color.white.opacity(0.02)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var premiumCardBorder: some View {
        RoundedRectangle(cornerRadius: 20)
            .stroke(
                LinearGradient(
                    colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.5
            )
    }

    private var categoryList: some View {
        Group {
            if sortOrder == .byGroup {
                // Grouped view with section headers
                VStack(spacing: 16) {
                    ForEach(groupedCategories, id: \.group) { section in
                        VStack(spacing: 0) {
                            // Group header
                            let registry = CategoryRegistryManager.shared
                            let groupSpent = section.categories.reduce(0) { $0 + $1.currentSpend }
                            let groupBudget = section.categories.reduce(0) { $0 + $1.budgetAmount }

                            HStack(spacing: 8) {
                                Image(systemName: registry.iconForGroup(section.group))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(registry.colorForGroup(section.group))

                                Text(registry.localizedGroupName(section.group))
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)

                                Text("(\(section.categories.count))")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white.opacity(0.4))

                                Spacer()

                                VStack(alignment: .trailing, spacing: 1) {
                                    Text(String(format: "€%.0f / €%.0f", groupSpent, groupBudget))
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundColor(groupSpent > groupBudget ? Color(red: 1.0, green: 0.4, blue: 0.4) : .white.opacity(0.7))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)

                            // Category items for this group with dividers
                            ForEach(Array(section.categories.enumerated()), id: \.element.id) { index, category in
                                VStack(spacing: 0) {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.06))
                                        .frame(height: 0.5)
                                        .padding(.leading, 52)

                                    CategoryBudgetCard(
                                        categoryProgress: category,
                                        onRemove: onRemoveCategory != nil ? { categoryToRemove = category.category } : nil
                                    )
                                }
                            }
                        }
                        .background(premiumCardBackground)
                        .overlay(premiumCardBorder)
                    }
                }
            } else {
                // Flat sorted view in premium glass card
                VStack(spacing: 0) {
                    ForEach(Array(sortedCategories.enumerated()), id: \.element.id) { index, category in
                        VStack(spacing: 0) {
                            if index > 0 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.06))
                                    .frame(height: 0.5)
                                    .padding(.leading, 52)
                            }
                            CategoryBudgetCard(
                                categoryProgress: category,
                                onRemove: onRemoveCategory != nil ? { categoryToRemove = category.category } : nil
                            )
                        }
                    }
                }
                .background(premiumCardBackground)
                .overlay(premiumCardBorder)
            }
        }
    }
}

// MARK: - Category Budget Card

/// A detailed card showing budget progress for a single category
struct CategoryBudgetCard: View {
    let categoryProgress: CategoryBudgetProgress
    var onRemove: (() -> Void)?

    @State private var animationProgress: CGFloat = 0

    // MARK: - Color Constants

    private static let greenColor = Color(red: 0.3, green: 0.8, blue: 0.5)
    private static let orangeColor = Color(red: 1.0, green: 0.75, blue: 0.3)
    private static let redColor = Color(red: 1.0, green: 0.4, blue: 0.4)

    private var displayedPercent: Int { categoryProgress.displayedPercent }

    private var barColor: Color {
        if categoryProgress.isOverBudget || displayedPercent >= 100 {
            return Self.redColor
        } else if categoryProgress.isWarning {
            return Self.orangeColor
        } else {
            return Self.greenColor
        }
    }

    private var statusText: String {
        if categoryProgress.isOverBudget || displayedPercent >= 100 {
            return "€\(String(format: "%.0f", categoryProgress.overAmount)) \(L("over"))"
        } else if categoryProgress.isWarning {
            return L("almost_at_limit")
        } else {
            return "€\(String(format: "%.0f", categoryProgress.remainingAmount)) \(L("left_to_spend"))"
        }
    }

    private var statusIcon: String {
        if categoryProgress.isOverBudget || displayedPercent >= 100 {
            return "exclamationmark.triangle.fill"
        } else if categoryProgress.isWarning {
            return "exclamationmark.circle.fill"
        } else {
            return "checkmark.circle.fill"
        }
    }

    private var spendAmountColor: Color {
        if categoryProgress.isOverBudget || displayedPercent >= 100 {
            return Self.redColor
        } else if categoryProgress.isWarning {
            return Self.orangeColor
        } else {
            return .white
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header row
            HStack(spacing: 12) {
                // Category icon with ring
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 4)
                        .frame(width: 48, height: 48)

                    // Progress ring
                    Circle()
                        .trim(from: 0, to: min(1.0, CGFloat(categoryProgress.spendRatio)) * animationProgress)
                        .stroke(
                            barColor,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 48, height: 48)
                        .rotationEffect(.degrees(-90))

                    // Icon
                    Image.categorySymbol(categoryProgress.icon)
                        .frame(width: 18, height: 18)
                        .foregroundStyle(categoryProgress.category.categoryColor)
                }

                // Category info
                VStack(alignment: .leading, spacing: 4) {
                    Text(CategoryRegistryManager.shared.displayNameForCategory(categoryProgress.category))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)

                    // Status badge
                    HStack(spacing: 4) {
                        Image(systemName: statusIcon)
                            .font(.system(size: 10, weight: .semibold))
                        Text(statusText)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(barColor)
                }

                Spacer()

                // Amount display
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "€%.0f", categoryProgress.currentSpend))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(spendAmountColor)

                    Text(String(format: "of €%.0f", categoryProgress.budgetAmount))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }

                // Remove button
                if let onRemove {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.15))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))

                    // Fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [barColor.opacity(0.8), barColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * min(1.0, CGFloat(categoryProgress.spendRatio)) * animationProgress)

                    // Over budget indicator
                    if categoryProgress.isOverBudget {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [Self.redColor.opacity(0.6), Self.redColor.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * min(0.3, CGFloat(categoryProgress.spendRatio - 1.0)) * animationProgress)
                            .offset(x: geometry.size.width)
                    }

                    // Budget limit marker
                    if categoryProgress.spendRatio < 1.0 {
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 2, height: 12)
                            .offset(x: geometry.size.width - 1, y: -2)
                    }
                }
            }
            .frame(height: 8)

            // Percentage indicator
            HStack {
                if categoryProgress.isWarning {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9, weight: .semibold))
                        Text("\(displayedPercent)% \(L("used"))")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(Self.orangeColor)
                } else if categoryProgress.isOverBudget || displayedPercent >= 100 {
                    Text("\(displayedPercent)% \(L("used"))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Self.redColor)
                } else {
                    Text("\(displayedPercent)% \(L("used"))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }

                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                animationProgress = 1.0
            }
        }
    }
}

// MARK: - Compact Category Budget Grid

/// A compact grid of category budgets for inline display - shows ALL categories
struct CategoryBudgetGrid: View {
    let categories: [CategoryBudgetProgress]
    var onSeeAll: (() -> Void)?
    var onRemoveCategory: ((String) -> Void)?

    /// Show top categories sorted by spend amount (highest first)
    private var displayCategories: [CategoryBudgetProgress] {
        categories
            .sorted { $0.currentSpend > $1.currentSpend }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                Text(L("category_budgets"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))

                Spacer()

                if let onSeeAll = onSeeAll, !categories.isEmpty {
                    Button(action: onSeeAll) {
                        HStack(spacing: 4) {
                            Text(categories.count > 5 ? "\(L("see_all")) (\(categories.count))" : L("see_all"))
                                .font(.system(size: 12, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(.white.opacity(0.35))
                    }
                }
            }

            // List of category items with budget amounts
            if displayCategories.isEmpty {
                Text(L("no_budget_data"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(displayCategories.enumerated()), id: \.element.id) { index, category in
                        VStack(spacing: 0) {
                            if index > 0 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.06))
                                    .frame(height: 0.5)
                                    .padding(.leading, 52)
                            }
                            CompactCategoryBudgetItem(
                                categoryProgress: category,
                                onRemove: onRemoveCategory != nil ? { onRemoveCategory?(category.category) } : nil
                            )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Compact Category Budget Item

/// A row display of a category budget showing spent vs budget amounts
struct CompactCategoryBudgetItem: View {
    let categoryProgress: CategoryBudgetProgress
    var onRemove: (() -> Void)?

    @State private var animationProgress: CGFloat = 0

    private static let greenColor = Color(red: 0.3, green: 0.8, blue: 0.5)
    private static let orangeColor = Color(red: 1.0, green: 0.75, blue: 0.3)
    private static let redColor = Color(red: 1.0, green: 0.4, blue: 0.4)

    private var displayedPercent: Int { categoryProgress.displayedPercent }

    private var barColor: Color {
        if categoryProgress.isOverBudget || displayedPercent >= 100 {
            return Self.redColor
        } else if categoryProgress.isWarning {
            return Self.orangeColor
        } else {
            return Self.greenColor
        }
    }

    private var statusIcon: String {
        if categoryProgress.isOverBudget || displayedPercent >= 100 {
            return "exclamationmark.triangle.fill"
        } else if categoryProgress.isWarning {
            return "exclamationmark.circle.fill"
        } else {
            return "checkmark.circle.fill"
        }
    }

    private var statusText: String {
        if categoryProgress.isOverBudget || displayedPercent >= 100 {
            return L("over")
        } else if categoryProgress.isWarning {
            return L("warning")
        } else {
            return L("on_track")
        }
    }

    private var spendAmountColor: Color {
        if categoryProgress.isOverBudget || displayedPercent >= 100 {
            return Self.redColor
        } else if categoryProgress.isWarning {
            return Self.orangeColor
        } else {
            return .white
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Category icon with mini ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 3)
                    .frame(width: 40, height: 40)

                Circle()
                    .trim(from: 0, to: min(1.0, CGFloat(categoryProgress.spendRatio)) * animationProgress)
                    .stroke(barColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))

                Image.categorySymbol(categoryProgress.icon)
                    .frame(width: 14, height: 14)
                    .foregroundStyle(categoryProgress.category.categoryColor)
            }

            // Category name and status
            VStack(alignment: .leading, spacing: 3) {
                Text(CategoryRegistryManager.shared.displayNameForCategory(categoryProgress.category))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: statusIcon)
                        .font(.system(size: 10, weight: .semibold))
                    Text(statusText)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(barColor)
            }

            Spacer()

            // Budget amounts
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Text(String(format: "€%.0f", categoryProgress.currentSpend))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(spendAmountColor)

                    Text("/")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))

                    Text(String(format: "€%.0f", categoryProgress.budgetAmount))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }

                // Remaining or over amount
                Text(categoryProgress.isOverBudget
                     ? String(format: "€%.0f \(L("over"))", categoryProgress.overAmount)
                     : String(format: "€%.0f \(L("left_to_spend"))", categoryProgress.remainingAmount))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(categoryProgress.isOverBudget ? Self.redColor : .white.opacity(0.4))
            }

            // Remove button
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.15))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 10)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animationProgress = 1.0
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleBudget = UserBudget(
        id: "1",
        userId: "user1",
        monthlyAmount: 850,
        categoryAllocations: nil,
        isSmartBudget: true,
        createdAt: "2026-01-01T00:00:00Z",
        updatedAt: "2026-01-01T00:00:00Z"
    )

    let sampleProgress = BudgetProgress(
        budget: sampleBudget,
        currentSpend: 723,
        daysElapsed: 21,
        daysInMonth: 31,
        categoryProgress: [
            CategoryBudgetProgress(category: "Fresh Produce", budgetAmount: 100, currentSpend: 65),
            CategoryBudgetProgress(category: "Meat & Fish", budgetAmount: 150, currentSpend: 168),
            CategoryBudgetProgress(category: "Snacks & Sweets", budgetAmount: 60, currentSpend: 72),
            CategoryBudgetProgress(category: "Dairy & Eggs", budgetAmount: 80, currentSpend: 74),
            CategoryBudgetProgress(category: "Bakery", budgetAmount: 50, currentSpend: 35),
            CategoryBudgetProgress(category: "Household", budgetAmount: 120, currentSpend: 95),
            CategoryBudgetProgress(category: "Drinks (Soft/Soda)", budgetAmount: 40, currentSpend: 28),
            CategoryBudgetProgress(category: "Frozen", budgetAmount: 70, currentSpend: 42),
        ]
    )

    return CategoryBudgetDetailView(progress: sampleProgress)
}
