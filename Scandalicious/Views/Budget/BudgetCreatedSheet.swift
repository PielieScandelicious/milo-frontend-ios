//
//  BudgetCreatedSheet.swift
//  Scandalicious
//
//  Created by Claude on 31/01/2026.
//

import SwiftUI

// MARK: - Budget Created Success Sheet

struct BudgetCreatedSheet: View {
    let budgetAmount: Double
    let monthlySavings: Double
    let categoryAllocations: [CategoryAllocation]
    let onDismiss: () -> Void

    @State private var showContent = false
    @State private var showCategories = false
    @State private var ringProgress: CGFloat = 0
    @State private var checkmarkScale: CGFloat = 0
    @State private var categoryListExpanded = false

    private var savingsPercentage: Double {
        guard budgetAmount > 0 else { return 0 }
        let average = budgetAmount + monthlySavings
        return (monthlySavings / average) * 100
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.06, blue: 0.14),
                    Color(red: 0.05, green: 0.03, blue: 0.10)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Animated background particles
            GeometryReader { geometry in
                ForEach(0..<20, id: \.self) { index in
                    Circle()
                        .fill(Color(red: 0.6, green: 0.4, blue: 1.0).opacity(0.1))
                        .frame(width: CGFloat.random(in: 4...12))
                        .position(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: CGFloat.random(in: 0...geometry.size.height)
                        )
                        .blur(radius: 2)
                }
            }

            ScrollView {
                VStack(spacing: 32) {
                    Spacer().frame(height: 40)

                    // Success Animation
                    successAnimation
                        .opacity(showContent ? 1 : 0)
                        .scaleEffect(showContent ? 1 : 0.8)

                    // Budget Amount Display
                    budgetAmountSection
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)

                    // Savings Badge
                    if monthlySavings > 0 {
                        savingsBadge
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 20)
                    }

                    // Category Allocations
                    if !categoryAllocations.isEmpty {
                        categorySection
                            .opacity(showCategories ? 1 : 0)
                            .offset(y: showCategories ? 0 : 30)
                    }

                    Spacer().frame(height: 20)

                    // Continue Button
                    continueButton
                        .opacity(showCategories ? 1 : 0)
                        .offset(y: showCategories ? 0 : 20)

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 24)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                showContent = true
            }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3)) {
                ringProgress = 1.0
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.6)) {
                checkmarkScale = 1.0
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.8)) {
                showCategories = true
            }
        }
    }

    // MARK: - Success Animation

    private var successAnimation: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.3, green: 0.8, blue: 0.5).opacity(0.3),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 40,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)

            // Background ring
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 6)
                .frame(width: 100, height: 100)

            // Animated progress ring
            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.3, green: 0.8, blue: 0.5),
                            Color(red: 0.2, green: 0.9, blue: 0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(-90))

            // Checkmark
            Image(systemName: "checkmark")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(Color(red: 0.3, green: 0.8, blue: 0.5))
                .scaleEffect(checkmarkScale)
        }
    }

    // MARK: - Budget Amount Section

    private var budgetAmountSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 1.0))

                Text("Smart Budget Created!")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            }

            Text(String(format: "€%.0f", budgetAmount))
                .font(.system(size: 56, weight: .bold, design: .rounded))
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

            Text("per month")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    // MARK: - Savings Badge

    private var savingsBadge: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.3, green: 0.8, blue: 0.5).opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: "leaf.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(red: 0.3, green: 0.8, blue: 0.5))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Monthly Savings Target")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))

                HStack(spacing: 6) {
                    Text(String(format: "€%.0f", monthlySavings))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.3, green: 0.8, blue: 0.5))

                    Text(String(format: "(%.0f%%)", savingsPercentage))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(red: 0.3, green: 0.8, blue: 0.5).opacity(0.7))
                }
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.3, green: 0.8, blue: 0.5).opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(red: 0.3, green: 0.8, blue: 0.5).opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Category Section

    private var categorySection: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 1.0))

                    Text("Milo's Category Budgets")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }

                Spacer()

                Text("\(categoryAllocations.count) categories")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }

            // Category list
            VStack(spacing: 8) {
                ForEach(Array((categoryListExpanded ? categoryAllocations : Array(categoryAllocations.prefix(6))).enumerated()), id: \.element.category) { index, allocation in
                    categoryRow(allocation, index: index)
                }

                // Expandable button
                if categoryAllocations.count > 6 {
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            categoryListExpanded.toggle()
                        }
                    }) {
                        HStack(spacing: 6) {
                            if !categoryListExpanded {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Show \(categoryAllocations.count - 6) more categories")
                                    .font(.system(size: 14, weight: .semibold))
                            } else {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Show less")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 1.0))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.03))
                        )
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.6, green: 0.4, blue: 1.0).opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(red: 0.6, green: 0.4, blue: 1.0).opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func categoryRow(_ allocation: CategoryAllocation, index: Int) -> some View {
        let percentage = budgetAmount > 0 ? (allocation.amount / budgetAmount) * 100 : 0

        return HStack(spacing: 12) {
            // Category icon
            ZStack {
                Circle()
                    .fill(allocation.category.categoryColor.opacity(0.2))
                    .frame(width: 36, height: 36)

                Image(systemName: categoryIcon(for: allocation.category))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(allocation.category.categoryColor)
            }

            // Name
            Text(allocation.category)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()

            // Percentage
            Text(String(format: "%.0f%%", percentage))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.4))

            // Amount
            Text(String(format: "€%.0f", allocation.amount))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 55, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
        )
        .opacity(showCategories ? 1 : 0)
        .offset(x: showCategories ? 0 : 20)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.05 + 0.9), value: showCategories)
    }

    // MARK: - Continue Button

    private var continueButton: some View {
        Button(action: onDismiss) {
            HStack(spacing: 10) {
                Text("Start Tracking")
                    .font(.system(size: 17, weight: .bold))

                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .bold))
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
    }

    // MARK: - Helper Functions

    private func categoryIcon(for category: String) -> String {
        let lowercased = category.lowercased()
        if lowercased.contains("produce") || lowercased.contains("vegetable") || lowercased.contains("fruit") {
            return "leaf.fill"
        } else if lowercased.contains("meat") || lowercased.contains("fish") || lowercased.contains("protein") {
            return "fish.fill"
        } else if lowercased.contains("dairy") || lowercased.contains("milk") {
            return "drop.fill"
        } else if lowercased.contains("snack") || lowercased.contains("sweet") || lowercased.contains("candy") {
            return "birthday.cake.fill"
        } else if lowercased.contains("beverage") || lowercased.contains("drink") || lowercased.contains("alcohol") {
            return "cup.and.saucer.fill"
        } else if lowercased.contains("bakery") || lowercased.contains("bread") {
            return "storefront.fill"
        } else if lowercased.contains("frozen") {
            return "snowflake"
        } else if lowercased.contains("household") || lowercased.contains("cleaning") {
            return "house.fill"
        } else {
            return "cart.fill"
        }
    }
}

// MARK: - Preview

#Preview {
    BudgetCreatedSheet(
        budgetAmount: 900,
        monthlySavings: 150,
        categoryAllocations: [
            CategoryAllocation(category: "Meat & Fish", amount: 450, isLocked: false),
            CategoryAllocation(category: "Alcohol", amount: 200, isLocked: false),
            CategoryAllocation(category: "Fresh Produce", amount: 160, isLocked: false),
            CategoryAllocation(category: "Dairy & Eggs", amount: 90, isLocked: false)
        ],
        onDismiss: {}
    )
}
