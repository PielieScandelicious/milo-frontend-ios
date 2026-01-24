//
//  InsightButton.swift
//  Scandalicious
//
//  Created by Claude on 21/01/2026.
//

import SwiftUI

// MARK: - Insight Button

struct InsightButton: View {
    let insightType: InsightType

    @State private var showingInsight = false

    // Dobby purple - matches the chat icon
    private let dobbyPurple = Color(red: 0.45, green: 0.15, blue: 0.85)

    var body: some View {
        Button {
            showingInsight = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .semibold))
                Text("Daily Insight")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(dobbyPurple)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(dobbyPurple.opacity(0.15))
            )
            .overlay(
                Capsule()
                    .stroke(dobbyPurple.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(InsightButtonStyle())
        .sheet(isPresented: $showingInsight) {
            InsightSheetView(insightType: insightType)
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(white: 0.08))
        }
    }
}

// MARK: - Insight Button Style

struct InsightButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Insight Sheet View

// MARK: - Daily Insight Cache

struct CachedInsight: Codable {
    let text: String
    let timestamp: Date

    var isValid: Bool {
        // Insights refresh at 6 AM daily
        let calendar = Calendar.current
        let now = Date()

        // Get today at 6 AM
        var todaySixAM = calendar.startOfDay(for: now)
        todaySixAM = calendar.date(byAdding: .hour, value: 6, to: todaySixAM) ?? todaySixAM

        // If we're before 6 AM today, the refresh point was yesterday at 6 AM
        let refreshPoint: Date
        if now < todaySixAM {
            refreshPoint = calendar.date(byAdding: .day, value: -1, to: todaySixAM) ?? todaySixAM
        } else {
            refreshPoint = todaySixAM
        }

        // Cache is valid if it was created after the most recent 6 AM refresh point
        return timestamp >= refreshPoint
    }
}

enum DailyInsightCache {
    private static let timestampSuffix = "_timestamp"

    static func load(for key: String) -> CachedInsight? {
        guard let text = UserDefaults.standard.string(forKey: key),
              let timestamp = UserDefaults.standard.object(forKey: key + timestampSuffix) as? Date else {
            return nil
        }
        return CachedInsight(text: text, timestamp: timestamp)
    }

    static func save(text: String, for key: String) {
        UserDefaults.standard.set(text, forKey: key)
        UserDefaults.standard.set(Date(), forKey: key + timestampSuffix)
    }

    static func clear(for key: String) {
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: key + timestampSuffix)
    }

    /// Check if a valid cached insight exists for the given type
    static func hasValidCache(for type: InsightType) -> Bool {
        if let cached = load(for: type.cacheKey), cached.isValid {
            return true
        }
        return false
    }
}

// MARK: - Height Preference Key for Dynamic Sizing

private struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct InsightSheetView: View {
    let insightType: InsightType

    @Environment(\.dismiss) private var dismiss
    @State private var insightText = ""
    @State private var isLoading = true
    @State private var error: String?
    @State private var contentOpacity: Double = 0
    @State private var contentBlur: Double = 8
    @State private var contentScale: Double = 0.96
    @State private var isCachedInsight = false
    @State private var contentHeight: CGFloat = 200

    private var title: String {
        switch insightType {
        case .totalSpending:
            return "Daily Spending Insight"
        case .healthScore:
            return "Daily Health Insight"
        case .storeBreakdown(let storeName, _, _, _):
            return "\(storeName) Daily Insight"
        }
    }

    private var icon: String {
        switch insightType {
        case .totalSpending:
            return "creditcard.fill"
        case .healthScore:
            return "heart.fill"
        case .storeBreakdown:
            return "storefront.fill"
        }
    }

    private var accentColor: Color {
        switch insightType {
        case .totalSpending:
            return .blue
        case .healthScore:
            return .green
        case .storeBreakdown:
            return .purple
        }
    }

    // Calculate dynamic detent based on content
    private var dynamicDetent: PresentationDetent {
        // Add padding for drag indicator (20) + safe area buffer (34)
        let totalHeight = contentHeight + 54
        return .height(totalHeight)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(accentColor)

                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()
                .background(Color.white.opacity(0.1))

            // Content - sizes to fit
            VStack(alignment: .leading, spacing: 0) {
                if isLoading {
                    HStack(spacing: 12) {
                        ProgressView()
                            .tint(accentColor)

                        Text("Generating insight...")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
                } else if let error = error {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.orange)

                        Text(error)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)

                        Button {
                            self.error = nil
                            isLoading = true
                            contentOpacity = 0
                            contentBlur = 8
                            contentScale = 0.96
                            DailyInsightCache.clear(for: insightType.cacheKey)
                            fetchInsight()
                        } label: {
                            Text("Try Again")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(accentColor)
                                .cornerRadius(20)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    // Insight text - naturally sized
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(accentColor)
                            .padding(.top, 2)

                        Text(insightText)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.white.opacity(0.9))
                            .lineSpacing(6)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(accentColor.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(accentColor.opacity(0.2), lineWidth: 1)
                    )
                    .opacity(contentOpacity)
                    .blur(radius: contentBlur)
                    .scaleEffect(contentScale)
                    .onAppear {
                        withAnimation(.easeOut(duration: 0.5)) {
                            contentOpacity = 1.0
                            contentBlur = 0
                            contentScale = 1.0
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Footer
            VStack(spacing: 0) {
                Divider()
                    .background(Color.white.opacity(0.1))

                Text("Insight by Dobby")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.vertical, 10)
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(key: HeightPreferenceKey.self, value: geo.size.height)
            }
        )
        .onPreferenceChange(HeightPreferenceKey.self) { height in
            if height > contentHeight {
                contentHeight = height
            }
        }
        .presentationDetents([dynamicDetent, .large])
        .onAppear {
            loadOrFetchInsight()
        }
    }

    private func loadOrFetchInsight() {
        // Check for cached insight first
        if let cached = DailyInsightCache.load(for: insightType.cacheKey), cached.isValid {
            // Use cached insight
            insightText = cached.text
            isLoading = false
            isCachedInsight = true
            return
        }

        // No valid cache, fetch new insight
        fetchInsight()
    }

    private func fetchInsight() {
        isCachedInsight = false
        Task {
            do {
                var fullText = ""
                for try await chunk in InsightService.shared.generateInsight(for: insightType) {
                    await MainActor.run {
                        fullText += chunk
                        insightText = fullText
                        if isLoading {
                            isLoading = false
                        }
                    }
                }
                // Save to cache after successful completion
                await MainActor.run {
                    DailyInsightCache.save(text: fullText, for: insightType.cacheKey)
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(white: 0.05).ignoresSafeArea()

        VStack(spacing: 20) {
            InsightButton(insightType: .totalSpending(
                amount: 523.45,
                period: "January 2026",
                storeCount: 5,
                topStore: "Albert Heijn"
            ))

            InsightButton(insightType: .healthScore(
                score: 3.8,
                period: "January 2026",
                totalItems: 47
            ))
        }
    }
}
