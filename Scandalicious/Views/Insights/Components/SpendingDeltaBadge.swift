//
//  SpendingDeltaBadge.swift
//  Scandalicious
//
//  Created by Claude on 23/02/2026.
//

import SwiftUI

struct SpendingDeltaBadge: View {
    let percentage: Double

    private var isDecrease: Bool { percentage < 0 }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: isDecrease ? "arrow.down.right" : "arrow.up.right")
                .font(.system(size: 11, weight: .bold))
            Text(String(format: "%.1f%% vs last month", abs(percentage)))
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(isDecrease ? Color.green : Color.red.opacity(0.9))
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill((isDecrease ? Color.green : Color.red).opacity(0.12))
        )
    }
}
