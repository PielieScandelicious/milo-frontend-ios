//
//  SpinWheelView.swift
//  Scandalicious
//
//  Spin wheel supporting Standard (EV ~100 pts) and Premium (EV ~200 pts) wheels.
//

import SwiftUI

struct SpinWheelView: View {
    @ObservedObject private var gm = GamificationManager.shared
    @State private var selectedSpinType: SpinWheelType = .standard
    @State private var rotation: Double = 90.0
    @State private var isSpinning = false
    @State private var spinResult: SpinResult? = nil
    @State private var showResult = false
    @State private var showConfetti = false
    @State private var showMysteryReveal = false
    @State private var mysteryRevealed = false
    @State private var showTestPanel = false
    @State private var pendingRespin = false
    @State private var mysteryCountValue: Int = 0
    @State private var mysteryCountDone = false
    @Environment(\.dismiss) private var dismiss

    private let wheelSize: CGFloat = min(UIScreen.main.bounds.width - 64, 320)
    private let gold = Color(red: 1.0, green: 0.84, blue: 0.0)
    private let orange = Color(red: 1.0, green: 0.5, blue: 0.0)

    private var segments: [SpinSegment] { SpinSegment.segments(for: selectedSpinType) }

    private var canSpin: Bool {
        if gm.spinTestMode { return true }
        if pendingRespin { return true }
        return selectedSpinType == .premium ? gm.premiumSpins > 0 : gm.standardSpins > 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background — teal for standard, amber for premium
                Color(white: 0.04).ignoresSafeArea()

                RadialGradient(
                    colors: [wheelAccentColor.opacity(0.06), Color.clear],
                    center: .center, startRadius: 40, endRadius: 260
                )
                .ignoresSafeArea()

                if showConfetti { ConfettiView() }

                VStack(spacing: 20) {
                    spinsCounter

                    // Spin type selector (only when not spinning)
                    if !isSpinning {
                        spinTypeSelector
                    }

                    // Wheel + pointer
                    ZStack {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color(white: 0.25), Color(white: 0.10), Color(white: 0.20)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 4
                            )
                            .frame(width: wheelSize + 10, height: wheelSize + 10)

                        WheelCanvas(segments: segments, rotation: rotation, accentColor: wheelAccentColor)
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
                            .overlay(Circle().stroke(wheelAccentColor.opacity(0.3), lineWidth: 1.5))
                            .shadow(color: .black.opacity(0.5), radius: 6)

                        // Pointer
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
                            Image(systemName: "ladybug.fill").font(.system(size: 16))
                            Text("Test").font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(gm.spinTestMode ? .green : .white.opacity(0.7))
                    }
                }
                #endif
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Klaar") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .sheet(isPresented: $showTestPanel) { testModePanel }
        }
    }

    // MARK: - Accent color per wheel type

    private var wheelAccentColor: Color {
        selectedSpinType == .premium
            ? Color(red: 1.0, green: 0.7, blue: 0.1)
            : Color(red: 0.3, green: 0.75, blue: 1.0)
    }

    // MARK: - Spins Counter

    private var spinsCounter: some View {
        HStack(spacing: 12) {
            if gm.spinTestMode {
                Label("TEST MODE — Infinite spins", systemImage: "sparkle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.green)
            } else {
                // Standard spins pill
                spinCountPill(count: gm.standardSpins, type: .standard)
                spinCountPill(count: gm.premiumSpins, type: .premium)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(gm.spinTestMode ? Color.green.opacity(0.1) : Color(white: 0.08))
                .overlay(Capsule().stroke(gm.spinTestMode ? Color.green.opacity(0.3) : gold.opacity(0.15), lineWidth: 0.5))
        )
    }

    private func spinCountPill(count: Int, type: SpinWheelType) -> some View {
        let accent: Color = type == .premium
            ? Color(red: 1.0, green: 0.7, blue: 0.1)
            : Color(red: 0.3, green: 0.75, blue: 1.0)
        return HStack(spacing: 4) {
            Image(systemName: type == .premium ? "crown.fill" : "arrow.trianglehead.2.clockwise.rotate.90")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(accent)
            Text("\(count)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(count > 0 ? .white : .white.opacity(0.3))
        }
    }

    // MARK: - Spin Type Selector

    private var spinTypeSelector: some View {
        HStack(spacing: 0) {
            spinTypeTab(.standard)
            spinTypeTab(.premium)
        }
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.09)))
        .frame(maxWidth: 240)
    }

    private func spinTypeTab(_ type: SpinWheelType) -> some View {
        let isSelected = selectedSpinType == type
        let count = type == .premium ? gm.premiumSpins : gm.standardSpins
        let accentForType: Color = type == .premium
            ? Color(red: 1.0, green: 0.7, blue: 0.1)
            : Color(red: 0.3, green: 0.75, blue: 1.0)

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedSpinType = type
            }
        } label: {
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: type == .premium ? "crown.fill" : "arrow.trianglehead.2.clockwise.rotate.90")
                        .font(.system(size: 10, weight: .bold))
                    Text(type.displayName)
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(isSelected ? accentForType : .white.opacity(0.4))

                Text("EV ~\(type.evPoints) pts")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(isSelected ? 0.5 : 0.25))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? accentForType.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .disabled(gm.spinTestMode ? false : count == 0)
        .opacity(gm.spinTestMode || count > 0 ? 1 : 0.4)
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
                Text(isSpinning ? "Draaien..." : (pendingRespin ? "RE-SPIN" : (canSpin ? "SPIN" : "Geen Spins")))
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(canSpin && !isSpinning ? .black : .white.opacity(0.4))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        canSpin && !isSpinning
                            ? LinearGradient(colors: [gold, Color(red: 0.9, green: 0.7, blue: 0.0)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [Color(white: 0.12), Color(white: 0.08)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .shadow(color: gold.opacity(isSpinning || !canSpin ? 0 : 0.3), radius: 12, y: 4)
            )
        }
        .buttonStyle(ScaleScanButtonStyle())
        .disabled(isSpinning || !canSpin)
    }

    // MARK: - Result Card

    private func resultCard(_ result: SpinResult) -> some View {
        let segType = SpinSegmentType(rawValue: result.segmentType)

        let resultIcon: String = {
            switch segType {
            case .jackpot: return "star.fill"
            case .mystery: return "gift.fill"
            case .tryAgain: return "arrow.counterclockwise"
            default: return "checkmark"
            }
        }()

        let resultTitle: String = {
            switch segType {
            case .jackpot: return "JACKPOT!"
            case .mystery: return "Mystery Bonus!"
            case .tryAgain: return "Gratis Re-spin!"
            default: return "Je won"
            }
        }()

        let resultLabel: String = {
            if result.pointsValue > 0 {
                return "+\(result.pointsValue) pts"
            }
            switch segType {
            case .tryAgain: return "Spin opnieuw!"
            default: return segments[result.segmentIndex].label
            }
        }()

        let accentColor: Color = {
            switch segType {
            case .jackpot: return gold
            case .mystery: return Color(red: 0.45, green: 0.15, blue: 0.85)
            case .tryAgain: return Color(red: 1.0, green: 0.3, blue: 0.5)
            default: return wheelAccentColor
            }
        }()

        return HStack(spacing: 14) {
            ZStack {
                Circle().fill(accentColor.opacity(0.15)).frame(width: 44, height: 44)
                Image(systemName: resultIcon).font(.system(size: 18, weight: .bold)).foregroundStyle(accentColor)
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

            if result.pointsValue > 0 {
                Text("Toegevoegd")
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
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(accentColor.opacity(0.2), lineWidth: 1))
        )
    }

    // MARK: - Mystery Reveal Overlay

    private func mysteryRevealOverlay(_ result: SpinResult) -> some View {
        let purple = Color(red: 0.6, green: 0.2, blue: 1.0)
        let revealPoints = result.mysteryRevealValue ?? result.pointsValue

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
                    Text("+\(mysteryCountValue) pts")
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: purple.opacity(mysteryCountDone ? 0.5 : 0), radius: 12)
                        .scaleEffect(mysteryCountDone ? 1.05 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: mysteryCountDone)
                        .transition(.opacity)
                } else {
                    Text("Tik om te onthullen")
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
                withAnimation(.easeOut(duration: 0.3)) { mysteryRevealed = true }
                startMysteryCount(target: revealPoints)
            }
        }
    }

    private func startMysteryCount(target: Int) {
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
                mysteryCountValue = Int(Double(target) * Double(i) / Double(steps))
                if i % 4 == 0 && i < steps {
                    tickGenerator.impactOccurred(intensity: 0.3 + 0.4 * t)
                }
                if i == steps {
                    mysteryCountValue = target
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { mysteryCountDone = true }
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3)) { showResult = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation(.easeOut(duration: 0.3)) { showMysteryReveal = false }
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
                    Toggle("Test Mode (Infinite Spins)", isOn: $gm.spinTestMode).tint(.green)
                } header: { Text("Mode") } footer: {
                    Text("Enables unlimited spins and force-segment controls. Non-prod only.")
                }

                if gm.spinTestMode {
                    Section("Spin Type") {
                        ForEach(SpinWheelType.allCases, id: \.rawValue) { type in
                            Button {
                                withAnimation { selectedSpinType = type }
                            } label: {
                                HStack {
                                    Text(type.displayName).foregroundStyle(.white)
                                    Spacer()
                                    if selectedSpinType == type {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                    }
                                }
                            }
                        }
                    }

                    Section("Force Specific Segment") {
                        Button {
                            gm.forcedSegmentIndex = nil
                        } label: {
                            HStack {
                                Image(systemName: "dice.fill").foregroundStyle(.white).frame(width: 30)
                                Text("Random").foregroundStyle(.white)
                                Spacer()
                                if gm.forcedSegmentIndex == nil {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                }
                            }
                        }

                        ForEach(segments) { seg in
                            Button {
                                gm.forcedSegmentIndex = seg.id
                            } label: {
                                HStack(spacing: 12) {
                                    Circle().fill(seg.color).frame(width: 12, height: 12)
                                    Text(seg.label).foregroundStyle(.white).font(.system(size: 15, weight: .semibold))
                                    Text("(\(seg.segmentType.rawValue))").foregroundStyle(.white.opacity(0.5)).font(.system(size: 12))
                                    Spacer()
                                    if gm.forcedSegmentIndex == seg.id {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                    }
                                }
                            }
                        }
                    }

                    Section("Quick Test") {
                        Button {
                            showTestPanel = false
                            runSequentialTest()
                        } label: {
                            HStack {
                                Image(systemName: "play.fill").foregroundStyle(.green)
                                Text("Spin alle 8 segmenten").foregroundStyle(.white)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(white: 0.06))
            .navigationTitle("Spin Test Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Klaar") { showTestPanel = false } }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Sequential Test

    private func runSequentialTest() {
        guard gm.spinTestMode else { return }
        var segIndex = 0
        func spinNext() {
            guard segIndex < segments.count else { gm.forcedSegmentIndex = nil; return }
            gm.forcedSegmentIndex = segIndex
            segIndex += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                startSpin()
                DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) { spinNext() }
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
            guard let result = await gm.spinWheel(spinType: selectedSpinType, isRespin: respin) else {
                isSpinning = false
                return
            }
            await MainActor.run { animateWheel(to: result) }
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

        withAnimation(.timingCurve(0.15, 0.85, 0.1, 1.0, duration: 4.5)) { rotation += totalSpin }
        startTickHaptics(duration: 4.5)

        DispatchQueue.main.asyncAfter(deadline: .now() + 4.6) {
            spinResult = result
            isSpinning = false

            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                gm.applySpinResult(result)
            }

            UINotificationFeedbackGenerator().notificationOccurred(.success)

            let segType = SpinSegmentType(rawValue: result.segmentType)

            if segType == .mystery {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showMysteryReveal = true }
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15)) { showResult = true }
            }

            if result.isJackpot || result.pointsValue >= 500 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showConfetti = true }
            }

            if segType == .tryAgain { pendingRespin = true }
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
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { tickGenerator.impactOccurred() }
        }
    }
}

// MARK: - SpinWheelType CaseIterable

extension SpinWheelType: CaseIterable {
    public static var allCases: [SpinWheelType] { [.standard, .premium] }
}

// MARK: - Wheel Canvas

private struct WheelCanvas: View {
    let segments: [SpinSegment]
    let rotation: Double
    let accentColor: Color

    private let sliceColors: [Color] = [Color(white: 0.12), Color(white: 0.06)]

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2
            let sliceAngle = 2.0 * .pi / Double(segments.count)

            for segment in segments {
                let startAngle = Double(segment.id) * sliceAngle - .pi / 2
                let endAngle = startAngle + sliceAngle
                let midAngle = startAngle + sliceAngle / 2.0

                var segPath = Path()
                segPath.move(to: center)
                segPath.addArc(center: center, radius: radius,
                               startAngle: Angle(radians: startAngle),
                               endAngle: Angle(radians: endAngle), clockwise: false)
                segPath.closeSubpath()
                context.fill(segPath, with: .color(sliceColors[segment.id % 2]))

                var arcPath = Path()
                arcPath.addArc(center: center, radius: radius - 1.5,
                               startAngle: Angle(radians: startAngle + 0.03),
                               endAngle: Angle(radians: endAngle - 0.03), clockwise: false)
                context.stroke(arcPath, with: .color(segment.color.opacity(0.4)), lineWidth: 3)

                var linePath = Path()
                linePath.move(to: center)
                linePath.addLine(to: CGPoint(
                    x: center.x + cos(startAngle) * radius,
                    y: center.y + sin(startAngle) * radius
                ))
                context.stroke(linePath, with: .color(.white.opacity(0.06)), lineWidth: 1)

                if let iconName = segment.icon {
                    let iconDist = radius * 0.82
                    let iconPt = CGPoint(
                        x: center.x + cos(midAngle) * iconDist,
                        y: center.y + sin(midAngle) * iconDist
                    )
                    context.drawLayer { ctx in
                        ctx.translateBy(x: iconPt.x, y: iconPt.y)
                        let iconVisualAngle = midAngle + 90.0 * .pi / 180.0
                        let iconAngleDeg = midAngle * 180 / .pi + 90
                        let iconRotation = cos(iconVisualAngle) < 0 ? iconAngleDeg + 180 : iconAngleDeg
                        ctx.rotate(by: Angle(degrees: iconRotation))
                        let icon = Text(Image(systemName: iconName))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(segment.color.opacity(0.5))
                        ctx.draw(icon, at: .zero)
                    }
                }

                let labelDist = radius * 0.52
                let labelPt = CGPoint(
                    x: center.x + cos(midAngle) * labelDist,
                    y: center.y + sin(midAngle) * labelDist
                )
                context.drawLayer { ctx in
                    ctx.translateBy(x: labelPt.x, y: labelPt.y)
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
