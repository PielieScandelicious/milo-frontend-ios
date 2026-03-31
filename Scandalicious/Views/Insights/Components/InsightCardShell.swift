//
//  InsightCardShell.swift
//  Scandalicious
//
//  Created by Claude on 23/02/2026.
//

import SwiftUI

struct InsightCardShell<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color(white: 0.10))
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(
                            Color.white.opacity(0.06),
                            lineWidth: 0.5
                        )
                }
            )
            .padding(.horizontal, 16)
    }
}
