//
//  BudgetActivityRingView.swift
//  Scandalicious
//
//  Activity ring showing budget progress for a single category
//  Uses green-to-red gradient based on budget usage
//

import SwiftUI

// MARK: - Budget Activity Ring View

/// A single activity ring showing budget progress for a category
/// Color transitions from green (on track) to red (over budget) based on fill percentage
struct BudgetActivityRingView: View {
    let item: BudgetProgressItem
    var size: CGFloat = 80

    @State private var animationProgress: CGFloat = 0

    // Ring styling
    private let lineWidthRatio: CGFloat = 0.12

    private var lineWidth: CGFloat {
        size * lineWidthRatio
    }

    private var fillProgress: CGFloat {
        CGFloat(item.clampedProgress) * animationProgress
    }

    /// Color based on budget usage - green to red gradient
    private var ringColor: Color {
        let ratio = item.progressRatio

        if ratio <= 0.5 {
            // 0-50%: Sleek green
            return Color(red: 0.2, green: 0.8, blue: 0.4)
        } else if ratio <= 0.7 {
            // 50-70%: Green transitioning to yellow-green
            let t = (ratio - 0.5) / 0.2
            return Color(
                red: 0.2 + 0.6 * t,
                green: 0.8,
                blue: 0.4 - 0.2 * t
            )
        } else if ratio <= 0.85 {
            // 70-85%: Yellow to orange
            let t = (ratio - 0.7) / 0.15
            return Color(
                red: 0.8 + 0.15 * t,
                green: 0.8 - 0.3 * t,
                blue: 0.2 - 0.1 * t
            )
        } else if ratio <= 1.0 {
            // 85-100%: Orange to red
            let t = (ratio - 0.85) / 0.15
            return Color(
                red: 0.95 + 0.05 * t,
                green: 0.5 - 0.2 * t,
                blue: 0.1
            )
        } else {
            // Over 100%: Deep red
            return Color(red: 1.0, green: 0.3, blue: 0.3)
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            // Ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: lineWidth)
                    .frame(width: size, height: size)

                // Progress ring with gradient color
                Circle()
                    .trim(from: 0, to: fillProgress)
                    .stroke(
                        ringColor,
                        style: StrokeStyle(
                            lineWidth: lineWidth,
                            lineCap: .round
                        )
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(-90))

                // Center content - icon
                Image(systemName: item.icon)
                    .font(.system(size: size * 0.28, weight: .semibold))
                    .foregroundStyle(ringColor)
            }

            // Category name
            Text(item.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: size + 10)

            // Status text
            Text(item.compactStatusText)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(ringColor)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                animationProgress = 1.0
            }
        }
        .onChange(of: item.spentAmount) { _, _ in
            animationProgress = 0
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animationProgress = 1.0
            }
        }
    }
}

// MARK: - Budget Activity Rings Grid

/// Grid layout showing budget activity rings grouped by spending category group
struct BudgetActivityRingsGrid: View {
    let items: [BudgetProgressItem]
    var ringSize: CGFloat = 80
    var columns: Int = 3

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 16), count: columns)
    }

    /// Group items by their category group using CategoryRegistryManager
    private var groupedItems: [(group: String, items: [BudgetProgressItem])] {
        let registry = CategoryRegistryManager.shared
        var groups: [String: [BudgetProgressItem]] = [:]

        for item in items {
            let group = registry.groupForSubCategory(item.name)
            groups[group, default: []].append(item)
        }

        // Sort groups by total spend (highest first), only include non-empty
        return groups
            .map { (group: $0.key, items: $0.value) }
            .sorted { group1, group2 in
                let total1 = group1.items.reduce(0) { $0 + $1.spentAmount }
                let total2 = group2.items.reduce(0) { $0 + $1.spentAmount }
                return total1 > total2
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))

                Text("Budget by Category")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()
            }
            .padding(.horizontal, 4)

            // Grouped rings
            if items.isEmpty {
                emptyState
            } else {
                let grouped = groupedItems
                if grouped.count == 1 {
                    // Single group — no need for section headers
                    LazyVGrid(columns: gridColumns, spacing: 20) {
                        ForEach(grouped[0].items) { item in
                            BudgetActivityRingView(item: item, size: ringSize)
                        }
                    }
                } else {
                    // Multiple groups — show section headers
                    VStack(spacing: 20) {
                        ForEach(grouped, id: \.group) { section in
                            VStack(alignment: .leading, spacing: 12) {
                                // Group header
                                HStack(spacing: 8) {
                                    let registry = CategoryRegistryManager.shared
                                    Image(systemName: registry.iconForGroup(section.group))
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(registry.colorForGroup(section.group))

                                    Text(section.group)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.7))

                                    Spacer()

                                    let groupTotal = section.items.reduce(0) { $0 + $1.spentAmount }
                                    Text(String(format: "€%.0f", groupTotal))
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                .padding(.horizontal, 4)

                                // Rings for this group
                                LazyVGrid(columns: gridColumns, spacing: 20) {
                                    ForEach(section.items) { item in
                                        BudgetActivityRingView(item: item, size: ringSize)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
        )
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.3))

            Text("No budget data")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

// MARK: - Compact Activity Ring

/// A smaller activity ring for inline use (e.g., in lists)
struct CompactActivityRing: View {
    let item: BudgetProgressItem
    var size: CGFloat = 44

    @State private var animationProgress: CGFloat = 0

    private let lineWidthRatio: CGFloat = 0.15

    private var lineWidth: CGFloat {
        size * lineWidthRatio
    }

    /// Color based on budget usage - green to red gradient
    private var ringColor: Color {
        let ratio = item.progressRatio

        if ratio <= 0.5 {
            return Color(red: 0.2, green: 0.8, blue: 0.4)
        } else if ratio <= 0.7 {
            let t = (ratio - 0.5) / 0.2
            return Color(red: 0.2 + 0.6 * t, green: 0.8, blue: 0.4 - 0.2 * t)
        } else if ratio <= 0.85 {
            let t = (ratio - 0.7) / 0.15
            return Color(red: 0.8 + 0.15 * t, green: 0.8 - 0.3 * t, blue: 0.2 - 0.1 * t)
        } else if ratio <= 1.0 {
            let t = (ratio - 0.85) / 0.15
            return Color(red: 0.95 + 0.05 * t, green: 0.5 - 0.2 * t, blue: 0.1)
        } else {
            return Color(red: 1.0, green: 0.3, blue: 0.3)
        }
    }

    var body: some View {
        ZStack {
            // Background
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: lineWidth)
                .frame(width: size, height: size)

            // Progress
            Circle()
                .trim(from: 0, to: CGFloat(item.clampedProgress) * animationProgress)
                .stroke(
                    ringColor,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))

            // Percentage or icon
            if size > 36 {
                Text(String(format: "%.0f", item.clampedProgress * 100))
                    .font(.system(size: size * 0.26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            } else {
                Image(systemName: item.icon)
                    .font(.system(size: size * 0.35))
                    .foregroundStyle(ringColor)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animationProgress = 1.0
            }
        }
    }
}

// MARK: - Preview

#Preview("Activity Rings Grid") {
    let sampleItems: [BudgetProgressItem] = [
        BudgetProgressItem(
            categoryId: "FRESH_PRODUCE",
            name: "Fresh Produce",
            limitAmount: 100,
            spentAmount: 35,
            isOverBudget: false,
            overBudgetAmount: nil
        ),
        BudgetProgressItem(
            categoryId: "MEAT_FISH",
            name: "Meat & Fish",
            limitAmount: 150,
            spentAmount: 90,
            isOverBudget: false,
            overBudgetAmount: nil
        ),
        BudgetProgressItem(
            categoryId: "SNACKS_SWEETS",
            name: "Snacks & Sweets",
            limitAmount: 50,
            spentAmount: 72,
            isOverBudget: true,
            overBudgetAmount: 22
        ),
        BudgetProgressItem(
            categoryId: "DAIRY_EGGS",
            name: "Dairy & Eggs",
            limitAmount: 80,
            spentAmount: 65,
            isOverBudget: false,
            overBudgetAmount: nil
        ),
        BudgetProgressItem(
            categoryId: "ALCOHOL",
            name: "Alcohol",
            limitAmount: 60,
            spentAmount: 85,
            isOverBudget: true,
            overBudgetAmount: 25
        ),
        BudgetProgressItem(
            categoryId: "BAKERY",
            name: "Bakery",
            limitAmount: 40,
            spentAmount: 28,
            isOverBudget: false,
            overBudgetAmount: nil
        )
    ]

    return ZStack {
        Color(white: 0.05).ignoresSafeArea()

        ScrollView {
            VStack(spacing: 24) {
                BudgetActivityRingsGrid(items: sampleItems)
                    .padding(.horizontal, 16)

                // Individual rings
                Text("Individual Rings")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 24) {
                    BudgetActivityRingView(
                        item: sampleItems[0],
                        size: 80
                    )

                    BudgetActivityRingView(
                        item: sampleItems[2],
                        size: 80
                    )
                }

                // Compact rings
                Text("Compact Rings")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 12) {
                    ForEach(sampleItems.prefix(4)) { item in
                        CompactActivityRing(item: item, size: 44)
                    }
                }
            }
            .padding()
        }
    }
    .preferredColorScheme(.dark)
}
