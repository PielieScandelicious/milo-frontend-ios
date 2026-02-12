//
//  SyncLoadingView.swift
//  Scandalicious
//
//  Milo head loading screen — just the cute face with ambient glow.
//

import SwiftUI

struct SyncLoadingView: View {
    private let miloPurple = Color(red: 0.45, green: 0.15, blue: 0.85)
    private let miloPurpleLight = Color(red: 0.55, green: 0.25, blue: 0.95)

    @State private var appeared = false
    @State private var contentOpacity: Double = 0
    @State private var glowOpacity: Double = 0
    @State private var ringRotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var breathe: CGFloat = 0.97

    var body: some View {
        ZStack {
            Color(white: 0.05).ignoresSafeArea()

            // Ambient purple glow
            RadialGradient(
                colors: [miloPurple.opacity(0.25), miloPurple.opacity(0.06), .clear],
                center: .center,
                startRadius: 40,
                endRadius: 280
            )
            .ignoresSafeArea()
            .opacity(glowOpacity)

            ZStack {
                // Pulsing outer glow ring
                Circle()
                    .stroke(miloPurple.opacity(0.15), lineWidth: 1.5)
                    .frame(width: 160, height: 160)
                    .scaleEffect(pulseScale)
                    .opacity(Double(2 - pulseScale))

                // Rotating accent ring
                Circle()
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                miloPurple.opacity(0),
                                miloPurple.opacity(0.4),
                                miloPurpleLight.opacity(0.7),
                                miloPurple.opacity(0.4),
                                miloPurple.opacity(0),
                            ]),
                            center: .center
                        ),
                        lineWidth: 2.5
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(ringRotation))

                // Milo head with gentle breathing
                MiloHeadCanvas(size: 110)
                    .scaleEffect(breathe)
            }
            .opacity(contentOpacity)
        }
        .onAppear {
            guard !appeared else { return }
            appeared = true

            withAnimation(.easeOut(duration: 0.6)) {
                contentOpacity = 1
                glowOpacity = 1
            }

            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: false)) {
                pulseScale = 1.5
            }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                breathe = 1.03
            }
        }
        .onDisappear {
            appeared = false
            contentOpacity = 0
            glowOpacity = 0
            ringRotation = 0
            pulseScale = 1.0
            breathe = 0.97
        }
    }
}

// MARK: - Milo Head (Canvas)

/// The same Apple-style Dachshund head from the chat, rendered via Canvas.
private struct MiloHeadCanvas: View {
    let size: CGFloat

    var body: some View {
        Canvas { context, canvasSize in
            var renderer = MiloHeadRenderer(
                cx: canvasSize.width / 2,
                cy: canvasSize.height / 2,
                size: size
            )
            renderer.draw(in: &context)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Head Renderer

private struct MiloHeadRenderer {
    let cx: CGFloat
    let cy: CGFloat
    let size: CGFloat

    var u: CGFloat { size / 100 }

    // Palette
    let furDark = Color(red: 0.40, green: 0.22, blue: 0.11)
    let furMid = Color(red: 0.55, green: 0.33, blue: 0.16)
    let furLight = Color(red: 0.68, green: 0.45, blue: 0.24)
    let furHighlight = Color(red: 0.78, green: 0.58, blue: 0.36)
    let snoutTan = Color(red: 0.76, green: 0.56, blue: 0.35)
    let snoutLight = Color(red: 0.85, green: 0.68, blue: 0.48)
    let noseDark = Color(red: 0.18, green: 0.12, blue: 0.08)
    let eyeDark = Color(red: 0.10, green: 0.06, blue: 0.04)
    let tongue = Color(red: 0.92, green: 0.50, blue: 0.55)

    mutating func draw(in context: inout GraphicsContext) {
        drawEars(in: &context)
        drawHead(in: &context)
        drawSnout(in: &context)
        drawNose(in: &context)
        drawEyes(in: &context)
        drawBrows(in: &context)
        drawMouth(in: &context)
    }

    // MARK: - Ears

    func drawEars(in ctx: inout GraphicsContext) {
        for xSign: CGFloat in [-1, 1] {
            let ear = Path { p in
                p.move(to: CGPoint(x: cx + xSign * 18 * u, y: cy - 16 * u))
                p.addCurve(
                    to: CGPoint(x: cx + xSign * 44 * u, y: cy - 14 * u),
                    control1: CGPoint(x: cx + xSign * 24 * u, y: cy - 30 * u),
                    control2: CGPoint(x: cx + xSign * 42 * u, y: cy - 28 * u)
                )
                p.addCurve(
                    to: CGPoint(x: cx + xSign * 38 * u, y: cy + 20 * u),
                    control1: CGPoint(x: cx + xSign * 50 * u, y: cy - 2 * u),
                    control2: CGPoint(x: cx + xSign * 48 * u, y: cy + 14 * u)
                )
                p.addCurve(
                    to: CGPoint(x: cx + xSign * 28 * u, y: cy + 18 * u),
                    control1: CGPoint(x: cx + xSign * 34 * u, y: cy + 26 * u),
                    control2: CGPoint(x: cx + xSign * 30 * u, y: cy + 26 * u)
                )
                p.addCurve(
                    to: CGPoint(x: cx + xSign * 18 * u, y: cy - 16 * u),
                    control1: CGPoint(x: cx + xSign * 24 * u, y: cy + 6 * u),
                    control2: CGPoint(x: cx + xSign * 14 * u, y: cy - 4 * u)
                )
                p.closeSubpath()
            }
            ctx.fill(ear, with: .linearGradient(
                Gradient(colors: [furDark, furDark.opacity(0.8)]),
                startPoint: CGPoint(x: cx + xSign * 30 * u, y: cy - 24 * u),
                endPoint: CGPoint(x: cx + xSign * 36 * u, y: cy + 22 * u)
            ))
        }
    }

    // MARK: - Head

    func drawHead(in ctx: inout GraphicsContext) {
        let rect = CGRect(x: cx - 34 * u, y: cy - 30 * u, width: 68 * u, height: 64 * u)
        ctx.fill(Path(ellipseIn: rect), with: .linearGradient(
            Gradient(colors: [furLight, furMid]),
            startPoint: CGPoint(x: cx, y: cy - 30 * u),
            endPoint: CGPoint(x: cx, y: cy + 34 * u)
        ))
        // Top highlight
        let hl = CGRect(x: cx - 22 * u, y: cy - 28 * u, width: 44 * u, height: 30 * u)
        ctx.fill(Path(ellipseIn: hl), with: .linearGradient(
            Gradient(colors: [furHighlight.opacity(0.5), furHighlight.opacity(0)]),
            startPoint: CGPoint(x: cx, y: cy - 28 * u),
            endPoint: CGPoint(x: cx, y: cy - 5 * u)
        ))
    }

    // MARK: - Snout

    func drawSnout(in ctx: inout GraphicsContext) {
        let rect = CGRect(x: cx - 20 * u, y: cy + 2 * u, width: 40 * u, height: 30 * u)
        ctx.fill(Path(ellipseIn: rect), with: .linearGradient(
            Gradient(colors: [snoutLight, snoutTan]),
            startPoint: CGPoint(x: cx, y: cy + 2 * u),
            endPoint: CGPoint(x: cx, y: cy + 32 * u)
        ))
    }

    // MARK: - Nose

    func drawNose(in ctx: inout GraphicsContext) {
        let nW: CGFloat = 14 * u
        let nH: CGFloat = 10 * u
        let nY: CGFloat = cy + 4 * u
        let rect = CGRect(x: cx - nW / 2, y: nY, width: nW, height: nH)
        ctx.fill(Path(roundedRect: rect, cornerRadius: 5 * u), with: .linearGradient(
            Gradient(colors: [noseDark, noseDark.opacity(0.9)]),
            startPoint: CGPoint(x: cx, y: nY),
            endPoint: CGPoint(x: cx, y: nY + nH)
        ))
        // Shine
        let shine = CGRect(x: cx - 3.5 * u, y: nY + 1.5 * u, width: 7 * u, height: 4 * u)
        ctx.fill(Path(ellipseIn: shine), with: .color(.white.opacity(0.35)))
    }

    // MARK: - Eyes

    func drawEyes(in ctx: inout GraphicsContext) {
        let r: CGFloat = 7 * u
        let ey: CGFloat = cy - 8 * u
        let sp: CGFloat = 14 * u

        for xSign: CGFloat in [-1, 1] {
            let ex = cx + xSign * sp
            // Main eye
            let eyeRect = CGRect(x: ex - r, y: ey - r * 1.15, width: r * 2, height: r * 2.3)
            ctx.fill(Path(ellipseIn: eyeRect), with: .color(eyeDark))
            // Primary shine
            let s1 = CGRect(x: ex + 1.5 * u, y: ey - r * 0.7, width: 4 * u, height: 4 * u)
            ctx.fill(Path(ellipseIn: s1), with: .color(.white.opacity(0.85)))
            // Secondary shine
            let s2 = CGRect(x: ex - 2.5 * u, y: ey + 2 * u, width: 2.5 * u, height: 2.5 * u)
            ctx.fill(Path(ellipseIn: s2), with: .color(.white.opacity(0.4)))
        }
    }

    // MARK: - Brows

    func drawBrows(in ctx: inout GraphicsContext) {
        let ey: CGFloat = cy - 8 * u
        let sp: CGFloat = 14 * u

        for xSign: CGFloat in [-1, 1] {
            let ex = cx + xSign * sp
            var brow = Path()
            brow.move(to: CGPoint(x: ex - 8 * u, y: ey - 12 * u))
            brow.addQuadCurve(
                to: CGPoint(x: ex + 8 * u, y: ey - 11 * u),
                control: CGPoint(x: ex, y: ey - 16 * u)
            )
            ctx.stroke(brow, with: .color(furDark.opacity(0.5)),
                      style: StrokeStyle(lineWidth: 2 * u, lineCap: .round))
        }
    }

    // MARK: - Mouth

    func drawMouth(in ctx: inout GraphicsContext) {
        let my: CGFloat = cy + 18 * u
        var mouth = Path()
        mouth.move(to: CGPoint(x: cx - 7 * u, y: my))
        mouth.addQuadCurve(
            to: CGPoint(x: cx, y: my + 4 * u),
            control: CGPoint(x: cx - 3 * u, y: my + 5 * u)
        )
        mouth.addQuadCurve(
            to: CGPoint(x: cx + 7 * u, y: my),
            control: CGPoint(x: cx + 3 * u, y: my + 5 * u)
        )
        ctx.stroke(mouth, with: .color(furDark.opacity(0.6)),
                  style: StrokeStyle(lineWidth: 1.8 * u, lineCap: .round))

        // Tongue (proper shape — narrow top, round bottom)
        let tTop = my + 1 * u
        let tBot = my + 12 * u
        let tonguePath = Path { p in
            p.move(to: CGPoint(x: cx - 3.5 * u, y: tTop))
            p.addCurve(
                to: CGPoint(x: cx, y: tBot),
                control1: CGPoint(x: cx - 6 * u, y: tTop + 4 * u),
                control2: CGPoint(x: cx - 6 * u, y: tBot)
            )
            p.addCurve(
                to: CGPoint(x: cx + 3.5 * u, y: tTop),
                control1: CGPoint(x: cx + 6 * u, y: tBot),
                control2: CGPoint(x: cx + 6 * u, y: tTop + 4 * u)
            )
            p.closeSubpath()
        }
        ctx.fill(tonguePath, with: .color(Color(red: 0.88, green: 0.25, blue: 0.30)))
        var crease = Path()
        crease.move(to: CGPoint(x: cx, y: tTop + 1.5 * u))
        crease.addLine(to: CGPoint(x: cx, y: tBot - 2.5 * u))
        ctx.stroke(crease, with: .color(Color(red: 0.72, green: 0.18, blue: 0.22).opacity(0.4)),
                  style: StrokeStyle(lineWidth: 1 * u, lineCap: .round))
        let thl = CGRect(x: cx - 1.5 * u, y: tTop + 2 * u, width: 3 * u, height: 4 * u)
        ctx.fill(Path(ellipseIn: thl), with: .color(Color(red: 0.95, green: 0.42, blue: 0.45).opacity(0.45)))
    }
}

#Preview {
    SyncLoadingView()
}
