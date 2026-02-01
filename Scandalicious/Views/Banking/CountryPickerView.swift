//
//  CountryPickerView.swift
//  Scandalicious
//
//  Created by Claude on 01/02/2026.
//

import SwiftUI

struct CountryPickerView: View {
    @ObservedObject var viewModel: BankingViewModel
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "globe.europe.africa.fill")
                            .font(.system(size: 48))
                            .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))

                        Text("Select Your Country")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)

                        Text("Choose the country where your bank is located")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)

                    // Country Grid
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(BankingCountry.supportedCountries) { country in
                            CountryCard(
                                country: country,
                                isSelected: viewModel.selectedCountry.code == country.code,
                                onTap: {
                                    viewModel.selectCountryAndShowBanks(country)
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 40)
            }
            .background(Color(white: 0.08))
            .navigationTitle("Select Country")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Country Card

struct CountryCard: View {
    let country: BankingCountry
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: 8) {
                Text(country.flag)
                    .font(.system(size: 40))

                Text(country.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: isSelected ? 0.2 : 0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? Color(red: 0.3, green: 0.7, blue: 1.0) : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CountryPickerView(viewModel: BankingViewModel())
}
