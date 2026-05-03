//
//  CashbackCategoryFilterBar.swift
//  Scandalicious
//
//  Horizontal-scroll chip strip for filtering brand cashback deals by category.
//  Mirrors the backend `category` enum: food / drinks / household / personal_care
//  / baby / pet / other. "All" is the synthetic default.
//

import SwiftUI

struct CashbackCategoryFilterBar: View {
    @Binding var selected: CashbackCategory
    let availableCategories: Set<CashbackCategory>

    private static let cashbackGreen = Color(red: 0.25, green: 0.90, blue: 0.55)

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CashbackCategory.displayOrder, id: \.self) { cat in
                    if cat == .all || availableCategories.contains(cat) {
                        chip(cat)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }

    private func chip(_ cat: CashbackCategory) -> some View {
        let isSelected = cat == selected
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selected = cat
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 4) {
                if let symbol = cat.symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 10, weight: .bold))
                }
                Text(cat.label)
                    .font(.system(size: 12, weight: .heavy))
                    .tracking(0.4)
            }
            .foregroundStyle(isSelected ? .black : .white.opacity(0.65))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(
                    isSelected
                        ? AnyShapeStyle(Self.cashbackGreen)
                        : AnyShapeStyle(Color.white.opacity(0.06))
                )
            )
            .overlay(
                Capsule().stroke(
                    isSelected ? .clear : .white.opacity(0.08),
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Category enum

enum CashbackCategory: String, Hashable, CaseIterable {
    case all
    case food
    case drinks
    case household
    case personalCare = "personal_care"
    case baby
    case pet
    case other

    static let displayOrder: [CashbackCategory] = [
        .all, .food, .drinks, .household, .personalCare, .baby, .pet, .other,
    ]

    var label: String {
        switch self {
        case .all: return "All"
        case .food: return "Food"
        case .drinks: return "Drinks"
        case .household: return "Household"
        case .personalCare: return "Personal Care"
        case .baby: return "Baby"
        case .pet: return "Pet"
        case .other: return "Other"
        }
    }

    var symbol: String? {
        switch self {
        case .all: return nil
        case .food: return "fork.knife"
        case .drinks: return "cup.and.saucer.fill"
        case .household: return "house.fill"
        case .personalCare: return "drop.fill"
        case .baby: return "figure.and.child.holdinghands"
        case .pet: return "pawprint.fill"
        case .other: return "tag.fill"
        }
    }

    static func from(_ raw: String?) -> CashbackCategory {
        guard let raw else { return .other }
        return CashbackCategory(rawValue: raw) ?? .other
    }
}
