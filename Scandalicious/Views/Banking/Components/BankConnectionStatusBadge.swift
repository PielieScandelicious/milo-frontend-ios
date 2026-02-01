//
//  BankConnectionStatusBadge.swift
//  Scandalicious
//
//  Created by Claude on 01/02/2026.
//

import SwiftUI

struct BankConnectionStatusBadge: View {
    let status: BankConnectionStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.system(size: 10))

            Text(status.displayText)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(status.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.15))
        .clipShape(Capsule())
    }
}

#Preview {
    VStack(spacing: 12) {
        BankConnectionStatusBadge(status: .active)
        BankConnectionStatusBadge(status: .pending)
        BankConnectionStatusBadge(status: .expired)
        BankConnectionStatusBadge(status: .error)
        BankConnectionStatusBadge(status: .revoked)
    }
    .padding()
    .background(Color(white: 0.08))
}
