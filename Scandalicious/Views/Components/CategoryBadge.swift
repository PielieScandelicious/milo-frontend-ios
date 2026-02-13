//
//  CategoryBadge.swift
//  Scandalicious
//

import SwiftUI

struct CategoryBadge: View {
    let category: ExpenseCategory
    var size: CGFloat = 32

    var body: some View {
        category.icon
            .frame(width: size * 0.55, height: size * 0.55)
            .foregroundStyle(category.color)
            .frame(width: size, height: size)
            .background(category.color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: size * 0.25))
    }
}

#Preview {
    VStack(spacing: 12) {
        ForEach(ExpenseCategory.allCases.prefix(10)) { category in
            HStack(spacing: 12) {
                CategoryBadge(category: category, size: 40)
                Text(category.displayName)
                    .font(.subheadline)
                Spacer()
            }
        }
    }
    .padding()
}
