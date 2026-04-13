//
//  PromoComponents.swift
//  Scandalicious
//
//  Created by Claude on 09/02/2026.
//

import SwiftUI

// MARK: - Color Constants

private let promoGreen = Color(red: 0.20, green: 0.85, blue: 0.50)
private let promoGreenDark = Color(red: 0.10, green: 0.65, blue: 0.40)
private let promoGold = Color(red: 1.00, green: 0.80, blue: 0.20)
private let cardBackground = Color(white: 0.08)
private let cardOverlayTop = Color.white.opacity(0.04)
private let cardOverlayBottom = Color.white.opacity(0.02)
private let borderTop = Color.white.opacity(0.15)
private let borderBottom = Color.white.opacity(0.05)

private var greenGradient: LinearGradient {
    LinearGradient(
        colors: [promoGreen, promoGreenDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Glass Card Background Modifier

private struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 20
    var borderGradient: LinearGradient? = nil

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(cardBackground)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [cardOverlayTop, cardOverlayBottom],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        borderGradient ?? LinearGradient(
                            colors: [borderTop, borderBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
    }
}

extension View {
    func glassCard(
        cornerRadius: CGFloat = 20,
        borderGradient: LinearGradient? = nil
    ) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, borderGradient: borderGradient))
    }
}

// MARK: - Promo Banner Card (for OverviewView)

struct PromoBannerCard: View {
    @ObservedObject var viewModel: PromosViewModel
    @State private var appeared = false

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                NavigationLink {
                    PromosView(viewModel: viewModel)
                } label: {
                    bannerSkeleton
                }
                .buttonStyle(.plain)
            case .success(let data) where data.isReady && data.dealCount > 0:
                bannerContent(data)
            case .success(let data):
                NavigationLink {
                    PromosView(viewModel: viewModel)
                } label: {
                    debugBanner(bannerMessage(for: data))
                }
                .buttonStyle(.plain)
            case .error:
                // Error — tappable to open PromosView & retry
                NavigationLink {
                    PromosView(viewModel: viewModel)
                } label: {
                    debugBanner("Couldn't load deals — tap to retry")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func debugBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "tag.fill")
                .font(.system(size: 16))
                .foregroundColor(.orange)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(2)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(14)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(white: 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }

    private func bannerMessage(for data: PromoRecommendationResponse) -> String {
        switch data.reportStatus {
        case .ready:
            return "No deals this week — tap to open your weekly report"
        case .noEnrichedProfile:
            return "Keep scanning receipts to unlock weekly deals"
        case .noReportAvailable:
            return "This week's report isn't ready yet"
        }
    }

    private func bannerContent(_ data: PromoRecommendationResponse) -> some View {
        NavigationLink {
            PromosView(viewModel: viewModel)
        } label: {
            HStack(spacing: 12) {
                // Green accent icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [promoGreen.opacity(0.25), promoGreenDark.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)

                    Image(systemName: "tag.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(greenGradient)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 0) {
                        Text("\(data.dealCount) deals")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(greenGradient)
                        Text(" matched this week")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }

                    Text("across \(data.stores.count) stores")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(16)
            .contentShape(Rectangle())
            .glassCard(
                borderGradient: LinearGradient(
                    colors: [promoGreen.opacity(0.25), promoGreenDark.opacity(0.10)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        .buttonStyle(.plain)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                appeared = true
            }
        }
    }

    private var bannerSkeleton: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(promoGreen.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "tag.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(greenGradient)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("00 deals matched this week")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Text("across 0 stores")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(16)
        .glassCard(
            borderGradient: LinearGradient(
                colors: [promoGreen.opacity(0.25), promoGreenDark.opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .redacted(reason: .placeholder)
    }
}

// MARK: - Hero Card

struct PromoSummaryHeader: View {
    let stores: [PromoStore]
    @State private var appeared = false

    private var itemsWithImages: [PromoStoreItem] {
        stores.flatMap { $0.items.filter { $0.thumbnailUrl != nil } }
    }

    private var totalSavings: Double {
        itemsWithImages.reduce(0) { $0 + $1.savings }
    }

    private var dealCount: Int {
        itemsWithImages.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(format: "€%.2f", totalSavings))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(greenGradient)

            Text("in savings this week")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.5))

            HStack(spacing: 5) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(greenGradient)

                Text("Milo found \(dealCount) deals")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.35))
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                appeared = true
            }
        }
    }
}

// MARK: - Section Header

struct PromoSectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(greenGradient)
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .tracking(1.2)
                .foregroundColor(.white.opacity(0.5))
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Product Image View

struct PromoProductImageView: View {
    let url: String
    let size: CGFloat

    var body: some View {
        AsyncImage(url: URL(string: url)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            case .failure:
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: size * 0.3, weight: .light))
                            .foregroundColor(.white.opacity(0.15))
                    )
            case .empty:
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: size, height: size)
                    .redacted(reason: .placeholder)
            @unknown default:
                EmptyView()
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }
}

// MARK: - Skeleton Loading View (redacted placeholder)

struct PromoSkeletonView: View {
    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 12) {
            // Placeholder summary header
            VStack(alignment: .leading, spacing: 4) {
                Text("€00.00")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("potential savings this week")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)

            // Placeholder filter bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 90, height: 34)
                    }
                }
                .padding(.horizontal, 16)
            }

            // Placeholder product grid
            LazyVGrid(columns: gridColumns, spacing: 14) {
                ForEach(0..<6, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 0) {
                        // Image placeholder
                        RoundedRectangle(cornerRadius: 0)
                            .fill(Color(white: 0.15))
                            .frame(height: 140)

                        // Info placeholder
                        VStack(alignment: .leading, spacing: 5) {
                            Text("BRAND")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white.opacity(0.3))
                            Text("Product Name Here")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(height: 48, alignment: .topLeading)
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 80, height: 26)
                            Text("€0.00")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(promoGreen)
                            Spacer(minLength: 0)
                            HStack {
                                Text("0 days left")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.3))
                                Spacer()
                            }
                        }
                        .padding(10)
                    }
                    .frame(height: PromoProductCard.cardHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(white: 0.09))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
                }
            }
            .padding(.horizontal, 16)
        }
        .redacted(reason: .placeholder)
    }
}

// MARK: - Empty State

struct PromoEmptyView: View {
    let status: PromoReportStatus
    let title: String
    let message: String
    var onAddStores: (() -> Void)? = nil
    var onScanReceipt: (() -> Void)? = nil

    @State private var appeared = false
    @State private var iconPulse = false

    var body: some View {
        VStack(spacing: 20) {
            // Icon with animated glow
            ZStack {
                // Glow ring behind icon
                Circle()
                    .fill(accentColor.opacity(0.08))
                    .frame(width: 88, height: 88)
                    .scaleEffect(iconPulse ? 1.12 : 1.0)
                    .opacity(iconPulse ? 0.6 : 0.3)

                Circle()
                    .fill(Color(white: 0.08))
                    .frame(width: 72, height: 72)
                    .overlay(Circle().stroke(accentColor.opacity(0.2), lineWidth: 1))

                Image(systemName: iconName)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            // Status-specific hint
            if let hint = contextHint {
                HStack(spacing: 6) {
                    Image(systemName: hintIcon)
                        .font(.system(size: 11, weight: .semibold))
                    Text(hint)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(accentColor.opacity(0.7))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(accentColor.opacity(0.08))
                )
            }

            // CTA buttons
            ctaButton
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
        .glassCard()
        .padding(.horizontal, 16)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(0.5)) {
                iconPulse = true
            }
        }
    }

    // MARK: - Status-specific content

    private var subtitle: String {
        switch status {
        case .noReportAvailable:
            return "Milo is sniffing out the best deals for your stores. Your personalised report refreshes every week."
        case .noEnrichedProfile:
            return "Milo personalises deals based on your shopping habits. Scan a few receipts so he knows what you like!"
        case .ready:
            return message.isEmpty
                ? "No matching promotions this week across your selected stores. Milo will keep looking!"
                : message
        }
    }

    private var contextHint: String? {
        switch status {
        case .noReportAvailable:
            return "Usually ready by Monday"
        case .noEnrichedProfile:
            return "Scan 2–3 receipts to get started"
        case .ready:
            return nil
        }
    }

    private var hintIcon: String {
        switch status {
        case .noReportAvailable: return "clock"
        case .noEnrichedProfile: return "camera.viewfinder"
        case .ready: return "calendar"
        }
    }

    private var accentColor: Color {
        switch status {
        case .noReportAvailable: return Color(red: 0.40, green: 0.70, blue: 1.0)
        case .noEnrichedProfile: return promoGreen
        case .ready: return promoGold
        }
    }

    private var iconName: String {
        switch status {
        case .ready:
            return "pawprint.fill"
        case .noEnrichedProfile:
            return "doc.text.viewfinder"
        case .noReportAvailable:
            return "sparkle.magnifyingglass"
        }
    }

    @ViewBuilder
    private var ctaButton: some View {
        switch status {
        case .noEnrichedProfile:
            if let onScan = onScanReceipt {
                Button(action: onScan) {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Scan a Receipt")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(promoGreen))
                }
                .padding(.top, 4)
            }
        case .ready:
            if let onAdd = onAddStores {
                Button(action: onAdd) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Add More Stores")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(promoGreen)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().stroke(promoGreen, lineWidth: 1.5))
                }
                .padding(.top, 4)
            }
        case .noReportAvailable:
            EmptyView()
        }
    }
}

// MARK: - Error State

struct PromoErrorView: View {
    let message: String
    let onRetry: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.08))
                    .frame(width: 72, height: 72)
                    .overlay(Circle().stroke(Color.orange.opacity(0.2), lineWidth: 1))

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .orange.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("Couldn't load deals")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            Button(action: onRetry) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Try Again")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Capsule().fill(Color.orange))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
        .glassCard()
        .padding(.horizontal, 16)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }
}
