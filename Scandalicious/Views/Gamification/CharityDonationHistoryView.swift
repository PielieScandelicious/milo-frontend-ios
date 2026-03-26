//
//  CharityDonationHistoryView.swift
//  Scandalicious
//

import SwiftUI

struct CharityDonationHistoryView: View {
    @ObservedObject private var gm = GamificationManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.05).ignoresSafeArea()

                if gm.charityHistory.isEmpty {
                    emptyState
                } else {
                    donationList
                }
            }
            .navigationTitle("Donation History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Donation List

    private var donationList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                // Total donated banner
                if gm.charityTotalDonated > 0 {
                    totalBanner
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 8)
                }

                // Donations
                VStack(spacing: 1) {
                    ForEach(gm.charityHistory) { donation in
                        donationRow(donation)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer().frame(height: 40)
            }
        }
    }

    // MARK: - Total Banner

    private var totalBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.45, green: 0.15, blue: 0.85).opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: "heart.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(red: 0.45, green: 0.15, blue: 0.85))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Total Donated")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                Text(String(format: "€%.2f", gm.charityTotalDonated))
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }

            Spacer()

            Text("\(gm.charityHistory.count) donation\(gm.charityHistory.count == 1 ? "" : "s")")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(red: 0.45, green: 0.15, blue: 0.85).opacity(0.25), lineWidth: 1)
                )
        )
    }

    // MARK: - Donation Row

    @ViewBuilder
    private func donationRow(_ donation: CharityDonationItem) -> some View {
        HStack(spacing: 12) {
            // Status indicator dot
            Circle()
                .fill(donation.isTransferred ?
                    Color(red: 0.2, green: 0.78, blue: 0.45) :
                    Color(red: 1.0, green: 0.75, blue: 0.0))
                .frame(width: 8, height: 8)

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(donation.charityName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(formattedDate(donation.createdAt))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            // Amount + status badge
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "€%.2f", donation.amount))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                statusBadge(donation)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 4)
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    @ViewBuilder
    private func statusBadge(_ donation: CharityDonationItem) -> some View {
        if donation.isTransferred {
            HStack(spacing: 3) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 9))
                Text("Transferred")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(Color(red: 0.2, green: 0.78, blue: 0.45))
        } else {
            HStack(spacing: 3) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 9))
                Text("Pending")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(Color(red: 1.0, green: 0.75, blue: 0.0))
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.slash")
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(.white.opacity(0.2))
            Text("No donations yet")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
            Text("Your donation history will appear here")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.25))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Helpers

    private func formattedDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: iso) {
            return date.formatted(.dateTime.day().month(.abbreviated).year())
        }
        // Fallback without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: iso) {
            return date.formatted(.dateTime.day().month(.abbreviated).year())
        }
        return iso
    }
}
