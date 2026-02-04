//
//  BudgetSetupView.swift
//  Scandalicious
//
//  Created by Claude on 31/01/2026.
//

import SwiftUI

// MARK: - Budget Setup View

/// Smart budget setup with AI-powered category allocations
struct BudgetSetupView: View {
    @ObservedObject var viewModel: BudgetViewModel
    @Environment(\.dismiss) private var dismiss

    // Budget selection state
    @State private var selectionMode: SelectionMode = .percentage
    @State private var selectedPercentage: SavingsPercentage = .ten
    @State private var customAmount: Double = 500
    @State private var showSuccessSheet = false
    @State private var showAllCategories = false
    @State private var expandedOpportunityIds = Set<String>()

    // Category editing state
    @State private var showCategoryEditor = false
    @State private var editableCategoryAllocations: [EditableCategoryAllocation] = []
    @State private var hasCustomizedCategories = false
    @State private var categoryListExpanded = false

    // Callback to switch to scan tab
    var onScanReceipt: (() -> Void)?

    enum SelectionMode {
        case percentage
        case custom
    }

    enum SavingsPercentage: CaseIterable, Identifiable {
        case five, ten, fifteen, twenty, twentyFive

        var id: Int { value }

        var value: Int {
            switch self {
            case .five: return 5
            case .ten: return 10
            case .fifteen: return 15
            case .twenty: return 20
            case .twentyFive: return 25
            }
        }

        var label: String { "\(value)%" }
    }

    // Computed properties

    private var navigationTitle: String {
        guard let suggestion = viewModel.aiSuggestionState.data else {
            return "Smart Budget"
        }
        return suggestion.dataCollectionPhase.title
    }

    private var averageSpending: Double {
        viewModel.aiSuggestionState.data?.rawData.monthlyAverage ?? 500
    }

    private var targetBudget: Double {
        switch selectionMode {
        case .percentage:
            let savings = averageSpending * Double(selectedPercentage.value) / 100
            return max(100, averageSpending - savings)
        case .custom:
            return customAmount
        }
    }

    private var savingsAmount: Double {
        max(0, averageSpending - targetBudget)
    }

    private var savingsPercentageValue: Double {
        guard averageSpending > 0 else { return 0 }
        return (savingsAmount / averageSpending) * 100
    }

    /// Scale AI category allocations to match the target budget
    /// If categories have been customized, return those instead
    private var scaledCategoryAllocations: [CategoryAllocation] {
        // If user has customized categories, use those
        if hasCustomizedCategories && !editableCategoryAllocations.isEmpty {
            return editableCategoryAllocations.map { editable in
                CategoryAllocation(
                    category: editable.category,
                    amount: editable.amount,
                    isLocked: editable.isLocked
                )
            }
        }

        // Otherwise, scale AI suggestions
        guard let aiSuggestion = viewModel.aiSuggestionState.data else { return [] }

        let originalTotal = aiSuggestion.categoryAllocations.reduce(0) { $0 + $1.suggestedAmount }
        guard originalTotal > 0 else { return [] }

        let scaleFactor = targetBudget / originalTotal

        return aiSuggestion.categoryAllocations.map { allocation in
            CategoryAllocation(
                category: allocation.category,
                amount: allocation.suggestedAmount * scaleFactor,
                isLocked: false
            )
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(white: 0.08),
                        Color(red: 0.08, green: 0.06, blue: 0.12)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                if viewModel.aiSuggestionState.isLoading {
                    loadingView
                } else if let suggestion = viewModel.aiSuggestionState.data {
                    // Show different UI based on data collection phase
                    switch suggestion.dataCollectionPhase {
                    case .onboarding:
                        onboardingContent(suggestion)
                    case .buildingProfile:
                        buildingProfileContent(suggestion)
                    case .fullyPersonalized:
                        mainContent
                    }
                } else if let error = viewModel.aiSuggestionState.errorMessage {
                    errorView(error)
                } else {
                    loadingView
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if viewModel.aiSuggestionState.data == nil {
                Task {
                    await viewModel.loadAISuggestion()
                    // Set default custom amount to -10% after data loads
                    if customAmount == 500 && averageSpending > 0 {
                        customAmount = averageSpending * 0.9
                    }
                }
            } else {
                // Data already loaded, set default if needed
                if customAmount == 500 && averageSpending > 0 {
                    customAmount = averageSpending * 0.9
                }
            }
        }
        .fullScreenCover(isPresented: $showSuccessSheet) {
            BudgetCreatedSheet(
                budgetAmount: targetBudget,
                monthlySavings: savingsAmount,
                categoryAllocations: scaledCategoryAllocations,
                onDismiss: {
                    showSuccessSheet = false
                    dismiss()
                }
            )
        }
        .sheet(isPresented: $showAllCategories) {
            AllCategoriesSheet(
                allocations: scaledCategoryAllocations,
                totalBudget: targetBudget
            )
        }
        .sheet(isPresented: $showCategoryEditor) {
            // Create a temporary budget for editing
            let tempBudget = UserBudget(
                id: "temp",
                userId: "temp",
                monthlyAmount: targetBudget,
                categoryAllocations: editableCategoryAllocations.isEmpty ? scaledCategoryAllocations : editableCategoryAllocations.map { editable in
                    CategoryAllocation(
                        category: editable.category,
                        amount: editable.amount,
                        isLocked: editable.isLocked
                    )
                }
            )

            EditCategoryBudgetsSheet(initialBudget: tempBudget) { updatedAllocations in
                handleCategorySave(updatedAllocations)
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 4)
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [Color(red: 0.6, green: 0.4, blue: 1.0), Color(red: 0.3, green: 0.7, blue: 1.0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .modifier(RotatingAnimation())

                Image(systemName: "sparkles")
                    .font(.system(size: 28))
                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 1.0))
            }

            VStack(spacing: 8) {
                Text("Milo is Analyzing Your Spending")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Text("Finding patterns and optimization opportunities...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()
        }
    }

    // MARK: - Onboarding Content (No Data)

    private func onboardingContent(_ suggestion: AIBudgetSuggestionResponse) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Welcome header with progress
                onboardingHeader(suggestion)
                    .padding(.horizontal, 20)

                // AI Recommended Budget - Best Effort (even with no data)
                aiRecommendedBudgetCardForOnboarding(suggestion)
                    .padding(.horizontal, 20)

                // Scan receipt CTA
                scanReceiptCTASection
                    .padding(.horizontal, 20)

                // Option to use suggested budget anyway
                useAnywaySuggestionSection(suggestion)
                    .padding(.horizontal, 20)
            }
            .padding(.vertical, 16)
        }
    }

    private func onboardingHeader(_ suggestion: AIBudgetSuggestionResponse) -> some View {
        HStack(spacing: 16) {
            // Progress ring showing 0 of 3
            DataCollectionProgressRing(
                monthsCollected: 0,
                targetMonths: 3,
                size: 64,
                showLabel: false
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("Getting Started")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Text("Scan receipts to personalize your budget")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))

                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))

                    Text("We've prepared a starting point for you")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 1.0))
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.55, green: 0.35, blue: 0.95).opacity(0.12),
                            Color(red: 0.55, green: 0.35, blue: 0.95).opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(red: 0.55, green: 0.35, blue: 0.95).opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func aiRecommendedBudgetCardForOnboarding(_ suggestion: AIBudgetSuggestionResponse) -> some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.yellow.opacity(0.8))

                    Text("Suggested Starting Point")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                }

                Spacer()

                // Preliminary badge
                Text("Preliminary")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                    )
            }

            // Recommended amount
            VStack(spacing: 6) {
                Text(String(format: "€%.0f", suggestion.recommendedBudget.amount))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))

                Text("per month")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
            }

            // Reasoning
            Text(suggestion.recommendedBudget.reasoning)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.45))
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            // Note about personalization
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                Text("This will become personalized as you scan receipts")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(.white.opacity(0.35))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.06), style: StrokeStyle(lineWidth: 1, dash: [8, 4]))
                )
        )
    }

    private var scanReceiptCTASection: some View {
        VStack(spacing: 12) {
            Button(action: {
                dismiss()
                onScanReceipt?()
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 18, weight: .semibold))

                    Text("Scan Your First Receipt")
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.3, green: 0.7, blue: 1.0),
                            Color(red: 0.25, green: 0.6, blue: 0.95)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: Color(red: 0.3, green: 0.7, blue: 1.0).opacity(0.4), radius: 12, y: 4)
            }

            Text("Start building your personalized budget profile")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
        }
    }

    private func useAnywaySuggestionSection(_ suggestion: AIBudgetSuggestionResponse) -> some View {
        VStack(spacing: 16) {
            // Divider with "or"
            HStack {
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 1)

                Text("or")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))

                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 1)
            }

            // Use suggested amount button
            Button(action: {
                customAmount = suggestion.recommendedBudget.amount
                selectionMode = .custom
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))

                    Text("Use Suggested Budget (€\(Int(suggestion.recommendedBudget.amount)))")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
            }

            Text("You can always adjust later as you scan more receipts")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)

            // If they want to proceed anyway, show a simplified setup
            if selectionMode == .custom {
                simplifiedBudgetSetup(suggestion)
            }
        }
    }

    private func simplifiedBudgetSetup(_ suggestion: AIBudgetSuggestionResponse) -> some View {
        VStack(spacing: 20) {
            // Amount display
            Text(String(format: "€%.0f", customAmount))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))

            // Slider
            VStack(spacing: 8) {
                Slider(
                    value: $customAmount,
                    in: 100...1500,
                    step: 25
                )
                .tint(Color(red: 0.3, green: 0.7, blue: 1.0))

                HStack {
                    Text("€100")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                    Spacer()
                    Text("€1,500")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                }
            }

            // Create button
            Button(action: createBudget) {
                HStack(spacing: 8) {
                    if viewModel.isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Set Starting Budget")
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.3, green: 0.7, blue: 1.0),
                            Color(red: 0.25, green: 0.6, blue: 0.95)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
            }
            .disabled(viewModel.isSaving)

            // Note
            Text("This is a starting point. Your budget will become more personalized as you scan receipts.")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.03))
        )
    }

    // MARK: - Building Profile Content (1-2 Months Data)

    private func buildingProfileContent(_ suggestion: AIBudgetSuggestionResponse) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with progress
                buildingProfileHeader(suggestion)

                // AI Recommended Budget - Best Effort (prominent display)
                aiRecommendedBudgetCardForPartialData(suggestion)

                // AI Insight if available
                if !suggestion.summary.isEmpty {
                    aiInsightCard(suggestion.summary)
                }

                // Budget target section (same as full, but with confidence indicator)
                budgetTargetSectionWithConfidence(suggestion)

                // Category preview (with muted styling indicator)
                categoryPreviewSectionForPartialData(suggestion)

                // Savings opportunities preview
                if !suggestion.savingsOpportunities.isEmpty {
                    savingsOpportunitiesPreview(suggestion)
                }

                // Tips
                if !suggestion.personalizedTips.isEmpty {
                    tipsSection(suggestion.personalizedTips)
                }

                // Create budget button
                createBudgetButton
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private func buildingProfileHeader(_ suggestion: AIBudgetSuggestionResponse) -> some View {
        HStack(spacing: 16) {
            // Progress ring
            DataCollectionProgressRing(
                monthsCollected: suggestion.basedOnMonths,
                targetMonths: 3,
                size: 72,
                showLabel: false
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("Building Your Profile")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Text(suggestion.dataBasisDescription)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))

                // Progress message
                let remaining = 3 - suggestion.basedOnMonths
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12))

                    Text("\(remaining) more month\(remaining == 1 ? "" : "s") for full personalization")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(Color(red: 0.55, green: 0.35, blue: 0.95))
            }

            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.55, green: 0.35, blue: 0.95).opacity(0.15),
                            Color(red: 0.55, green: 0.35, blue: 0.95).opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(red: 0.55, green: 0.35, blue: 0.95).opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func budgetTargetSectionWithConfidence(_ suggestion: AIBudgetSuggestionResponse) -> some View {
        VStack(spacing: 20) {
            // Section header with confidence badge
            HStack {
                Image(systemName: "target")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))

                Text("Set Your Target")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                ConfidenceBadge(confidence: suggestion.recommendedBudget.confidence, style: .compact)
            }

            // Mode toggle and selection (reuse existing)
            HStack(spacing: 0) {
                modeToggleButton(mode: .percentage, label: "Save %", icon: "percent")
                modeToggleButton(mode: .custom, label: "Custom", icon: "slider.horizontal.3")
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
            )

            if selectionMode == .percentage {
                percentageSelector
            } else {
                customAmountSelector
            }

            resultDisplay
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func categoryPreviewSectionForPartialData(_ suggestion: AIBudgetSuggestionResponse) -> some View {
        VStack(spacing: 16) {
            // Header with "Preliminary" indicator
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

                // Preliminary badge
                Text("Building")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                    )
            }

            // Category bars with slightly muted styling
            VStack(spacing: 10) {
                ForEach(categoryListExpanded ? scaledCategoryAllocations : Array(scaledCategoryAllocations.prefix(5)), id: \.category) { allocation in
                    categoryBarForPartialData(allocation)
                }

                // Expand/collapse button
                if scaledCategoryAllocations.count > 5 {
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            categoryListExpanded.toggle()
                        }
                    }) {
                        HStack(spacing: 6) {
                            if !categoryListExpanded {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Show \(scaledCategoryAllocations.count - 5) more categories")
                                    .font(.system(size: 12, weight: .semibold))
                            } else {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Show less")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                        }
                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 1.0))
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(red: 0.6, green: 0.4, blue: 1.0).opacity(0.08))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            // Note about improving accuracy
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))

                Text("Category allocations will improve with more data")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.6, green: 0.4, blue: 1.0).opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(red: 0.6, green: 0.4, blue: 1.0).opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [8, 4]))
                )
        )
    }

    private func categoryBarForPartialData(_ allocation: CategoryAllocation) -> some View {
        let percentage = targetBudget > 0 ? (allocation.amount / targetBudget) : 0

        return HStack(spacing: 12) {
            // Category icon with slightly muted opacity
            ZStack {
                Circle()
                    .fill(allocation.category.categoryColor.opacity(0.15))
                    .frame(width: 32, height: 32)

                Image(systemName: categoryIcon(for: allocation.category))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(allocation.category.categoryColor.opacity(0.8))
            }

            // Name and bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(allocation.category)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)

                    Spacer()

                    Text(String(format: "€%.0f", allocation.amount))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }

                // Progress bar with muted styling
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(allocation.category.categoryColor.opacity(0.7))
                            .frame(width: geometry.size.width * CGFloat(percentage), height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
    }

    private func savingsOpportunitiesPreview(_ suggestion: AIBudgetSuggestionResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Potential Savings")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                Text("Early insight")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }

            // Show first 2 opportunities
            ForEach(suggestion.savingsOpportunities.prefix(2)) { opportunity in
                HStack(spacing: 12) {
                    Image(systemName: opportunity.difficultyIcon)
                        .font(.system(size: 14))
                        .foregroundColor(opportunity.difficultyColor.opacity(0.8))
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(opportunity.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))

                        Text(opportunity.description)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(String(format: "€%.0f/mo", opportunity.potentialSavings))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.3, green: 0.8, blue: 0.5).opacity(0.8))
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.03))
                )
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Data collection phase header (always show progress)
                if let suggestion = viewModel.aiSuggestionState.data {
                    dataCollectionPhaseHeader(suggestion)
                }

                // AI Recommended Budget - PROMINENT
                aiRecommendedBudgetCard

                // AI Insight Summary
                if let summary = viewModel.aiSuggestionState.data?.summary, !summary.isEmpty {
                    aiInsightCard(summary)
                }

                // Budget Target Section
                budgetTargetSection

                // Category Allocations Preview
                categoryPreviewSection

                // Savings opportunities
                if let opportunities = viewModel.aiSuggestionState.data?.savingsOpportunities, !opportunities.isEmpty {
                    savingsOpportunitiesSection(opportunities)
                }

                // Tips from AI
                if let tips = viewModel.aiSuggestionState.data?.personalizedTips, !tips.isEmpty {
                    tipsSection(tips)
                }

                // Create Budget Button
                createBudgetButton
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Data Collection Phase Header

    private func dataCollectionPhaseHeader(_ suggestion: AIBudgetSuggestionResponse) -> some View {
        HStack(spacing: 16) {
            // Progress ring
            DataCollectionProgressRing(
                monthsCollected: suggestion.basedOnMonths,
                targetMonths: 3,
                size: 64,
                showLabel: false
            )

            VStack(alignment: .leading, spacing: 4) {
                // Phase title
                Text(suggestion.dataCollectionPhase.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                // Data basis
                Text(suggestion.dataBasisDescription)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))

                // Status message
                HStack(spacing: 4) {
                    Image(systemName: suggestion.dataCollectionPhase.isFullyPersonalized ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                        .font(.system(size: 12))

                    Text(suggestion.dataCollectionPhase.isFullyPersonalized ?
                         "Fully personalized recommendations" :
                         "\(3 - suggestion.basedOnMonths) more month\(suggestion.basedOnMonths == 2 ? "" : "s") for full personalization")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(suggestion.dataCollectionPhase.isFullyPersonalized ?
                                 Color(red: 0.3, green: 0.8, blue: 0.5) :
                                 Color(red: 0.55, green: 0.35, blue: 0.95))
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            (suggestion.dataCollectionPhase.isFullyPersonalized ?
                             Color(red: 0.3, green: 0.8, blue: 0.5) :
                             Color(red: 0.55, green: 0.35, blue: 0.95)).opacity(0.12),
                            (suggestion.dataCollectionPhase.isFullyPersonalized ?
                             Color(red: 0.3, green: 0.8, blue: 0.5) :
                             Color(red: 0.55, green: 0.35, blue: 0.95)).opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            (suggestion.dataCollectionPhase.isFullyPersonalized ?
                             Color(red: 0.3, green: 0.8, blue: 0.5) :
                             Color(red: 0.55, green: 0.35, blue: 0.95)).opacity(0.2),
                            lineWidth: 1
                        )
                )
        )
    }

    // MARK: - AI Recommended Budget Card

    private var aiRecommendedBudgetCard: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 1.0))

                    Text("Milo's Recommended Budget")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }

                Spacer()

                if let confidence = viewModel.aiSuggestionState.data?.recommendedBudget.confidence {
                    ConfidenceBadge(confidence: confidence, style: .compact)
                }
            }

            // Recommended amount - VERY PROMINENT
            if let amount = viewModel.aiSuggestionState.data?.recommendedBudget.amount {
                VStack(spacing: 8) {
                    Text(String(format: "€%.0f", amount))
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("per month")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            // Health score and average spend row
            HStack(spacing: 0) {
                // Health Score
                if let score = viewModel.aiSuggestionState.data?.budgetHealthScore {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.1), lineWidth: 4)
                                .frame(width: 44, height: 44)

                            Circle()
                                .trim(from: 0, to: CGFloat(score) / 100)
                                .stroke(healthScoreColor(score), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .frame(width: 44, height: 44)
                                .rotationEffect(.degrees(-90))

                            Text("\(score)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }

                        Text("Health")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                }

                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 1, height: 50)

                // Average Spend
                VStack(spacing: 4) {
                    Text(String(format: "€%.0f", averageSpending))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))

                    Text("Avg Spend")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 1, height: 50)

                // Potential Savings
                if let recommended = viewModel.aiSuggestionState.data?.recommendedBudget.amount {
                    let savings = averageSpending - recommended
                    VStack(spacing: 4) {
                        Text(String(format: "€%.0f", max(0, savings)))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(savings > 0 ? Color(red: 0.3, green: 0.8, blue: 0.5) : .white.opacity(0.5))

                        Text("Savings")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.03))
            )

            // Reasoning
            if let reasoning = viewModel.aiSuggestionState.data?.recommendedBudget.reasoning {
                Text(reasoning)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.6, green: 0.4, blue: 1.0).opacity(0.12),
                            Color(red: 0.5, green: 0.3, blue: 0.9).opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(red: 0.6, green: 0.4, blue: 1.0).opacity(0.25), lineWidth: 1)
                )
        )
    }

    // MARK: - AI Recommended Budget Card for Partial Data

    private func aiRecommendedBudgetCardForPartialData(_ suggestion: AIBudgetSuggestionResponse) -> some View {
        VStack(spacing: 16) {
            // Header with "Best Effort" indicator
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 1.0).opacity(0.8))

                    Text("Milo's Recommended Budget")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                }

                Spacer()

                // Best effort badge
                HStack(spacing: 4) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 10))
                    Text("Best Effort")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(.white.opacity(0.5))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                )
            }

            // Recommended amount - prominent but with muted styling
            VStack(spacing: 8) {
                Text(String(format: "€%.0f", suggestion.recommendedBudget.amount))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))

                Text("per month")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }

            // Confidence badge
            ConfidenceBadge(confidence: suggestion.recommendedBudget.confidence, style: .compact)

            // Stats row with muted styling
            HStack(spacing: 0) {
                // Average Spend (if available)
                if suggestion.totalSpendAnalyzed > 0 {
                    VStack(spacing: 4) {
                        Text(String(format: "€%.0f", averageSpending))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))

                        Text("Avg Spend")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)

                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 1, height: 40)
                }

                // Potential Savings
                let savings = averageSpending - suggestion.recommendedBudget.amount
                VStack(spacing: 4) {
                    Text(String(format: "€%.0f", max(0, savings)))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(savings > 0 ? Color(red: 0.3, green: 0.8, blue: 0.5).opacity(0.8) : .white.opacity(0.4))

                    Text("Est. Savings")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 1, height: 40)

                // Data basis
                VStack(spacing: 4) {
                    Text("\(suggestion.basedOnMonths)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.55, green: 0.35, blue: 0.95).opacity(0.9))

                    Text(suggestion.basedOnMonths == 1 ? "Month" : "Months")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.03))
            )

            // Reasoning with note about improving accuracy
            VStack(spacing: 8) {
                Text(suggestion.recommendedBudget.reasoning)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10))
                    Text("Will improve with more data")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(Color(red: 0.55, green: 0.35, blue: 0.95).opacity(0.8))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.6, green: 0.4, blue: 1.0).opacity(0.08),
                            Color(red: 0.5, green: 0.3, blue: 0.9).opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(red: 0.6, green: 0.4, blue: 1.0).opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [8, 4]))
                )
        )
    }

    // MARK: - Savings Opportunities Section

    private func savingsOpportunitiesSection(_ opportunities: [SavingsOpportunity]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(red: 0.3, green: 0.8, blue: 0.5))

                    Text("Savings Opportunities")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }

                Spacer()

                let totalSavings = opportunities.reduce(0) { $0 + $1.potentialSavings }
                Text(String(format: "Up to €%.0f/mo", totalSavings))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(red: 0.3, green: 0.8, blue: 0.5))
            }

            ForEach(opportunities.prefix(3)) { opportunity in
                let isExpanded = expandedOpportunityIds.contains(opportunity.id)

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: opportunity.difficultyIcon)
                        .font(.system(size: 16))
                        .foregroundColor(opportunity.difficultyColor)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(opportunity.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)

                        Text(opportunity.description)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(isExpanded ? nil : 2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(String(format: "€%.0f", opportunity.potentialSavings))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.3, green: 0.8, blue: 0.5))

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if isExpanded {
                            expandedOpportunityIds.remove(opportunity.id)
                        } else {
                            expandedOpportunityIds.insert(opportunity.id)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.3, green: 0.8, blue: 0.5).opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(red: 0.3, green: 0.8, blue: 0.5).opacity(0.15), lineWidth: 1)
                )
        )
    }

    // MARK: - AI Insight Card

    private func aiInsightCard(_ summary: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // AI Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.6, green: 0.4, blue: 1.0).opacity(0.3),
                                Color(red: 0.4, green: 0.3, blue: 0.9).opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)

                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 1.0))
            }

            // Summary Text
            VStack(alignment: .leading, spacing: 6) {
                Text("Milo's Insight")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 1.0))
                    .textCase(.uppercase)
                    .tracking(0.5)

                Text(summary)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.6, green: 0.4, blue: 1.0).opacity(0.08),
                            Color(red: 0.5, green: 0.3, blue: 0.9).opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.6, green: 0.4, blue: 1.0).opacity(0.25),
                                    Color(red: 0.5, green: 0.3, blue: 0.9).opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }

    // MARK: - Budget Target Section

    private var budgetTargetSection: some View {
        VStack(spacing: 20) {
            // Section Header
            HStack {
                Image(systemName: "target")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))

                Text("Set Your Target")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Spacer()
            }

            // Mode Toggle
            HStack(spacing: 0) {
                modeToggleButton(mode: .percentage, label: "Save %", icon: "percent")
                modeToggleButton(mode: .custom, label: "Custom", icon: "slider.horizontal.3")
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
            )

            // Selection Content
            if selectionMode == .percentage {
                percentageSelector
            } else {
                customAmountSelector
            }

            // Result Display
            resultDisplay
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func modeToggleButton(mode: SelectionMode, label: String, icon: String) -> some View {
        Button(action: { withAnimation(.spring(response: 0.3)) { selectionMode = mode } }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(selectionMode == mode ? .white : .white.opacity(0.5))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selectionMode == mode ? Color(red: 0.3, green: 0.7, blue: 1.0).opacity(0.3) : Color.clear)
            )
        }
        .padding(4)
    }

    private var percentageSelector: some View {
        VStack(spacing: 16) {
            Text("How much do you want to save?")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))

            // Percentage pills
            HStack(spacing: 8) {
                ForEach(SavingsPercentage.allCases) { percentage in
                    Button(action: { withAnimation(.spring(response: 0.25)) { selectedPercentage = percentage } }) {
                        Text(percentage.label)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(selectedPercentage == percentage ? .white : .white.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedPercentage == percentage ?
                                          LinearGradient(
                                            colors: [Color(red: 0.3, green: 0.8, blue: 0.5), Color(red: 0.2, green: 0.7, blue: 0.5)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                          ) :
                                            LinearGradient(colors: [Color.white.opacity(0.08)], startPoint: .top, endPoint: .bottom))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedPercentage == percentage ? Color(red: 0.3, green: 0.8, blue: 0.5) : Color.clear, lineWidth: 2)
                            )
                    }
                }
            }
        }
    }

    private var customAmountSelector: some View {
        VStack(spacing: 16) {
            Text("Set your monthly budget")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))

            // Amount display
            Text(String(format: "€%.0f", customAmount))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))

            // Slider
            VStack(spacing: 8) {
                Slider(
                    value: $customAmount,
                    in: 100...max(averageSpending * 1.5, 2000),
                    step: 25
                )
                .tint(Color(red: 0.3, green: 0.7, blue: 1.0))

                HStack {
                    Text("€100")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                    Spacer()
                    Text(String(format: "€%.0f", max(averageSpending * 1.5, 2000)))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                }
            }

            // Quick select based on average
            HStack(spacing: 8) {
                quickAmountButton(multiplier: 0.8, label: "-20%")
                quickAmountButton(multiplier: 0.9, label: "-10%")
                quickAmountButton(multiplier: 1.0, label: "Average")
                quickAmountButton(multiplier: 1.1, label: "+10%")
            }
        }
    }

    private func quickAmountButton(multiplier: Double, label: String) -> some View {
        let amount = averageSpending * multiplier
        let isSelected = abs(customAmount - amount) < 1

        return Button(action: { withAnimation { customAmount = amount } }) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color(red: 0.3, green: 0.7, blue: 1.0).opacity(0.3) : Color.white.opacity(0.05))
                )
        }
    }

    private var resultDisplay: some View {
        HStack(spacing: 0) {
            // Target Budget
            VStack(spacing: 4) {
                Text("Target Budget")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))

                Text(String(format: "€%.0f", targetBudget))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 1, height: 40)

            // Monthly Savings
            VStack(spacing: 4) {
                Text("Monthly Savings")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))

                HStack(spacing: 4) {
                    Text(String(format: "€%.0f", savingsAmount))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(savingsAmount > 0 ? Color(red: 0.3, green: 0.8, blue: 0.5) : .white.opacity(0.5))

                    if savingsAmount > 0 {
                        Text(String(format: "(%.0f%%)", savingsPercentageValue))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(red: 0.3, green: 0.8, blue: 0.5).opacity(0.7))
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
        )
    }

    // MARK: - Category Preview Section

    private var categoryPreviewSection: some View {
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

                    // Customized indicator
                    if hasCustomizedCategories {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                            Text("Customized")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(Color(red: 0.3, green: 0.8, blue: 0.5))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.3, green: 0.8, blue: 0.5).opacity(0.15))
                        )
                    }
                }

                Spacer()

                // Edit button
                Button(action: { openCategoryEditor() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Edit")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))
                }
            }

            // Category bars - show top 5 or all if expanded
            VStack(spacing: 10) {
                ForEach(categoryListExpanded ? scaledCategoryAllocations : Array(scaledCategoryAllocations.prefix(5)), id: \.category) { allocation in
                    categoryBar(allocation)
                }

                // Expand/collapse button
                if scaledCategoryAllocations.count > 5 {
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            categoryListExpanded.toggle()
                        }
                    }) {
                        HStack(spacing: 6) {
                            if !categoryListExpanded {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Show \(scaledCategoryAllocations.count - 5) more categories")
                                    .font(.system(size: 12, weight: .semibold))
                            } else {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Show less")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                        }
                        .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(red: 0.3, green: 0.7, blue: 1.0).opacity(0.08))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
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

    private func categoryBar(_ allocation: CategoryAllocation) -> some View {
        let percentage = targetBudget > 0 ? (allocation.amount / targetBudget) : 0

        return HStack(spacing: 12) {
            // Category icon
            ZStack {
                Circle()
                    .fill(allocation.category.categoryColor.opacity(0.2))
                    .frame(width: 32, height: 32)

                Image(systemName: categoryIcon(for: allocation.category))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(allocation.category.categoryColor)
            }

            // Name and bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(allocation.category)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    // Edited indicator
                    if allocation.isLocked {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))
                    }

                    Spacer()

                    Text(String(format: "€%.0f", allocation.amount))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(allocation.category.categoryColor)
                            .frame(width: geometry.size.width * CGFloat(percentage), height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
    }

    // MARK: - Tips Section

    private func tipsSection(_ tips: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.yellow)

                Text("Milo's Tips")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(tips.prefix(2), id: \.self) { tip in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(.white.opacity(0.5))
                        Text(tip)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.yellow.opacity(0.08))
        )
    }

    // MARK: - Create Budget Button

    private var createBudgetButton: some View {
        Button(action: createBudget) {
            HStack(spacing: 10) {
                if viewModel.isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))

                    Text("Create Smart Budget")
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
        .disabled(viewModel.isSaving)
        .padding(.top, 8)
        .padding(.bottom, 20)
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            VStack(spacing: 8) {
                Text("Couldn't Load Analysis")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Text(error)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button(action: { Task { await viewModel.loadAISuggestion() } }) {
                Text("Try Again")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.3, green: 0.7, blue: 1.0))
                    )
            }

            Spacer()
        }
    }

    // MARK: - Helper Functions

    private func healthScoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return Color(red: 0.3, green: 0.8, blue: 0.5)
        case 60..<80: return Color(red: 0.3, green: 0.7, blue: 1.0)
        case 40..<60: return Color(red: 1.0, green: 0.75, blue: 0.3)
        default: return Color(red: 1.0, green: 0.4, blue: 0.4)
        }
    }

    private func categoryIcon(for category: String) -> String {
        category.categoryIcon
    }

    // MARK: - Category Editing

    private func openCategoryEditor() {
        // Initialize editable categories if not already done
        if editableCategoryAllocations.isEmpty {
            editableCategoryAllocations = scaledCategoryAllocations.map { allocation in
                EditableCategoryAllocation(
                    category: allocation.category,
                    amount: allocation.amount,
                    originalAmount: allocation.amount,
                    isLocked: allocation.isLocked
                )
            }
        }
        showCategoryEditor = true
    }

    private func handleCategorySave(_ allocations: [CategoryAllocation]) {
        // Update editable categories
        editableCategoryAllocations = allocations.map { allocation in
            EditableCategoryAllocation(
                category: allocation.category,
                amount: allocation.amount,
                originalAmount: allocation.amount, // Keep current as new original
                isLocked: allocation.isLocked
            )
        }
        hasCustomizedCategories = true
    }

    // MARK: - Actions

    private func createBudget() {
        Task {
            let success = await viewModel.createBudget(
                amount: targetBudget,
                categoryAllocations: scaledCategoryAllocations.isEmpty ? nil : scaledCategoryAllocations
            )
            if success {
                showSuccessSheet = true
            }
        }
    }
}

// MARK: - Rotating Animation Modifier

struct RotatingAnimation: ViewModifier {
    @State private var rotation: Double = 0

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

// MARK: - All Categories Sheet

struct AllCategoriesSheet: View {
    let allocations: [CategoryAllocation]
    let totalBudget: Double
    @Environment(\.dismiss) private var dismiss

    /// Group allocations by category group
    private var groupedAllocations: [(group: String, allocations: [CategoryAllocation])] {
        let registry = CategoryRegistryManager.shared
        var groups: [String: [CategoryAllocation]] = [:]

        for allocation in allocations {
            let group = registry.groupForSubCategory(allocation.category)
            groups[group, default: []].append(allocation)
        }

        return groups
            .map { (group: $0.key, allocations: $0.value) }
            .sorted { g1, g2 in
                let total1 = g1.allocations.reduce(0) { $0 + $1.amount }
                let total2 = g2.allocations.reduce(0) { $0 + $1.amount }
                return total1 > total2
            }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(white: 0.08).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Total
                        VStack(spacing: 4) {
                            Text("Total Budget")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))

                            Text(String(format: "€%.0f", totalBudget))
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))
                        }
                        .padding(.vertical, 20)

                        // All categories grouped
                        let grouped = groupedAllocations
                        if grouped.count <= 1 {
                            VStack(spacing: 8) {
                                ForEach(allocations, id: \.category) { allocation in
                                    allocationRow(allocation)
                                }
                            }
                        } else {
                            VStack(spacing: 20) {
                                ForEach(grouped, id: \.group) { section in
                                    VStack(alignment: .leading, spacing: 8) {
                                        // Group header
                                        let registry = CategoryRegistryManager.shared
                                        let groupTotal = section.allocations.reduce(0) { $0 + $1.amount }

                                        HStack(spacing: 8) {
                                            Image(systemName: registry.iconForGroup(section.group))
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(registry.colorForGroup(section.group))

                                            Text(section.group)
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.white.opacity(0.8))

                                            Spacer()

                                            Text(String(format: "€%.0f", groupTotal))
                                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                        .padding(.horizontal, 4)

                                        ForEach(section.allocations, id: \.category) { allocation in
                                            allocationRow(allocation)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("All Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func allocationRow(_ allocation: CategoryAllocation) -> some View {
        let percentage = totalBudget > 0 ? (allocation.amount / totalBudget) * 100 : 0

        return HStack(spacing: 14) {
            Circle()
                .fill(allocation.category.categoryColor)
                .frame(width: 12, height: 12)

            Text(allocation.category)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)

            Spacer()

            Text(String(format: "%.0f%%", percentage))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.4))

            Text(String(format: "€%.0f", allocation.amount))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Preview

#Preview {
    BudgetSetupView(viewModel: BudgetViewModel())
}
