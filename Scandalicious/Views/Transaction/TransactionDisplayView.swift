//
//  TransactionDisplayView.swift
//  Dobby
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import SwiftUI

enum DisplayStyle: String, CaseIterable {
    case list = "List"
    case table = "Table"
    
    var icon: String {
        switch self {
        case .list: return "rectangle.grid.1x2.fill"
        case .table: return "tablecells.fill"
        }
    }
}

struct TransactionDisplayView: View {
    let storeName: String
    let period: String
    let category: String?
    let categoryColor: Color?
    
    @State private var displayStyle: DisplayStyle = .list
    
    var body: some View {
        ZStack {
            Color(white: 0.05).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Style picker
                stylePicker
                
                // Content based on style
                Group {
                    if displayStyle == .list {
                        TransactionListView(
                            storeName: storeName,
                            period: period,
                            category: category,
                            categoryColor: categoryColor
                        )
                    } else {
                        TransactionTableView(
                            storeName: storeName,
                            period: period,
                            category: category
                        )
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(category ?? storeName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(period)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
    }
    
    private var stylePicker: some View {
        HStack(spacing: 0) {
            ForEach(DisplayStyle.allCases, id: \.self) { style in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        displayStyle = style
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: style.icon)
                            .font(.system(size: 14, weight: .semibold))
                        
                        Text(style.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(displayStyle == style ? .black : .white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(displayStyle == style ? Color.white : Color.clear)
                    )
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    NavigationStack {
        TransactionDisplayView(
            storeName: "COLRUYT",
            period: "January 2026",
            category: "Meat & Fish",
            categoryColor: Color(red: 0.9, green: 0.4, blue: 0.4)
        )
    }
    .preferredColorScheme(.dark)
}
