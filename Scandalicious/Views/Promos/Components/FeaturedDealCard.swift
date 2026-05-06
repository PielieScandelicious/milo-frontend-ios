//
//  FeaturedDealCard.swift
//  Scandalicious
//
//  168pt-wide tile used in the horizontal "FEATURED" rail. Photo block on
//  top with brand-logo disc + cashback chip; eyebrow + serif title below.
//

import SwiftUI

struct FeaturedDealCard: View {
    let deal: BrandCashbackDeal
    var onTap: () -> Void

    private static let width: CGFloat = 168
    private static let photoHeight: CGFloat = 110

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                photo
                metadata
            }
            .frame(width: Self.width, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(CashbackTokens.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(CashbackTokens.cardStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(FeaturedCardButtonStyle())
    }

    private var photo: some View {
        ZStack(alignment: .topLeading) {
            AsyncImage(url: deal.imageThumbUrl ?? deal.imageUrl) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Color(red: 0.957, green: 0.949, blue: 0.933)
                }
            }
            .frame(width: Self.width, height: Self.photoHeight)
            .clipped()

            BrandLogoDisc(
                brand: deal.brandName,
                logoURL: deal.brandLogoUrl,
                size: 28
            )
                .padding(8)

            VStack {
                HStack {
                    Spacer()
                    Text("FEATURED")
                        .font(CashbackFont.sans(9, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.black.opacity(0.65))
                        )
                        .padding(8)
                }
                Spacer()
                HStack {
                    Spacer()
                    CashbackChip(amount: deal.cashbackAmount, size: .small)
                        .padding(8)
                }
            }
        }
        .frame(width: Self.width, height: Self.photoHeight)
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(deal.brandName.uppercased())
                .font(CashbackFont.sans(9.5, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(CashbackTokens.text55)
                .lineLimit(1)
            Text(deal.productName)
                .font(CashbackFont.serif(16))
                .kerning(-0.3)
                .foregroundStyle(.white)
                .lineSpacing(1)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.top, 11)
        .padding(.bottom, 12)
        .frame(width: Self.width, alignment: .leading)
    }
}

private struct FeaturedCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
    }
}
