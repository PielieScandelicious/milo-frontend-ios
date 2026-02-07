//
//  SkeletonViews.swift
//  Scandalicious
//
//  Shimmer skeleton placeholders that replace ProgressView spinners.
//  These match the layout of real content so the transition feels like "filling in".
//

import SwiftUI

// MARK: - Shimmer Modifier

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .clear,
                            Color.white.opacity(0.08),
                            .clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: phase * geometry.size.width)
                }
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 2
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton Building Blocks

struct SkeletonRect: View {
    var width: CGFloat? = nil
    var height: CGFloat = 14
    var cornerRadius: CGFloat = 6

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.white.opacity(0.08))
            .frame(width: width, height: height)
    }
}

struct SkeletonCircle: View {
    var size: CGFloat = 40

    var body: some View {
        Circle()
            .fill(Color.white.opacity(0.08))
            .frame(width: size, height: size)
    }
}

// MARK: - Skeleton Store Row

struct SkeletonStoreRow: View {
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
                .frame(width: 50, height: 50)

            // Text lines
            VStack(alignment: .leading, spacing: 8) {
                SkeletonRect(width: 120, height: 16)
                SkeletonRect(width: 80, height: 12)
            }

            Spacer()

            // Amount
            SkeletonRect(width: 60, height: 20, cornerRadius: 8)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.03))
        )
        .shimmer()
    }
}

// MARK: - Skeleton Donut Chart

struct SkeletonDonutChart: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: 24)
                .frame(width: 160, height: 160)

            VStack(spacing: 4) {
                SkeletonRect(width: 60, height: 12)
                SkeletonRect(width: 80, height: 24, cornerRadius: 8)
                SkeletonRect(width: 50, height: 10)
            }
        }
        .frame(height: 200)
        .shimmer()
    }
}

// MARK: - Skeleton Receipt Card

struct SkeletonReceiptCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Store icon
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 6) {
                    SkeletonRect(width: 100, height: 16)
                    SkeletonRect(width: 70, height: 12)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    SkeletonRect(width: 50, height: 16)
                    SkeletonRect(width: 40, height: 12)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .shimmer()
    }
}

// MARK: - Skeleton Transaction Row

struct SkeletonTransactionRow: View {
    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
                .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 6) {
                SkeletonRect(width: 130, height: 16)
                SkeletonRect(width: 80, height: 12)
            }

            Spacer()

            SkeletonRect(width: 55, height: 18, cornerRadius: 8)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .shimmer()
    }
}

// MARK: - Skeleton Category Row

struct SkeletonCategoryRow: View {
    var body: some View {
        HStack(spacing: 12) {
            SkeletonCircle(size: 36)

            VStack(alignment: .leading, spacing: 6) {
                SkeletonRect(width: 100, height: 14)
                SkeletonRect(width: 60, height: 11)
            }

            Spacer()

            SkeletonRect(width: 50, height: 16, cornerRadius: 8)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .shimmer()
    }
}

// MARK: - Skeleton Budget Insights Card

struct SkeletonInsightsCard: View {
    var body: some View {
        VStack(spacing: 20) {
            // Score ring placeholder
            HStack(spacing: 24) {
                SkeletonCircle(size: 80)

                VStack(alignment: .leading, spacing: 10) {
                    SkeletonRect(width: 100, height: 18)
                    HStack(spacing: 12) {
                        SkeletonRect(width: 40, height: 14)
                        SkeletonRect(width: 40, height: 14)
                        SkeletonRect(width: 40, height: 14)
                    }
                }

                Spacer()
            }

            SkeletonRect(height: 1)

            // Metrics
            HStack(spacing: 0) {
                VStack(spacing: 6) {
                    SkeletonRect(width: 60, height: 11)
                    SkeletonRect(width: 50, height: 18)
                    SkeletonRect(width: 70, height: 11)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 6) {
                    SkeletonRect(width: 60, height: 11)
                    SkeletonRect(width: 50, height: 18)
                    SkeletonRect(width: 70, height: 11)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
        .shimmer()
    }
}

// MARK: - Composite Skeleton Views

struct SkeletonStoreList: View {
    var count: Int = 5

    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<count, id: \.self) { _ in
                SkeletonStoreRow()
            }
        }
    }
}

struct SkeletonReceiptList: View {
    var count: Int = 3

    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<count, id: \.self) { _ in
                SkeletonReceiptCard()
            }
        }
    }
}

struct SkeletonTransactionList: View {
    var count: Int = 5

    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { _ in
                SkeletonTransactionRow()
            }
        }
    }
}

struct SkeletonCategoryList: View {
    var count: Int = 5

    var body: some View {
        VStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { _ in
                SkeletonCategoryRow()
            }
        }
    }
}
