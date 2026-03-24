//
//  SpinWheelView.swift
//  Scandalicious
//
//  Created by Claude on 20/02/2026.
//

import SwiftUI

struct SpinWheelView: View {
    @ObservedObject private var gm = GamificationManager.shared
    @State private var rotation: Double = 90.0
    @State private var isSpinning = false
    @State private var spinResult: SpinResult? = nil
    @State private var showResult = false
    @State private var showConfetti = false
    @State private var showMysteryReveal = false
    @State private var mysteryRevealed = false
    @State private var showTestPanel = false
    @State private var pendingRespin = false
    @State private var mysteryCountValue: Double = 0
    @State private var mysteryCountDone = false
    @Environment(\.dismiss) private var dismiss

    private let segments = SpinSegment.segments
    private let wheelSize: CGFloat = min(UIScreen.main.bounds.width - 64, 320)

    private let gold = Color(red: 1.0, green: 0.84, blue: 0.0)

    private var canSpin: Bool {
        gm.spinTestMode || gm.spinsAvailable > 0 || pendingRespin
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(white: 0.04).ignoresSafeArea()

                // Subtle radial glow behind wheel
                RadialGradient(
                    colors: [gold.opacity(0.06), Color.clear],
                    center: .center, startRadius: 40, endRadius: 260
                )
                .ignoresSafeArea()

                if showConfetti { ConfettiView() }

                VStack(spacing: 24) {
                    // Double Next indicator
                    if gm.hasDoubleNext {
                        doubleNextBanner
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.8).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }

                    // Wheel + pointer
                    ZStack {
                        // Outer ring — subtle dark chrome
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color(white: 0.25), Color(white: 0.10), Color(white: 0.20)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 4
                            )
                            .frame(width: wheelSize + 10, height: wheelSize + 10)

                        WheelCanvas(segments: segments, rotation: rotation)
                            .frame(width: wheelSize, height: wheelSize)
                            .clipShape(Circle())

                        // Center hub
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color(white: 0.18), Color(white: 0.06)],
                                    center: .center, startRadius: 0, endRadius: 22
                                )
                            )
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .stroke(gold.opacity(0.3), lineWidth: 1.5)
                            )
                            .shadow(color: .black.opacity(0.5), radius: 6)

                        // Pointer at top
                        VStack(spacing: 0) {
                            PointerShape()
                                .fill(
                                    LinearGradient(
                                        colors: [gold, Color(red: 0.85, green: 0.65, blue: 0.0)],
                                        startPoint: .top, endPoint: .bottom
                                    )
                                )
                                .frame(width: 22, height: 30)
                                .shadow(color: gold.opacity(0.5), radius: 6, y: 2)
                                .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
                            Spacer()
                        }
                        .frame(height: wheelSize + 8)
                    }

                    spinButton

                    if let result = spinResult, showResult {
                        resultCard(result)
                            .transition(.scale(scale: 0.85).combined(with: .opacity))
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Mystery reveal overlay
                if showMysteryReveal, let result = spinResult {
                    mysteryRevealOverlay(result)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(white: 0.04), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                #if !PRODUCTION
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showTestPanel.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "ladybug.fill")
                                .font(.system(size: 16))
                            Text("Test")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(gm.spinTestMode ? .green : .white.opacity(0.7))
                    }
                }
                #endif
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .sheet(isPresented: $showTestPanel) {
                testModePanel
            }
        }
    }

    // MARK: - Double Next Banner

    private var doubleNextBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.yellow)
            Text("2x ACTIVE — Next cash win is doubled!")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.yellow.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )
        )
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }

    // MARK: - Spin Button

    private var spinButton: some View {
        Button {
            guard canSpin && !isSpinning else { return }
            startSpin()
        } label: {
            HStack(spacing: 8) {
                if !isSpinning {
                    Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                        .font(.system(size: 15, weight: .bold))
                }
                Text(isSpinning ? "Spinning..." : (pendingRespin ? "RE-SPIN" : (canSpin ? "SPIN" : "No Spins Left")))
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(canSpin && !isSpinning ? .black : .white.opacity(0.4))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        canSpin && !isSpinning
                            ? LinearGradient(
                                colors: [gold, Color(red: 0.9, green: 0.7, blue: 0.0)],
                                startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(
                                colors: [Color(white: 0.12), Color(white: 0.08)],
                                startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .shadow(color: gold.opacity(
                        isSpinning || !canSpin ? 0 : 0.3), radius: 12, y: 4)
            )
        }
        .buttonStyle(ScaleScanButtonStyle())
        .disabled(isSpinning || !canSpin)
    }

    // MARK: - Result Card

    private func resultCard(_ result: SpinResult) -> some View {
        let segment = segments[result.segmentIndex]
        let resultIcon: String = {
            switch SpinSegmentType(rawValue: result.segmentType) {
            case .jackpot: return "star.fill"
            case .mystery: return "gift.fill"
            case .tryAgain: return "arrow.counterclockwise"
            case .doubleNext: return "bolt.fill"
            default: return "checkmark"
            }
        }()

        let resultTitle: String = {
            switch SpinSegmentType(rawValue: result.segmentType) {
            case .jackpot: return "JACKPOT!"
            case .mystery: return "Mystery Cash!"
            case .tryAgain: return "Free Re-spin!"
            case .doubleNext: return "2x Next Win!"
            default: return "You won"
            }
        }()

        let resultLabel: String = {
            if result.cashValue > 0 {
                return String(format: "€%.2f", result.cashValue)
            }
            switch SpinSegmentType(rawValue: result.segmentType) {
            case .tryAgain: return "Spin again!"
            case .doubleNext: return "Next win doubled"
            default: return segment.label
            }
        }()

        let accentColor: Color = {
            switch SpinSegmentType(rawValue: result.segmentType) {
            case .jackpot: return gold
            case .mystery: return Color(red: 0.45, green: 0.15, blue: 0.85)
            case .tryAgain: return Color(red: 1.0, green: 0.3, blue: 0.5)
            case .doubleNext: return Color(red: 0.3, green: 0.7, blue: 1.0)
            default: return gold
            }
        }()

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: resultIcon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(resultTitle)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(accentColor.opacity(0.8))
                Text(resultLabel)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }

            Spacer()

            if result.cashValue > 0 {
                Text("Added")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color(white: 0.12)))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(accentColor.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Mystery Reveal Overlay

    private func mysteryRevealOverlay(_ result: SpinResult) -> some View {
        let purple = Color(red: 0.6, green: 0.2, blue: 1.0)

        return ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(purple.opacity(mysteryRevealed ? 0.2 : 0.05))
                        .frame(width: 120, height: 120)
                        .scaleEffect(mysteryRevealed ? 1.3 : 1.0)

                    Image(systemName: "gift.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(purple)
                        .scaleEffect(mysteryRevealed ? 1.15 : 1.0)
                        .shadow(color: purple.opacity(mysteryRevealed ? 0.6 : 0), radius: 20)
                }
                .animation(.easeOut(duration: 0.6), value: mysteryRevealed)

                if mysteryRevealed {
                    Text(String(format: "€%.2f", mysteryCountValue))
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: purple.opacity(mysteryCountDone ? 0.5 : 0), radius: 12)
                        .scaleEffect(mysteryCountDone ? 1.05 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: mysteryCountDone)
                        .transition(.opacity)

                    if mysteryCountDone && result.isDoubled {
                        Text("2x DOUBLED!")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundStyle(.yellow)
                            .transition(.scale(scale: 0.5).combined(with: .opacity))
                    }
                } else {
                    Text("Tap to reveal")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(1.5)
                        .textCase(.uppercase)
                }

                Spacer()
                Spacer()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !mysteryRevealed {
                withAnimation(.easeOut(duration: 0.3)) {
                    mysteryRevealed = true
                }
                startMysteryCount(target: result.cashValue)
            }
        }
    }

    private func startMysteryCount(target: Double) {
        mysteryCountValue = 0
        mysteryCountDone = false

        let totalDuration: Double = 2.0
        let steps = 40
        let tickGenerator = UIImpactFeedbackGenerator(style: .light)
        tickGenerator.prepare()

        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let eased = 1.0 - pow(1.0 - t, 3)
            let delay = eased * totalDuration

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                let progress = Double(i) / Double(steps)
                mysteryCountValue = target * progress

                if i % 4 == 0 && i < steps {
                    tickGenerator.impactOccurred(intensity: 0.3 + 0.4 * progress)
                }

                if i == steps {
                    mysteryCountValue = target
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                        mysteryCountDone = true
                    }
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3)) {
                        showResult = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showMysteryReveal = false
                        }
                    }
                }
            }
        }
    }

    // MARK: - Test Mode Panel

    private var testModePanel: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Test Mode (Infinite Spins)", isOn: $gm.spinTestMode)
                        .tint(.green)
                } header: {
                    Text("Mode")
                } footer: {
                    Text("Enables unlimited spins and force-segment controls. Only available in non-prod builds.")
                }

                if gm.spinTestMode {
                    Section("Force Specific Segment") {
                        // "Random" option
                        Button {
                            gm.forcedSegmentIndex = nil
                        } label: {
                            HStack {
                                Image(systemName: "dice.fill")
                                    .foregroundStyle(.white)
                                    .frame(width: 30)
                                Text("Random (normal behavior)")
                                    .foregroundStyle(.white)
                                Spacer()
                                if gm.forcedSegmentIndex == nil {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                        }

                        // Each segment as a button
                        ForEach(segments) { seg in
                            Button {
                                gm.forcedSegmentIndex = seg.id
                            } label: {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(seg.color)
                                        .frame(width: 12, height: 12)
                                    Text(seg.label)
                                        .foregroundStyle(.white)
                                        .font(.system(size: 15, weight: .semibold))
                                    Text("(\(seg.segmentType.rawValue))")
                                        .foregroundStyle(.white.opacity(0.5))
                                        .font(.system(size: 12))
                                    Spacer()
                                    if gm.forcedSegmentIndex == seg.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                    }
                                }
                            }
                        }
                    }

                    Section("Quick Test All") {
                        Button {
                            showTestPanel = false
                            runSequentialTest()
                        } label: {
                            HStack {
                                Image(systemName: "play.fill")
                                    .foregroundStyle(.green)
                                Text("Spin all 8 segments in sequence")
                                    .foregroundStyle(.white)
                            }
                        }
                    }

                    Section {
                        Toggle("Force 2x Active", isOn: Binding(
                            get: { gm.hasDoubleNext },
                            set: { _ in
                                gm.forcedSegmentIndex = 3 // DoubleNext segment
                            }
                        ))
                        .tint(.yellow)
                    } header: {
                        Text("Double Next Testing")
                    } footer: {
                        Text("Force a Double Next spin first, then test a cash segment to see the 2x effect.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(white: 0.06))
            .navigationTitle("Spin Test Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showTestPanel = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Sequential Test

    private func runSequentialTest() {
        guard gm.spinTestMode else { return }

        // Spin each segment in sequence with a delay
        var segIndex = 0
        func spinNext() {
            guard segIndex < segments.count else {
                gm.forcedSegmentIndex = nil
                return
            }
            gm.forcedSegmentIndex = segIndex
            segIndex += 1

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                startSpin()
                // Schedule next after this spin completes (4.5s animation + 2s result)
                DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) {
                    spinNext()
                }
            }
        }
        spinNext()
    }

    // MARK: - Spin Logic

    private func startSpin() {
        let respin = pendingRespin
        pendingRespin = false
        isSpinning = true
        showResult = false
        showConfetti = false
        showMysteryReveal = false
        mysteryRevealed = false
        mysteryCountValue = 0
        mysteryCountDone = false
        spinResult = nil

        Task {
            guard let result = await gm.spinWheel(isRespin: respin) else {
                isSpinning = false
                return
            }

            await MainActor.run {
                animateWheel(to: result)
            }
        }
    }

    private func animateWheel(to result: SpinResult) {
        let segCount = Double(segments.count)
        let segmentAngle = 360.0 / segCount
        let targetStop = 360.0 - (Double(result.segmentIndex) + 0.5) * segmentAngle
        let currentNormalized = rotation.truncatingRemainder(dividingBy: 360.0)
        let extra = targetStop - currentNormalized
        let fullSpins = Double(Int.random(in: 5...8)) * 360.0
        let totalSpin = fullSpins + extra

        withAnimation(.timingCurve(0.15, 0.85, 0.1, 1.0, duration: 4.5)) {
            rotation += totalSpin
        }

        startTickHaptics(duration: 4.5)

        DispatchQueue.main.asyncAfter(deadline: .now() + 4.6) {
            spinResult = result
            isSpinning = false

            // Sync wallet, spins, and double-next now that wheel has stopped
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                gm.applySpinResult(result)
            }

            UINotificationFeedbackGenerator().notificationOccurred(.success)

            let segType = SpinSegmentType(rawValue: result.segmentType)

            // Mystery: show reveal overlay — result card shown only after user taps to reveal
            if segType == .mystery {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showMysteryReveal = true
                }
            } else if segType == .doubleNext {
                // No result card for 2x — the banner is enough
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15)) {
                    showResult = true
                }
            }

            // Confetti for jackpot or €2+
            if result.isJackpot || result.cashValue >= 2.0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showConfetti = true
                }
            }

            // Try Again: set pending respin so user can manually tap RE-SPIN
            if segType == .tryAgain {
                pendingRespin = true
            }
        }
    }

    private func startTickHaptics(duration: TimeInterval) {
        let tickGenerator = UIImpactFeedbackGenerator(style: .light)
        tickGenerator.prepare()
        let totalTicks = 30
        for i in 0..<totalTicks {
            let t = Double(i) / Double(totalTicks)
            let eased = 1.0 - pow(1.0 - t, 3)
            let delay = eased * duration * 0.95
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                tickGenerator.impactOccurred()
            }
        }
    }
}

// MARK: - Wheel Canvas

private struct WheelCanvas: View {
    let segments: [SpinSegment]
    let rotation: Double

    // Alternating dark tones
    private let sliceColors: [Color] = [
        Color(white: 0.12),
        Color(white: 0.06),
    ]

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2
            let sliceAngle = 2.0 * .pi / Double(segments.count)

            for segment in segments {
                let startAngle = Double(segment.id) * sliceAngle - .pi / 2
                let endAngle = startAngle + sliceAngle
                let midAngle = startAngle + sliceAngle / 2.0

                // --- Slice fill ---
                var segPath = Path()
                segPath.move(to: center)
                segPath.addArc(center: center, radius: radius,
                               startAngle: Angle(radians: startAngle),
                               endAngle: Angle(radians: endAngle), clockwise: false)
                segPath.closeSubpath()
                context.fill(segPath, with: .color(sliceColors[segment.id % 2]))

                // Thin colored line along outer edge
                var arcPath = Path()
                arcPath.addArc(center: center, radius: radius - 1.5,
                               startAngle: Angle(radians: startAngle + 0.03),
                               endAngle: Angle(radians: endAngle - 0.03), clockwise: false)
                context.stroke(arcPath, with: .color(segment.color.opacity(0.4)), lineWidth: 3)

                // Separator line
                var linePath = Path()
                linePath.move(to: center)
                linePath.addLine(to: CGPoint(
                    x: center.x + cos(startAngle) * radius,
                    y: center.y + sin(startAngle) * radius
                ))
                context.stroke(linePath, with: .color(.white.opacity(0.06)), lineWidth: 1)

                // --- Icon near outer edge ---
                if let iconName = segment.icon {
                    let iconDist = radius * 0.82
                    let iconPt = CGPoint(
                        x: center.x + cos(midAngle) * iconDist,
                        y: center.y + sin(midAngle) * iconDist
                    )

                    context.drawLayer { ctx in
                        ctx.translateBy(x: iconPt.x, y: iconPt.y)
                        let iconAngleDeg = midAngle * 180 / .pi + 90
                        let iconVisualAngle = midAngle + 90.0 * .pi / 180.0
                        let iconRotation = cos(iconVisualAngle) < 0 ? iconAngleDeg + 180 : iconAngleDeg
                        ctx.rotate(by: Angle(degrees: iconRotation))
                        let icon = Text(Image(systemName: iconName))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(segment.color.opacity(0.5))
                        ctx.draw(icon, at: .zero)
                    }
                }

                // --- Label text (radial: reading outward from center) ---
                let labelDist = radius * 0.52
                let labelPt = CGPoint(
                    x: center.x + cos(midAngle) * labelDist,
                    y: center.y + sin(midAngle) * labelDist
                )

                context.drawLayer { ctx in
                    ctx.translateBy(x: labelPt.x, y: labelPt.y)
                    // Flip labels on the visual left side so they read correctly
                    // Account for the wheel's initial 90° rotation offset
                    let angleDeg = midAngle * 180 / .pi
                    let visualAngle = midAngle + 90.0 * .pi / 180.0
                    let textRotation = cos(visualAngle) < 0 ? angleDeg + 180 : angleDeg
                    ctx.rotate(by: Angle(degrees: textRotation))

                    let text = Text(segment.label)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(segment.color)
                    ctx.draw(text, at: .zero)
                }
            }
        }
        .rotationEffect(.degrees(rotation))
    }
}

// MARK: - Scale Scan Button Style

struct ScaleScanButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Pointer Shape

private struct PointerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tipY = rect.maxY
        let topY = rect.minY
        let midX = rect.midX
        let halfW = rect.width / 2

        path.move(to: CGPoint(x: midX, y: tipY))
        path.addLine(to: CGPoint(x: midX - halfW, y: topY))
        path.addQuadCurve(
            to: CGPoint(x: midX + halfW, y: topY),
            control: CGPoint(x: midX, y: topY + rect.height * 0.25)
        )
        path.closeSubpath()
        return path
    }
}
