//
//  CouponStoreView.swift
//  Scandalicious
//
//  Created by Claude on 20/02/2026.
//

import SwiftUI

struct CouponStoreView: View {
    @ObservedObject private var gm = GamificationManager.shared
    @State private var selectedCoupon: Coupon? = nil
    @State private var showPurchaseConfirm = false
    @State private var purchaseError = false

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "tag.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(red: 0.45, green: 0.15, blue: 0.85))
                Text("Coupon Store")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Text(gm.wallet.formatted)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.0))
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Coupon.mockCoupons) { coupon in
                    CouponTileView(
                        coupon: coupon,
                        canAfford: gm.wallet.cents >= coupon.priceCents,
                        alreadyOwned: gm.ownedCoupons.contains(where: { $0.id == coupon.id })
                    ) {
                        selectedCoupon = coupon
                        showPurchaseConfirm = true
                    }
                }
            }
        }
        .padding(16)
        .glassCard()
        .confirmationDialog(
            "Redeem Coupon",
            isPresented: $showPurchaseConfirm,
            titleVisibility: .visible
        ) {
            if let c = selectedCoupon {
                Button("Buy for \(c.priceFormatted)") {
                    let success = gm.redeemCoupon(c)
                    if !success {
                        purchaseError = true
                    } else {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        } message: {
            if let c = selectedCoupon {
                Text("\(c.title) at \(c.storeName). Cost: \(c.priceFormatted)")
            }
        }
        .alert("Insufficient Balance", isPresented: $purchaseError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You don't have enough in your wallet for this coupon.")
        }
    }
}

// MARK: - Coupon Tile

private struct CouponTileView: View {
    let coupon: Coupon
    let canAfford: Bool
    let alreadyOwned: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            if !alreadyOwned && canAfford {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onTap()
            }
        }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(coupon.storeLogoColor.color)
                        .frame(width: 10, height: 10)
                    Text(coupon.storeName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                }

                Text(coupon.discountText)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(coupon.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)

                Spacer()

                Group {
                    if alreadyOwned {
                        Text("Owned")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(red: 0.2, green: 0.8, blue: 0.4))
                    } else {
                        Text(coupon.priceFormatted)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(canAfford
                                ? Color(red: 1.0, green: 0.84, blue: 0.0)
                                : .white.opacity(0.3))
                    }
                }
            }
            .padding(12)
            .frame(minHeight: 130)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(white: alreadyOwned ? 0.06 : 0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        alreadyOwned
                            ? Color(red: 0.2, green: 0.8, blue: 0.4).opacity(0.3)
                            : canAfford ? Color.white.opacity(0.12) : Color.white.opacity(0.05),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .opacity(alreadyOwned || canAfford ? 1.0 : 0.5)
    }
}
