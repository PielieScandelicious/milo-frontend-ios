//
//  MyCouponsView.swift
//  Scandalicious
//
//  Created by Claude on 20/02/2026.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct MyCouponsView: View {
    @ObservedObject private var gm = GamificationManager.shared
    @State private var expandedCouponId: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("My Coupons")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)

            ForEach(gm.ownedCoupons) { coupon in
                OwnedCouponRow(
                    coupon: coupon,
                    isExpanded: expandedCouponId == coupon.id
                ) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        expandedCouponId = expandedCouponId == coupon.id ? nil : coupon.id
                    }
                }
            }
        }
        .padding(16)
        .glassCard()
    }
}

// MARK: - Owned Coupon Row

private struct OwnedCouponRow: View {
    let coupon: Coupon
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(coupon.storeLogoColor.color.opacity(0.2))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text(String(coupon.storeName.prefix(1)))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(coupon.storeLogoColor.color)
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(coupon.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(coupon.storeName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(12)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 12) {
                    if let qrImage = generateQRCode(from: coupon.qrPayload) {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 150, height: 150)
                            .padding(16)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Text("Show this QR code at checkout")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.bottom, 16)
                .transition(.opacity)
            }
        }
        .background(Color(white: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
