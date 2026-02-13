//
//  AddBudgetModalView.swift
//  Scandalicious
//
//  Smart Anchor Interface for adding/editing a per-category budget.
//  Shows historical spending context + three tier suggestions.
//

import SwiftUI

// MARK: - Add Budget Modal View

struct AddBudgetModalView: View {
    @StateObject private var vm: SmartAnchorViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isAmountFocused: Bool

    /// Callback when user confirms a budget amount
    let onSetBudget: (String, Double) -> Void

    // MARK: - Animation State

    @State private var barsAnimated = false
    @State private var averageLineAnimated = false

    // MARK: - Init

    init(
        categoryName: String,
        monthlyTotals: [Double],
        monthLabels: [String],
        onSetBudget: @escaping (String, Double) -> Void
    ) {
        _vm = StateObject(wrappedValue: SmartAnchorViewModel(
            categoryName: categoryName,
            monthlyTotals: monthlyTotals,
            monthLabels: monthLabels
        ))
        self.onSetBudget = onSetBudget
    }

    /// Convenience init from suggestion data (when per-month data unavailable)
    init(
        categoryName: String,
        averageMonthlySpend: Double,
        basedOnMonths: Int,
        onSetBudget: @escaping (String, Double) -> Void
    ) {
        _vm = StateObject(wrappedValue: SmartAnchorViewModel(
            categoryName: categoryName,
            averageMonthlySpend: averageMonthlySpend,
            basedOnMonths: basedOnMonths
        ))
        self.onSetBudget = onSetBudget
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color(white: 0.06),
                        Color(red: 0.06, green: 0.05, blue: 0.10)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Category header
                        categoryHeader

                        // Spending context chart
                        if vm.hasHistory {
                            spendingChartSection
                        } else {
                            noHistoryPlaceholder
                        }

                        // Cycle toggle
                        cycleToggle

                        // Smart tier buttons
                        smartTierButtons

                        // Custom amount field
                        customAmountSection

                        // Set budget button
                        setBudgetButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white.opacity(0.7))
                }

                ToolbarItem(placement: .principal) {
                    Text("Set Budget")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.15)) {
                barsAnimated = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
                averageLineAnimated = true
            }
        }
    }

    // MARK: - Category Header

    private var categoryHeader: some View {
        HStack(spacing: 14) {
            Image.categorySymbol(vm.categoryName.categoryIcon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(vm.categoryName.categoryColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(vm.categoryName.normalizedCategoryName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                if vm.hasHistory {
                    Text("Your average is \(vm.formattedAverage) / \(vm.selectedCycle.rawValue.lowercased())")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                } else {
                    Text("No spending history yet")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    // MARK: - Spending Chart Section

    private var spendingChartSection: some View {
        VStack(spacing: 14) {
            // Section header
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 1.0))

                Text("Recent Spending")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))

                Spacer()
            }

            // Chart
            spendingChart
                .frame(height: 160)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var spendingChart: some View {
        let dataPoints = vm.chartDataPoints
        let maxAmount = dataPoints.map(\.amount).max() ?? 1
        let avgAmount = vm.averageMonthlySpend

        return GeometryReader { geometry in
            let barWidth: CGFloat = 40
            let spacing = (geometry.size.width - barWidth * CGFloat(dataPoints.count)) / CGFloat(max(1, dataPoints.count + 1))
            let chartHeight = geometry.size.height - 30 // Reserve space for labels

            ZStack(alignment: .bottom) {
                // Bars
                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(Array(dataPoints.enumerated()), id: \.offset) { index, point in
                        VStack(spacing: 6) {
                            // Amount label above bar
                            Text(String(format: "€%.0f", point.amount))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(barsAnimated ? 0.7 : 0))

                            // Bar
                            let barHeight = maxAmount > 0 ? (point.amount / maxAmount) * (chartHeight - 20) : 0
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            vm.categoryName.categoryColor.opacity(0.8),
                                            vm.categoryName.categoryColor.opacity(0.4)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: barWidth, height: barsAnimated ? max(4, barHeight) : 4)

                            // Month label
                            Text(point.monthLabel)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                // Average line
                if avgAmount > 0 && maxAmount > 0 {
                    let lineY = (1 - avgAmount / maxAmount) * (chartHeight - 20) + 10
                    VStack(spacing: 0) {
                        HStack(spacing: 4) {
                            Text("avg")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))
                                .opacity(averageLineAnimated ? 1 : 0)

                            Rectangle()
                                .fill(Color(red: 0.3, green: 0.7, blue: 1.0).opacity(0.6))
                                .frame(height: 1.5)
                                .opacity(averageLineAnimated ? 1 : 0)
                        }
                    }
                    .offset(y: -geometry.size.height + lineY + 30)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
    }

    // MARK: - No History Placeholder

    private var noHistoryPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.2))

            Text("No spending data for this category yet")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.4))

            Text("Enter a custom budget amount below")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), style: StrokeStyle(lineWidth: 1, dash: [8, 4]))
                )
        )
    }

    // MARK: - Cycle Toggle

    private var cycleToggle: some View {
        HStack(spacing: 0) {
            ForEach(BudgetCycle.allCases) { cycle in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        vm.selectedCycle = cycle
                        // Recalculate custom amount if a tier was selected
                        if let tierId = vm.selectedTierId,
                           let tier = vm.tiers.first(where: { $0.id == tierId }) {
                            vm.customAmount = String(format: "%.0f", tier.amount)
                        }
                    }
                }) {
                    Text(cycle.rawValue)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(vm.selectedCycle == cycle ? .white : .white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(vm.selectedCycle == cycle
                                      ? Color(red: 0.3, green: 0.7, blue: 1.0).opacity(0.3)
                                      : Color.clear)
                        )
                }
                .padding(4)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
        )
    }

    // MARK: - Smart Tier Buttons

    private var smartTierButtons: some View {
        VStack(spacing: 14) {
            // Section label
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.yellow.opacity(0.8))

                Text("Smart Suggestions")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))

                Spacer()
            }

            if vm.hasHistory {
                HStack(spacing: 10) {
                    ForEach(vm.tiers) { tier in
                        tierButton(tier)
                    }
                }
            } else {
                Text("Scan receipts in this category to unlock smart suggestions")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func tierButton(_ tier: SmartAnchorTier) -> some View {
        let isSelected = vm.selectedTierId == tier.id

        return Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()

            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                vm.selectTier(tier)
            }
            isAmountFocused = false
        }) {
            VStack(spacing: 8) {
                // Amount
                Text(String(format: "€%.0f", tier.amount))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.8))

                // Label
                Text(tier.sublabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .white.opacity(0.45))

                // Icon
                Image(systemName: tier.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .white.opacity(0.9) : tier.color.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected
                          ? tier.color.opacity(0.3)
                          : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected
                            ? tier.color.opacity(0.6)
                            : Color.white.opacity(0.08),
                            lineWidth: isSelected ? 2 : 1)
            )
            .scaleEffect(isSelected ? 1.03 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Custom Amount Section

    private var customAmountSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Or enter a custom amount")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
            }

            HStack(spacing: 12) {
                Text("€")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))

                TextField("0", text: $vm.customAmount)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .keyboardType(.numberPad)
                    .focused($isAmountFocused)
                    .onChange(of: vm.customAmount) { _ in
                        vm.onCustomAmountEdited()
                    }

                if !vm.customAmount.isEmpty {
                    Button(action: {
                        vm.customAmount = ""
                        vm.selectedTierId = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                isAmountFocused
                                    ? Color(red: 0.3, green: 0.7, blue: 1.0).opacity(0.5)
                                    : Color.white.opacity(0.1),
                                lineWidth: isAmountFocused ? 2 : 1
                            )
                    )
            )

            // Cycle label
            if let amount = vm.resolvedAmount, amount > 0 {
                let perText = vm.selectedCycle == .monthly ? "per month" : "per week"
                Text(String(format: "€%.0f %@", amount, perText))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    // MARK: - Set Budget Button

    private var setBudgetButton: some View {
        Button(action: handleSetBudget) {
            HStack(spacing: 10) {
                if vm.isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))

                    Text("Set Budget")
                        .font(.system(size: 17, weight: .bold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: vm.canSetBudget
                        ? [Color(red: 0.4, green: 0.3, blue: 0.95), Color(red: 0.6, green: 0.4, blue: 1.0)]
                        : [Color.white.opacity(0.1), Color.white.opacity(0.08)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(
                color: vm.canSetBudget
                    ? Color(red: 0.5, green: 0.3, blue: 1.0).opacity(0.4)
                    : Color.clear,
                radius: 12, y: 4
            )
        }
        .disabled(!vm.canSetBudget || vm.isSaving)
        .padding(.bottom, 20)
    }

    // MARK: - Actions

    private func handleSetBudget() {
        guard let amount = vm.resolvedAmount else { return }
        vm.isSaving = true

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Convert weekly back to monthly for storage
        let monthlyAmount: Double
        if vm.selectedCycle == .weekly {
            monthlyAmount = amount * BudgetCycle.weeksPerMonth
        } else {
            monthlyAmount = amount
        }

        onSetBudget(vm.categoryName, monthlyAmount)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            vm.isSaving = false
            dismiss()
        }
    }
}

// MARK: - Smart Anchor Sheet Loader

/// Wrapper that loads per-category monthly spending from the API,
/// then presents the AddBudgetModalView with real data.
struct SmartAnchorSheetLoader: View {
    let categoryName: String
    let onSetBudget: (String, Double) -> Void

    @State private var monthlyData: CategoryMonthlySpend?
    @State private var isLoading = true
    @State private var loadError: String?

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let data = monthlyData {
                AddBudgetModalView(
                    categoryName: data.category,
                    monthlyTotals: data.monthlyTotals,
                    monthLabels: data.monthLabels,
                    onSetBudget: onSetBudget
                )
            } else {
                // No data found — show modal with fallback (zero history)
                AddBudgetModalView(
                    categoryName: categoryName,
                    averageMonthlySpend: 0,
                    basedOnMonths: 0,
                    onSetBudget: onSetBudget
                )
            }
        }
        .task {
            await loadData()
        }
    }

    private var loadingView: some View {
        ZStack {
            Color(white: 0.06).ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .tint(Color(red: 0.6, green: 0.4, blue: 1.0))
                    .scaleEffect(1.2)

                Text("Loading spending data...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .preferredColorScheme(.dark)
    }

    private func loadData() async {
        isLoading = true
        do {
            let response = try await BudgetAPIService.shared.getCategoryMonthlySpend(
                months: 3,
                category: categoryName
            )
            monthlyData = response.categories.first
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Preview

#Preview {
    AddBudgetModalView(
        categoryName: "Meat & Fish",
        monthlyTotals: [85, 110, 95],
        monthLabels: ["Nov", "Dec", "Jan"],
        onSetBudget: { category, amount in
            print("Set budget for \(category): €\(amount)")
        }
    )
}
