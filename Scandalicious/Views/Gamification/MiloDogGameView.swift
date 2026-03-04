//
//  MiloDogGameView.swift
//  milo-game-claude
//
//  Milo Dachshund Runner - Chrome Dino meets Snake
//  Tap to jump, hold to float. Eat candy to grow longer.
//  Longer body = harder to clear obstacles!
//

import SwiftUI

// MARK: - Colors (matching Milo app palette)

private let furBrown = Color(red: 0.60, green: 0.38, blue: 0.22)
private let furDark = Color(red: 0.45, green: 0.26, blue: 0.14)
private let furLight = Color(red: 0.70, green: 0.48, blue: 0.30)
private let noseBlack = Color(red: 0.12, green: 0.10, blue: 0.08)
private let tongueColor = Color(red: 0.90, green: 0.40, blue: 0.45)
private let grassColor = Color(red: 0.25, green: 0.60, blue: 0.28)
private let hydrantRed = Color(red: 0.75, green: 0.20, blue: 0.18)
private let coneOrange = Color(red: 0.95, green: 0.55, blue: 0.15)
private let rockGray = Color(red: 0.35, green: 0.33, blue: 0.30)
private let boneColor = Color(red: 0.95, green: 0.92, blue: 0.85)
private let boneShadow = Color(red: 0.80, green: 0.75, blue: 0.65)

// MARK: - Configuration

private enum Config {
    static let dogX: CGFloat = 80
    static let groundInset: CGFloat = 50
    static let jumpForce: CGFloat = 340
    static let normalGravity: CGFloat = 1500
    static let floatGravity: CGFloat = 450
    static let initialSpeed: CGFloat = 150
    static let segHistGap: Int = 4
    static let segVisualGap: CGFloat = 12
    static let historySize: Int = 400
    static let obstacleMinGap: CGFloat = 200
    static let obstacleRandomGap: CGFloat = 180
}

// MARK: - Types

private enum GamePhase { case idle, playing, gameOver }

private struct Obstacle: Identifiable {
    let id = UUID()
    var x: CGFloat
    let width: CGFloat
    let height: CGFloat
    let type: Int // 0=hydrant, 1=rock, 2=cone
}

private struct CandyItem: Identifiable {
    let id = UUID()
    var x: CGFloat
    let y: CGFloat // offset from ground (negative = above)
    var eaten: Bool = false
}

private struct ScorePop {
    var x: CGFloat
    var y: CGFloat
    var age: CGFloat = 0
}

// MARK: - Game State

@Observable
private class GameState {
    var phase: GamePhase = .idle
    var score: Int = 0
    var bonesCollected: Int = 0
    var highScore: Int = UserDefaults.standard.integer(forKey: "miloDogGameBoneHigh")

    // Dog physics
    var headY: CGFloat = 0
    var velocity: CGFloat = 0
    var isJumping = false

    // Snake body
    var segmentCount: Int = 2
    var yHistory = [CGFloat](repeating: 0, count: Config.historySize)
    var historyIdx: Int = 0

    // World
    var speed: CGFloat = Config.initialSpeed
    var obstacles: [Obstacle] = []
    var candies: [CandyItem] = []
    var pops: [ScorePop] = []
    var distSinceObstacle: CGFloat = 300
    var scrollOffset: CGFloat = 0
    var gameDistance: CGFloat = 0 // distance since game start (for difficulty)

    // Timing
    var walkTime: CGFloat = 0
    var lastTime: Double = 0
    var gameOverAge: CGFloat = 0
    var groundY: CGFloat = 200

    // Input
    var touching = false
    var viewWidth: CGFloat = 400
    var viewHeight: CGFloat = 260

    func segY(_ index: Int) -> CGFloat {
        let si = (historyIdx - 1) - index * Config.segHistGap
        guard si >= 0 else { return 0 }
        return yHistory[si % Config.historySize]
    }

    func tick(dt: CGFloat) {
        groundY = viewHeight - Config.groundInset
        walkTime += dt

        if phase == .idle {
            scrollOffset += 40 * dt
            return
        }
        if phase == .gameOver {
            gameOverAge += dt
            return
        }

        let grav: CGFloat = (touching && isJumping && velocity < 0)
            ? Config.floatGravity : Config.normalGravity

        if touching && !isJumping {
            velocity = -Config.jumpForce
            isJumping = true
        }
        velocity += grav * dt
        headY += velocity * dt
        if headY >= 0 { headY = 0; velocity = 0; isJumping = false }

        yHistory[historyIdx % Config.historySize] = headY
        historyIdx += 1

        let dx = speed * dt
        scrollOffset += dx
        gameDistance += dx
        distSinceObstacle += dx
        score = bonesCollected
        // Smooth start: ramp from idle speed (40) to full speed over ~1.5s
        let warmup = min(walkTime / 1.5, 1.0)
        let targetSpeed = Config.initialSpeed + 40 * log2(1 + gameDistance / 4000)
        speed = 40 + (targetSpeed - 40) * warmup

        for i in obstacles.indices { obstacles[i].x -= dx }
        obstacles.removeAll { $0.x < -60 }

        for i in candies.indices { candies[i].x -= dx }
        candies.removeAll { $0.x < -40 || $0.eaten }

        // Infinite difficulty: gentle logarithmic progress that never caps
        let progress = log2(1 + gameDistance / 8000)
        let minGap = max(55, Config.obstacleMinGap - progress * 30)
        let randGap = max(15, Config.obstacleRandomGap - progress * 35)
        let gap = minGap + CGFloat.random(in: 0...randGap)
        if distSinceObstacle > gap {
            let minH: CGFloat = 22 + progress * 6
            let maxH: CGFloat = min(42 + progress * 10, groundY - 20)
            obstacles.append(Obstacle(
                x: viewWidth + 30,
                width: CGFloat.random(in: 20...30),
                height: CGFloat.random(in: minH...maxH),
                type: Int.random(in: 0...2)
            ))
            distSinceObstacle = 0
        }

        let boneChance = 0.004 + min(progress, 3.0) * 0.003
        if CGFloat.random(in: 0...1) < boneChance * dt * 60 {
            if candies.allSatisfy({ $0.x < viewWidth - 120 }) {
                candies.append(CandyItem(
                    x: viewWidth + 30,
                    y: -CGFloat.random(in: 35...80)
                ))
            }
        }

        for i in candies.indices where !candies[i].eaten {
            let cx = candies[i].x, cy = groundY + candies[i].y
            let hx = Config.dogX + 18, hy = groundY + headY - 12
            if hypot(cx - hx, cy - hy) < 22 {
                candies[i].eaten = true
                // Cap segments so full dog (including tail) stays on screen
                let maxFit = Int((Config.dogX + 6 - 15) / Config.segVisualGap) + 1
                segmentCount = min(segmentCount + 1, maxFit)
                bonesCollected += 1
                pops.append(ScorePop(x: cx, y: cy))
            }
        }

        for i in pops.indices { pops[i].age += dt; pops[i].y -= 50 * dt }
        pops.removeAll { $0.age > 0.8 }

        checkCollisions()
    }

    private func checkCollisions() {
        for obs in obstacles {
            let oRect = CGRect(
                x: obs.x + 2, y: groundY - obs.height + 2,
                width: obs.width - 4, height: obs.height - 4
            )
            let dogGY = groundY - 16 // match visual offset
            let hRect = CGRect(
                x: Config.dogX + 6, y: dogGY + headY - 17,
                width: 22, height: 16
            )
            if hRect.intersects(oRect) { die(); return }

            for s in 1..<segmentCount {
                let sy = segY(s)
                let sx = Config.dogX + 6 - CGFloat(s) * Config.segVisualGap
                let sRect = CGRect(x: sx - 6, y: dogGY + sy - 5, width: 12, height: 10)
                if sRect.intersects(oRect) { die(); return }
            }
        }
    }

    func die() {
        phase = .gameOver
        gameOverAge = 0
        if score > highScore {
            highScore = score
            UserDefaults.standard.set(highScore, forKey: "miloDogGameBoneHigh")
        }
    }

    func reset() {
        phase = .playing
        score = 0
        bonesCollected = 0
        headY = 0
        velocity = 0
        isJumping = false
        segmentCount = 2
        yHistory = [CGFloat](repeating: 0, count: Config.historySize)
        historyIdx = 0
        speed = Config.initialSpeed
        obstacles = []
        candies = []
        pops = []
        distSinceObstacle = 300
        gameDistance = 0
        walkTime = 0
        lastTime = 0
        gameOverAge = 0
    }
}

// MARK: - Main View

struct MiloDogGameView: View {
    @State private var game = GameState()

    var body: some View {
        GameCanvas(game: game)
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if game.phase == .idle {
                            game.reset()
                        } else if game.phase == .gameOver && game.gameOverAge > 0.6 {
                            game.reset()
                        } else {
                            game.touching = true
                        }
                    }
                    .onEnded { _ in game.touching = false }
            )
    }
}

// Extracted to break generic type nesting depth
private struct GameCanvas: View {
    let game: GameState

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                let _ = tickGame(now: now, size: geo.size)

                Canvas { ctx, size in
                    drawBackground(ctx: ctx, size: size)
                    drawStores(ctx: ctx, size: size, time: now)
                    drawGrass(ctx: ctx, size: size)
                    drawObstacles(ctx: ctx)
                    drawBones(ctx: ctx, time: now)
                    drawDog(ctx: ctx, time: now)
                    drawPops(ctx: ctx)
                    drawUI(ctx: ctx, size: size, time: now)
                }
            }
        }
    }

    private func tickGame(now: Double, size: CGSize) {
        game.viewWidth = size.width
        game.viewHeight = size.height
        let dt = now - game.lastTime
        guard game.lastTime > 0, dt > 0, dt < 0.1 else {
            game.lastTime = now
            return
        }
        game.lastTime = now
        game.tick(dt: CGFloat(dt))
    }

    // MARK: - Drawing: Background & Ground

    private func drawBackground(ctx: GraphicsContext, size: CGSize) {
        let bg = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 20)
        ctx.fill(bg, with: .linearGradient(
            Gradient(colors: [Color(white: 0.08), Color(white: 0.03)]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)
        ))

        let gy = game.groundY
        let ground = Path { p in
            p.addRect(CGRect(x: 0, y: gy, width: size.width, height: size.height - gy))
        }
        ctx.fill(ground, with: .color(Color(white: 0.07)))

        let line = Path { p in
            p.move(to: CGPoint(x: 0, y: gy))
            p.addLine(to: CGPoint(x: size.width, y: gy))
        }
        ctx.stroke(line, with: .color(.white.opacity(0.08)), lineWidth: 1)
    }

    // MARK: - Drawing: Background Stores

    private func drawStores(ctx: GraphicsContext, size: CGSize, time: Double) {
        let gy = game.groundY
        let parallax = game.scrollOffset * 0.35
        let virtualW: CGFloat = 600

        // Store definitions: (xOffset, width, height, awningStyle)
        let stores: [(CGFloat, CGFloat, CGFloat, Int)] = [
            (30,  44, 55, 0),
            (140, 52, 38, 1),
            (270, 38, 48, 2),
            (390, 48, 42, 0),
            (510, 42, 52, 1),
        ]

        let awningColors: [Color] = [
            Color(red: 0.65, green: 0.18, blue: 0.15),
            Color(red: 0.12, green: 0.50, blue: 0.45),
            Color(red: 0.20, green: 0.55, blue: 0.22),
        ]

        for (sx, sw, sh, style) in stores {
            let bx = sx - parallax.truncatingRemainder(dividingBy: virtualW)
            let drawX = bx < -sw ? bx + virtualW : bx
            guard drawX < size.width + sw && drawX > -sw else { continue }

            let by = gy - sh

            // Building body
            ctx.fill(
                Path(roundedRect: CGRect(x: drawX, y: by, width: sw, height: sh),
                     cornerRadius: 2),
                with: .color(Color(white: 0.10 + Double(style) * 0.008))
            )

            // Roof cap
            ctx.fill(
                Path { p in
                    p.addRect(CGRect(x: drawX - 1, y: by, width: sw + 2, height: 3))
                },
                with: .color(.white.opacity(0.06))
            )

            // Awning
            let awColor = awningColors[style % awningColors.count]
            let awH: CGFloat = 8
            let awY = by + 12
            ctx.fill(
                Path(roundedRect: CGRect(x: drawX - 2, y: awY, width: sw + 4, height: awH),
                     cornerRadius: 1),
                with: .color(awColor.opacity(0.30))
            )
            // Scalloped bottom
            let scallops = Int(sw / 8)
            for sc in 0..<scallops {
                let scx = drawX + CGFloat(sc) * (sw / CGFloat(scallops)) + (sw / CGFloat(scallops)) * 0.5
                ctx.fill(
                    Path(ellipseIn: CGRect(x: scx - 3.5, y: awY + awH - 2, width: 7, height: 4)),
                    with: .color(awColor.opacity(0.25))
                )
            }

            // Windows
            let cols = max(2, Int(sw / 16))
            let rows = max(2, Int(sh / 22))
            let winW: CGFloat = 6, winH: CGFloat = 7
            let winColor = Color(red: 0.95, green: 0.82, blue: 0.45)
            for row in 0..<rows {
                let wy = by + 24 + CGFloat(row) * 14
                guard wy + winH < gy - 4 else { continue }
                for col in 0..<cols {
                    let wx = drawX + 6 + CGFloat(col) * ((sw - 12) / CGFloat(max(1, cols - 1)))
                    let flicker = sin(time * 0.8 + Double(row * 3 + col + style * 7))
                    let lit = (row + col + style) % 3 != 0
                    let alpha = lit ? (0.15 + flicker * 0.05) : 0.04
                    ctx.fill(
                        Path(roundedRect: CGRect(x: wx, y: wy, width: winW, height: winH),
                             cornerRadius: 1),
                        with: .color(winColor.opacity(alpha))
                    )
                }
            }

            // Door
            let doorW: CGFloat = 8, doorH: CGFloat = 13
            let doorX = drawX + (sw - doorW) * 0.5
            let doorY = gy - doorH
            ctx.fill(
                Path(roundedRect: CGRect(x: doorX, y: doorY, width: doorW, height: doorH),
                     cornerRadius: 1.5),
                with: .color(Color(white: 0.06))
            )
            // Door handle
            ctx.fill(
                Path(ellipseIn: CGRect(x: doorX + doorW - 3, y: doorY + doorH * 0.5, width: 1.5, height: 1.5)),
                with: .color(.white.opacity(0.12))
            )

            // Store sign glow
            ctx.fill(
                Path(roundedRect: CGRect(x: drawX + sw * 0.25, y: awY - 5, width: sw * 0.5, height: 4),
                     cornerRadius: 1),
                with: .color(awColor.opacity(0.18))
            )
        }
    }

    // MARK: - Drawing: Grass

    private func drawGrass(ctx: GraphicsContext, size: CGSize) {
        let gy = game.groundY
        let scroll = game.scrollOffset
        let t = game.walkTime

        let bladeSpacing: CGFloat = 18
        let scrollShift = scroll.truncatingRemainder(dividingBy: bladeSpacing)
        let globalStart = Int(scroll / bladeSpacing)
        for i in 0..<Int(size.width / bladeSpacing) + 2 {
            let baseX = CGFloat(i) * bladeSpacing - scrollShift
            let gi = globalStart + i // stable global index
            let h: CGFloat = 5 + CGFloat(abs(gi) % 5) * 2.5
            let sway = sin(t * 3 + CGFloat(gi) * 0.9) * 2.5
            let blade = Path { p in
                p.move(to: CGPoint(x: baseX, y: gy))
                p.addLine(to: CGPoint(x: baseX + sway, y: gy - h))
                p.addLine(to: CGPoint(x: baseX + 2, y: gy))
            }
            ctx.fill(blade, with: .color(grassColor.opacity(0.25 + Double(abs(gi) % 3) * 0.1)))
        }
    }

    // MARK: - Drawing: Obstacles

    private func drawObstacles(ctx: GraphicsContext) {
        let gy = game.groundY
        for obs in game.obstacles {
            switch obs.type {
            case 0: drawHydrant(ctx: ctx, obs: obs, gy: gy)
            case 1: drawRock(ctx: ctx, obs: obs, gy: gy)
            default: drawCone(ctx: ctx, obs: obs, gy: gy)
            }
        }
    }

    private func drawHydrant(ctx: GraphicsContext, obs: Obstacle, gy: CGFloat) {
        let body = Path(roundedRect: CGRect(
            x: obs.x + 4, y: gy - obs.height + 6,
            width: obs.width - 8, height: obs.height - 6
        ), cornerRadius: 3)
        ctx.fill(body, with: .color(hydrantRed))

        let cap = Path(roundedRect: CGRect(
            x: obs.x + 2, y: gy - obs.height,
            width: obs.width - 4, height: 8
        ), cornerRadius: 3)
        ctx.fill(cap, with: .color(hydrantRed.opacity(0.85)))

        let nub = Path(roundedRect: CGRect(
            x: obs.x, y: gy - obs.height + 12,
            width: obs.width, height: 5
        ), cornerRadius: 2)
        ctx.fill(nub, with: .color(hydrantRed.opacity(0.7)))
    }

    private func drawRock(ctx: GraphicsContext, obs: Obstacle, gy: CGFloat) {
        let rock = Path { p in
            let x = obs.x, w = obs.width, h = obs.height
            p.move(to: CGPoint(x: x + w * 0.1, y: gy))
            p.addCurve(
                to: CGPoint(x: x + w * 0.5, y: gy - h),
                control1: CGPoint(x: x - w * 0.05, y: gy - h * 0.4),
                control2: CGPoint(x: x + w * 0.2, y: gy - h * 1.1)
            )
            p.addCurve(
                to: CGPoint(x: x + w * 0.9, y: gy),
                control1: CGPoint(x: x + w * 0.8, y: gy - h * 1.1),
                control2: CGPoint(x: x + w * 1.05, y: gy - h * 0.4)
            )
            p.closeSubpath()
        }
        ctx.fill(rock, with: .color(rockGray))
    }

    private func drawCone(ctx: GraphicsContext, obs: Obstacle, gy: CGFloat) {
        let cone = Path { p in
            let x = obs.x, w = obs.width, h = obs.height
            p.move(to: CGPoint(x: x + w * 0.5, y: gy - h))
            p.addLine(to: CGPoint(x: x + w * 0.85, y: gy))
            p.addLine(to: CGPoint(x: x + w * 0.15, y: gy))
            p.closeSubpath()
        }
        ctx.fill(cone, with: .color(coneOrange))

        let stripeY = gy - obs.height * 0.45
        let stripe = Path { p in
            p.addRect(CGRect(
                x: obs.x + obs.width * 0.32, y: stripeY,
                width: obs.width * 0.36, height: 4
            ))
        }
        ctx.fill(stripe, with: .color(.white.opacity(0.7)))
    }

    // MARK: - Drawing: Candies

    private func drawBones(ctx: GraphicsContext, time: Double) {
        let gy = game.groundY
        for bone in game.candies where !bone.eaten {
            let bx = bone.x
            let by = gy + bone.y
            let bob = sin(CGFloat(time) * 4 + bx * 0.05) * 3
            let y = by + bob

            // Shaft
            ctx.fill(
                Path(roundedRect: CGRect(x: bx - 7, y: y - 2.5, width: 14, height: 5), cornerRadius: 2),
                with: .color(boneColor)
            )
            // Left knobs
            ctx.fill(Path(ellipseIn: CGRect(x: bx - 11, y: y - 5, width: 6, height: 5)), with: .color(boneColor))
            ctx.fill(Path(ellipseIn: CGRect(x: bx - 11, y: y, width: 6, height: 5)), with: .color(boneColor))
            // Right knobs
            ctx.fill(Path(ellipseIn: CGRect(x: bx + 5, y: y - 5, width: 6, height: 5)), with: .color(boneColor))
            ctx.fill(Path(ellipseIn: CGRect(x: bx + 5, y: y, width: 6, height: 5)), with: .color(boneColor))
            // Highlight
            ctx.fill(
                Path(roundedRect: CGRect(x: bx - 4, y: y - 1.5, width: 8, height: 1.5), cornerRadius: 0.75),
                with: .color(.white.opacity(0.4))
            )
        }
    }

    // MARK: - Drawing: Dog

    private func drawDog(ctx: GraphicsContext, time: Double) {
        let gy = game.groundY - 16 // lift dog so feet sit on grass line
        let dx = Config.dogX
        let isWalking = !game.isJumping && game.phase != .gameOver
        let walk = isWalking ? sin(game.walkTime * 8) : 0
        let walkAngle = walk * 18

        // Helper: segment x position (offset so segment 0 sits under head)
        func segX(_ s: Int) -> CGFloat {
            dx + 6 - CGFloat(s) * Config.segVisualGap
        }

        // -- Tail --
        let lastSeg = game.segmentCount - 1
        let lastY = game.segY(lastSeg)
        let lastX = segX(lastSeg)
        let tailX = lastX - 7
        let tailY = gy + lastY - 1
        let tailWag = sin(CGFloat(time) * 10) * 15

        ctx.drawLayer { c in
            c.translateBy(x: tailX, y: tailY)
            c.rotate(by: .degrees(-55 + Double(tailWag) * 0.8))
            c.fill(
                Path(roundedRect: CGRect(x: -2, y: -10, width: 4, height: 10), cornerRadius: 2),
                with: .color(furBrown)
            )
        }

        // -- Back legs (on last segment) --
        for (i, legOff) in ([-3.0, 3.0] as [CGFloat]).enumerated() {
            ctx.drawLayer { c in
                c.translateBy(x: lastX + legOff, y: gy + lastY + 4)
                let angle: CGFloat = game.isJumping ? 20 : (i == 0 ? walkAngle : -walkAngle)
                c.rotate(by: .degrees(Double(angle)))
                c.fill(
                    Path(roundedRect: CGRect(x: -3, y: 0, width: 6, height: 12), cornerRadius: 2),
                    with: .color(i == 0 ? furDark.opacity(0.8) : furBrown)
                )
            }
        }

        // -- Body segments (back to front, including segment 0 under head) --
        for s in stride(from: game.segmentCount - 1, through: 0, by: -1) {
            let sy = game.segY(s)
            let sx = segX(s)
            let shade = 0.95 - Double(s) * 0.015
            ctx.fill(
                Path(roundedRect: CGRect(x: sx - 9, y: gy + sy - 7, width: 18, height: 14), cornerRadius: 6),
                with: .color(furBrown.opacity(shade))
            )
            ctx.fill(
                Path(roundedRect: CGRect(x: sx - 6, y: gy + sy + 3, width: 12, height: 3), cornerRadius: 1.5),
                with: .color(furDark.opacity(0.15))
            )
        }

        // -- Front legs (at body front) --
        let seg0X = segX(0)
        let seg0Y = gy + game.segY(0)
        for (i, legOff) in ([-2.0, 2.0] as [CGFloat]).enumerated() {
            ctx.drawLayer { c in
                c.translateBy(x: seg0X + legOff + 3, y: seg0Y + 4)
                let angle: CGFloat = game.isJumping ? -15 : (i == 0 ? -walkAngle : walkAngle)
                c.rotate(by: .degrees(Double(angle)))
                c.fill(
                    Path(roundedRect: CGRect(x: -3, y: 0, width: 6, height: 11), cornerRadius: 2),
                    with: .color(i == 0 ? furDark.opacity(0.8) : furBrown)
                )
            }
        }

        // -- Head --
        let hx = dx + 8
        let hy = gy + game.headY - 19
        let bob: CGFloat = isWalking ? abs(sin(game.walkTime * 8)) * 1.5 : 0

        ctx.drawLayer { c in
            c.translateBy(x: hx, y: hy - bob)
            drawDogHead(ctx: c, time: time)
        }
    }

    private func drawDogHead(ctx: GraphicsContext, time: Double) {
        // -- Head (round oval) --
        ctx.fill(
            Path(ellipseIn: CGRect(x: 2, y: 0, width: 24, height: 22)),
            with: .linearGradient(
                Gradient(colors: [furLight, furBrown]),
                startPoint: CGPoint(x: 8, y: 0), endPoint: CGPoint(x: 20, y: 22)
            )
        )
        // Top highlight
        ctx.fill(
            Path(ellipseIn: CGRect(x: 6, y: 1, width: 14, height: 8)),
            with: .color(furLight.opacity(0.25))
        )

        // -- Floppy dachshund ear (in front of head) --
        let earFlap = sin(game.walkTime * 7) * 2
        ctx.drawLayer { ec in
            ec.translateBy(x: 2, y: 2)
            ec.translateBy(x: 7, y: 0)
            ec.rotate(by: .degrees(22 + Double(earFlap)))
            ec.translateBy(x: -7, y: 0)
            let ew: CGFloat = 14, eh: CGFloat = 22
            let earPath = Path { p in
                p.move(to: CGPoint(x: ew * 0.4, y: 0))
                p.addCurve(
                    to: CGPoint(x: ew, y: eh * 0.15),
                    control1: CGPoint(x: ew * 0.6, y: -eh * 0.06),
                    control2: CGPoint(x: ew * 0.95, y: -eh * 0.02)
                )
                p.addCurve(
                    to: CGPoint(x: ew * 0.6, y: eh * 0.9),
                    control1: CGPoint(x: ew * 1.05, y: eh * 0.45),
                    control2: CGPoint(x: ew * 0.85, y: eh * 0.8)
                )
                p.addCurve(
                    to: CGPoint(x: ew * 0.15, y: eh * 0.75),
                    control1: CGPoint(x: ew * 0.4, y: eh * 1.05),
                    control2: CGPoint(x: ew * 0.1, y: eh * 0.98)
                )
                p.addCurve(
                    to: CGPoint(x: ew * 0.4, y: 0),
                    control1: CGPoint(x: ew * 0.2, y: eh * 0.4),
                    control2: CGPoint(x: ew * 0.3, y: eh * 0.05)
                )
            }
            ec.fill(earPath, with: .color(furDark))
        }

        // -- Snout (rounded, extends forward) --
        ctx.fill(
            Path(roundedRect: CGRect(x: 17, y: 11, width: 14, height: 10), cornerRadius: 5),
            with: .color(furLight.opacity(0.85))
        )
        // Snout crease
        ctx.stroke(
            Path { p in
                p.move(to: CGPoint(x: 22, y: 18))
                p.addLine(to: CGPoint(x: 28, y: 18))
            },
            with: .color(furDark.opacity(0.2)), lineWidth: 0.8
        )

        // -- Tongue --
        if game.phase != .gameOver {
            let tongueLen: CGFloat = 3 + abs(sin(game.walkTime * 6)) * 3
            ctx.fill(
                Path(roundedRect: CGRect(x: 23, y: 20, width: 4, height: tongueLen), cornerRadius: 2),
                with: .color(tongueColor)
            )
        }

        // -- Nose --
        ctx.fill(
            Path(ellipseIn: CGRect(x: 25, y: 11, width: 8, height: 6)),
            with: .color(noseBlack)
        )
        // Nose shine
        ctx.fill(
            Path(ellipseIn: CGRect(x: 27, y: 11.5, width: 3, height: 2)),
            with: .color(.white.opacity(0.3))
        )

        // -- Eye (dark pupil only) --
        ctx.fill(
            Path(ellipseIn: CGRect(x: 13, y: 5, width: 6, height: 6)),
            with: .color(noseBlack)
        )
        // Big sparkle highlight
        ctx.fill(
            Path(ellipseIn: CGRect(x: 15.5, y: 5, width: 2.5, height: 2.5)),
            with: .color(.white.opacity(0.85))
        )
        // Small sparkle
        ctx.fill(
            Path(ellipseIn: CGRect(x: 13.5, y: 8.5, width: 1.5, height: 1.5)),
            with: .color(.white.opacity(0.35))
        )

        // -- Cheek blush --
        ctx.fill(
            Path(ellipseIn: CGRect(x: 18, y: 14, width: 5, height: 3)),
            with: .color(Color(red: 0.95, green: 0.55, blue: 0.55).opacity(0.2))
        )

        // -- Game over daze eyes --
        if game.phase == .gameOver {
            ctx.fill(
                Path(ellipseIn: CGRect(x: 13, y: 5, width: 6, height: 6)),
                with: .color(furBrown)
            )
            let xPath = Path { p in
                p.move(to: CGPoint(x: 13.5, y: 6)); p.addLine(to: CGPoint(x: 18.5, y: 10))
                p.move(to: CGPoint(x: 18.5, y: 6)); p.addLine(to: CGPoint(x: 13.5, y: 10))
            }
            ctx.stroke(xPath, with: .color(noseBlack), lineWidth: 1.5)
        }
    }

    // MARK: - Drawing: Score Pops

    private func drawPops(ctx: GraphicsContext) {
        for pop in game.pops {
            let opacity = max(0, 1.0 - Double(pop.age / 0.8))
            let scale = 0.8 + Double(pop.age) * 0.3
            ctx.drawLayer { c in
                c.translateBy(x: pop.x, y: pop.y)
                c.scaleBy(x: scale, y: scale)
                c.draw(
                    Text("+1")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(opacity)),
                    at: .zero
                )
            }
        }
    }

    // MARK: - Drawing: UI

    private func drawUI(ctx: GraphicsContext, size: CGSize, time: Double) {
        // Score (bones collected)
        ctx.draw(
            Text("🦴 \(game.score)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.9)),
            at: CGPoint(x: size.width - 20, y: 24),
            anchor: .topTrailing
        )

        // High score
        if game.highScore > 0 {
            ctx.draw(
                Text("BEST \(game.highScore)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.35)),
                at: CGPoint(x: size.width - 20, y: 50),
                anchor: .topTrailing
            )
        }

        // Idle message
        if game.phase == .idle {
            let pulse = 0.8 + sin(CGFloat(time) * 3) * 0.15
            let textY = size.height * 0.35
            let pill = Path(roundedRect: CGRect(
                x: size.width / 2 - 80, y: textY - 18,
                width: 160, height: 38
            ), cornerRadius: 19)
            ctx.fill(pill, with: .color(.white.opacity(0.1)))
            ctx.draw(
                Text("Tap to play!")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(pulse)),
                at: CGPoint(x: size.width / 2, y: textY)
            )
        }

        // Game over
        if game.phase == .gameOver {
            let overlayRect = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 20)
            ctx.fill(overlayRect, with: .color(.black.opacity(0.45)))

            ctx.draw(
                Text("Score")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white),
                at: CGPoint(x: size.width / 2, y: size.height / 2 - 30)
            )
            ctx.draw(
                Text("🦴 \(game.score)")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8)),
                at: CGPoint(x: size.width / 2, y: size.height / 2 + 2)
            )
            if game.gameOverAge > 0.6 {
                let tapPulse = 0.4 + sin(CGFloat(time) * 3) * 0.15
                ctx.draw(
                    Text("Tap to try again")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(tapPulse)),
                    at: CGPoint(x: size.width / 2, y: size.height / 2 + 30)
                )
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        MiloDogGameView()
            .padding(.horizontal, 16)
        Spacer()
    }
    .background(Color(white: 0.05))
    .preferredColorScheme(.dark)
}
