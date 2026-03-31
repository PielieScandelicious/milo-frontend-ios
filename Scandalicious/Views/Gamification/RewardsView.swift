//
//  RewardsView.swift
//  Scandalicious
//
//  Created by Claude on 20/02/2026.
//

import SwiftUI

struct RewardsView: View {
    @ObservedObject private var gm = GamificationManager.shared
    @State private var appeared = false
    @State private var contentOpacity: Double = 0

    private let headerGoldColor = Color(red: 0.18, green: 0.14, blue: 0.05)

    var body: some View {
        ZStack(alignment: .top) {
            Color(white: 0.05).ignoresSafeArea()

            // Gold gradient header
            GeometryReader { geo in
                LinearGradient(
                    stops: [
                        .init(color: headerGoldColor, location: 0.0),
                        .init(color: headerGoldColor.opacity(0.6), location: 0.3),
                        .init(color: Color(red: 0.12, green: 0.09, blue: 0.03).opacity(0.25), location: 0.55),
                        .init(color: Color.clear, location: 0.8)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: geo.size.height * 0.45 + geo.safeAreaInsets.top)
                .offset(y: -geo.safeAreaInsets.top)
                .allowsHitTesting(false)
            }
            .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Hero wallet card
                    WalletCardView()
                        .padding(.horizontal, 20)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)

                    // Referral card
                    ReferralCardView()
                        .padding(.horizontal, 20)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)

                    // Charity donations
                    CharityCardView()
                        .padding(.horizontal, 20)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)

                    // Withdraw cash
                    WithdrawCardView()
                        .padding(.horizontal, 20)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)

                    Spacer().frame(height: 100)
                }
                .padding(.top, 20)
            }

        }
        .navigationBarHidden(true)
        .opacity(contentOpacity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                contentOpacity = 1.0
            }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                appeared = true
            }
            gm.fetchAndSyncWallet()
        }
    }
}
