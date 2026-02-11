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
    @Environment(\.dismiss) private var dismiss
    @State private var sortOrder: CategorySortOrder = .worstFirst
    @State private var selectedCategory: CategoryBudgetProgress?
    @State private var showingEditSheet = false

    enum CategorySortOrder: String, CaseIterable {
        case worstFirst = "Needs Attention"
        case bestFirst = "On Track First"
        case highestSpend = "Highest Spend"
        case byGroup = "By Group"
        case alphabetical = "A-Z"
    }

    private var sortedCategories: [CategoryBudgetProgress] {
        switch sortOrder {
        case .worstFirst:
            return progress.categoryProgress.sorted { $0.spendRatio > $1.spendRatio }
        case .bestFirst:
            return progress.categoryProgress.sorted { $0.spendRatio < $1.spendRatio }
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
            let group = registry.groupForSubCategory(cat.category)
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
        progress.categoryProgress.filter { $0.isOverBudget }
    }

    private var warningCategories: [CategoryBudgetProgress] {
        progress.categoryProgress.filter { !$0.isOverBudget && $0.spendRatio > 0.85 }
    }

    private var onTrackCategories: [CategoryBudgetProgress] {
        progress.categoryProgress.filter { $0.spendRatio <= 0.85 }
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
                            Text("Edit")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingEditSheet) {
            EditCategoryBudgetsSheet(initialBudget: progress.budget) { updatedAllocations in
                // Handle save - notify parent to update budget
                // This will be handled by NotificationCenter or callback
                NotificationCenter.default.post(
                    name: .budgetCategoryAllocationsUpdated,
                    object: nil,
                    userInfo: ["allocations": updatedAllocations]
                )
            }
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
                    Text("\(progress.daysRemaining) days left")
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
                label: "Over Budget",
                color: Color(red: 1.0, green: 0.4, blue: 0.4),
                icon: "exclamationmark.triangle.fill"
            )

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 0.5)
                .padding(.vertical, 10)

            statusCard(
                count: warningCategories.count,
                label: "Warning",
                color: Color(red: 1.0, green: 0.75, blue: 0.3),
                icon: "exclamationmark.circle.fill"
            )

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 0.5)
                .padding(.vertical, 10)

            statusCard(
                count: onTrackCategories.count,
                label: "On Track",
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
                            Text(order.rawValue)
                            if sortOrder == order {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(sortOrder.rawValue)
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

                                Text(section.group)
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

                                    CategoryBudgetCard(categoryProgress: category)
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
                            CategoryBudgetCard(categoryProgress: category)
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

    @State private var animationProgress: CGFloat = 0

    private var statusColor: Color {
        if categoryProgress.isOverBudget {
            return Color(red: 1.0, green: 0.4, blue: 0.4)
        } else if categoryProgress.spendRatio > 0.85 {
            return Color(red: 1.0, green: 0.75, blue: 0.3)
        } else if categoryProgress.spendRatio > 0.6 {
            return Color(red: 0.3, green: 0.7, blue: 1.0)
        } else {
            return Color(red: 0.3, green: 0.8, blue: 0.5)
        }
    }

    private var statusText: String {
        if categoryProgress.isOverBudget {
            return "€\(String(format: "%.0f", categoryProgress.overAmount)) over"
        } else if categoryProgress.spendRatio > 0.85 {
            return "Almost at limit"
        } else {
            return "€\(String(format: "%.0f", categoryProgress.remainingAmount)) left"
        }
    }

    private var statusIcon: String {
        if categoryProgress.isOverBudget {
            return "exclamationmark.triangle.fill"
        } else if categoryProgress.spendRatio > 0.85 {
            return "exclamationmark.circle.fill"
        } else {
            return "checkmark.circle.fill"
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
                            statusColor,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 48, height: 48)
                        .rotationEffect(.degrees(-90))

                    // Icon
                    Image(systemName: categoryProgress.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(categoryProgress.category.categoryColor)
                }

                // Category info
                VStack(alignment: .leading, spacing: 4) {
                    Text(categoryProgress.category.normalizedCategoryName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)

                    // Status badge
                    HStack(spacing: 4) {
                        Image(systemName: statusIcon)
                            .font(.system(size: 10, weight: .semibold))
                        Text(statusText)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(statusColor)
                }

                Spacer()

                // Amount display
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "€%.0f", categoryProgress.currentSpend))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(categoryProgress.isOverBudget ? statusColor : .white)

                    Text(String(format: "of €%.0f", categoryProgress.budgetAmount))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
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
                                colors: [statusColor.opacity(0.8), statusColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * min(1.0, CGFloat(categoryProgress.spendRatio)) * animationProgress)

                    // Over budget indicator
                    if categoryProgress.isOverBudget {
                        // Striped pattern for over-budget portion
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [Color.red.opacity(0.6), Color.red.opacity(0.8)],
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
                Text(String(format: "%.0f%% used", categoryProgress.spendRatio * 100))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))

                Spacer()

                if categoryProgress.isLocked {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                        Text("Locked")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.3))
                }
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
                Text("Categories")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))

                Spacer()

                if let onSeeAll = onSeeAll, !categories.isEmpty {
                    Button(action: onSeeAll) {
                        HStack(spacing: 4) {
                            Text(categories.count > 5 ? "See All (\(categories.count))" : "Details")
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
                Text("No category budgets set")
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
                            CompactCategoryBudgetItem(categoryProgress: category)
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

    @State private var animationProgress: CGFloat = 0

    private var statusColor: Color {
        if categoryProgress.isOverBudget {
            return Color(red: 1.0, green: 0.4, blue: 0.4)
        } else if categoryProgress.spendRatio > 0.85 {
            return Color(red: 1.0, green: 0.75, blue: 0.3)
        } else if categoryProgress.spendRatio > 0.6 {
            return Color(red: 0.3, green: 0.7, blue: 1.0)
        } else {
            return Color(red: 0.3, green: 0.8, blue: 0.5)
        }
    }

    private var statusIcon: String {
        if categoryProgress.isOverBudget {
            return "exclamationmark.triangle.fill"
        } else if categoryProgress.spendRatio > 0.85 {
            return "exclamationmark.circle.fill"
        } else {
            return "checkmark.circle.fill"
        }
    }

    private var statusText: String {
        if categoryProgress.isOverBudget {
            return "Over"
        } else if categoryProgress.spendRatio > 0.85 {
            return "Warning"
        } else {
            return "On track"
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
                    .stroke(statusColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))

                Image(systemName: categoryProgress.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(categoryProgress.category.categoryColor)
            }

            // Category name and status
            VStack(alignment: .leading, spacing: 3) {
                Text(categoryProgress.category.normalizedCategoryName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: statusIcon)
                        .font(.system(size: 10, weight: .semibold))
                    Text(statusText)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(statusColor)
            }

            Spacer()

            // Budget amounts - key info users want to see
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Text(String(format: "€%.0f", categoryProgress.currentSpend))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(categoryProgress.isOverBudget ? statusColor : .white)

                    Text("/")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))

                    Text(String(format: "€%.0f", categoryProgress.budgetAmount))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }

                // Remaining or over amount
                Text(categoryProgress.isOverBudget
                     ? String(format: "€%.0f over", categoryProgress.overAmount)
                     : String(format: "€%.0f left", categoryProgress.remainingAmount))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(categoryProgress.isOverBudget ? statusColor : .white.opacity(0.4))
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
        notificationsEnabled: true,
        alertThresholds: [0.5, 0.75, 0.9]
    )

    let sampleProgress = BudgetProgress(
        budget: sampleBudget,
        currentSpend: 723,
        daysElapsed: 21,
        daysInMonth: 31,
        categoryProgress: [
            CategoryBudgetProgress(category: "Fresh Produce", budgetAmount: 100, currentSpend: 65, isLocked: false),
            CategoryBudgetProgress(category: "Meat & Fish", budgetAmount: 150, currentSpend: 168, isLocked: true),
            CategoryBudgetProgress(category: "Snacks & Sweets", budgetAmount: 60, currentSpend: 72, isLocked: false),
            CategoryBudgetProgress(category: "Dairy & Eggs", budgetAmount: 80, currentSpend: 74, isLocked: false),
            CategoryBudgetProgress(category: "Bakery", budgetAmount: 50, currentSpend: 35, isLocked: false),
            CategoryBudgetProgress(category: "Household", budgetAmount: 120, currentSpend: 95, isLocked: false),
            CategoryBudgetProgress(category: "Drinks (Soft/Soda)", budgetAmount: 40, currentSpend: 28, isLocked: false),
            CategoryBudgetProgress(category: "Frozen", budgetAmount: 70, currentSpend: 42, isLocked: false),
        ]
    )

    return CategoryBudgetDetailView(progress: sampleProgress)
}
