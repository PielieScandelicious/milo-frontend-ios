//
//  ConfettiView.swift
//  Scandalicious
//
//  Created by Claude on 20/02/2026.
//

import SwiftUI

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []

    private let colors: [Color] = [
        Color(red: 0.45, green: 0.15, blue: 0.85),
        Color(red: 1.0, green: 0.84, blue: 0.0),
        Color(red: 0.2, green: 0.8, blue: 0.4),
        Color(red: 1.0, green: 0.3, blue: 0.5),
        Color(red: 0.3, green: 0.7, blue: 1.0),
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    ConfettiPiece(particle: p, screenHeight: geo.size.height)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear { generateParticles() }
    }

    private func generateParticles() {
        particles = (0..<80).map { _ in
            ConfettiParticle(
                x: CGFloat.random(in: 0.05...0.95),
                color: colors.randomElement()!,
                size: CGFloat.random(in: 6...12),
                delay: Double.random(in: 0...0.4),
                duration: Double.random(in: 1.5...2.5),
                rotation: Double.random(in: 0...720),
                xDrift: CGFloat.random(in: -60...60)
            )
        }
    }
}

private struct ConfettiParticle: Identifiable {
    let id = UUID()
    let x: CGFloat
    let color: Color
    let size: CGFloat
    let delay: Double
    let duration: Double
    let rotation: Double
    let xDrift: CGFloat
}

private struct ConfettiPiece: View {
    let particle: ConfettiParticle
    let screenHeight: CGFloat

    @State private var offsetY: CGFloat = -20
    @State private var opacity: Double = 1

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(particle.color)
            .frame(width: particle.size, height: particle.size * 0.5)
            .rotation3DEffect(.degrees(particle.rotation), axis: (x: 1, y: 0.5, z: 0))
            .position(x: UIScreen.main.bounds.width * particle.x + particle.xDrift, y: offsetY)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeIn(duration: particle.duration).delay(particle.delay)) {
                    offsetY = screenHeight + 40
                }
                withAnimation(.linear(duration: 0.4).delay(particle.delay + particle.duration * 0.7)) {
                    opacity = 0
                }
            }
    }
}
