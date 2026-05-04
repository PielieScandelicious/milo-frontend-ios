//
//  BrandCashbackEarningRow.swift
//  Scandalicious
//
//  One earning event in the wallet's earnings feed.
//

import SwiftUI

struct BrandCashbackEarningRow: View {
    let event: BrandCashbackEarningEvent

    private let cashbackGreen = Color(red: 0.25, green: 0.90, blue: 0.55)

    var body: some View {
        HStack(spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 2) {
                Text(event.brandName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .lineLimit(1)
                Text(event.productName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(formattedDate)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer(minLength: 8)

            Text("+\(MoneyFormatter.eur(cents: event.cashbackEarnedCents))")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(cashbackGreen)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }

    private var thumbnail: some View {
        Group {
            if let url = event.imageThumbUrl {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var placeholder: some View {
        ZStack {
            Color.white.opacity(0.05)
            Image(systemName: "tag.fill")
                .font(.system(size: 16))
                .foregroundStyle(cashbackGreen.opacity(0.5))
        }
    }

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: event.earnedAt)
    }
}
