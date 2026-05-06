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
    /// Optional per-category counts shown as a small mono badge on the chip.
    /// When nil, the chip renders without a count.
    var counts: [CashbackCategory: Int] = [:]

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
        let count = counts[cat]
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selected = cat
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 6) {
                Text(cat.label)
                    .font(CashbackFont.sans(13, weight: .medium))
                    .kerning(-0.1)
                if let count {
                    Text("\(count)")
                        .font(CashbackFont.mono(11, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(
                            isSelected
                                ? Color(red: 0.043, green: 0.043, blue: 0.055).opacity(0.45)
                                : CashbackTokens.text40
                        )
                }
            }
            .foregroundStyle(
                isSelected
                    ? Color(red: 0.043, green: 0.043, blue: 0.055)
                    : CashbackTokens.text70
            )
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(
                    isSelected
                        ? AnyShapeStyle(Color.white)
                        : AnyShapeStyle(Color.white.opacity(0.06))
                )
            )
            .overlay(
                Capsule().stroke(
                    isSelected ? .clear : CashbackTokens.cardStroke,
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
