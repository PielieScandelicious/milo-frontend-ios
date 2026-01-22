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
                .presentationDetents([.fraction(0.7)])
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

private struct CachedInsight: Codable {
    let text: String
    let timestamp: Date

    var isValid: Bool {
        // Check if the insight was generated today (same calendar day)
        Calendar.current.isDateInToday(timestamp)
    }
}

private enum DailyInsightCache {
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
            .padding(.bottom, 16)

            Divider()
                .background(Color.white.opacity(0.1))

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isLoading {
                        HStack(spacing: 12) {
                            ProgressView()
                                .tint(accentColor)

                            Text("Generating insight...")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
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
                                // Clear cache and fetch fresh on retry
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
                        .padding(.top, 30)
                    } else {
                        // Insight text with nice formatting and premium fade-in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(accentColor)
                                .padding(.top, 2)

                            Text(insightText)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.white.opacity(0.9))
                                .lineSpacing(6)
                                .fixedSize(horizontal: false, vertical: true)
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
                .padding(20)
            }

            // Footer
            VStack(spacing: 8) {
                Divider()
                    .background(Color.white.opacity(0.1))

                VStack(spacing: 4) {
                    if !isLoading && error == nil {
                        Text("Today's insight • Refreshes daily")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    Text("Powered by Dobby")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                }
                .padding(.vertical, 12)
            }
        }
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
