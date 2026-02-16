//
//  ScandaLiciousAIChatView.swift
//  Scandalicious
//
//  ChatGPT-like Experience - Redesigned
//  Created by Gilles Moenaert on 19/01/2026.
//

import SwiftUI
import Combine
import FirebaseAuth
import StoreKit

// MARK: - Milo Brand Colors
private extension Color {
    static let miloPurple = Color(red: 0.45, green: 0.15, blue: 0.85)
    static let miloPurpleLight = Color(red: 0.55, green: 0.25, blue: 0.95)
    static let miloBackground = Color(white: 0.05)
    static let miloCardBackground = Color.white.opacity(0.06)
    static let miloCardBackgroundHover = Color.white.opacity(0.10)
    static let miloHeaderIndigo = Color(red: 0.15, green: 0.05, blue: 0.30)
}

// MARK: - Milo Dachshund Avatar (Apple-style head)
struct MiloDachshundView: View {
    var size: CGFloat = 64

    // Base unit for proportional scaling
    private var u: CGFloat { size / 100 }

    // Palette — warm chocolate tones
    private let furDark = Color(red: 0.40, green: 0.22, blue: 0.11)
    private let furMid = Color(red: 0.55, green: 0.33, blue: 0.16)
    private let furLight = Color(red: 0.68, green: 0.45, blue: 0.24)
    private let furHighlight = Color(red: 0.78, green: 0.58, blue: 0.36)
    private let snoutTan = Color(red: 0.76, green: 0.56, blue: 0.35)
    private let snoutLight = Color(red: 0.85, green: 0.68, blue: 0.48)
    private let noseDark = Color(red: 0.18, green: 0.12, blue: 0.08)
    private let eyeDark = Color(red: 0.10, green: 0.06, blue: 0.04)

    var body: some View {
        Canvas { context, canvasSize in
            let cx = canvasSize.width / 2
            let cy = canvasSize.height / 2

            // ── EARS (hooked floppy — fold over and hang down) ──
            for xSign: CGFloat in [-1, 1] {
                let ear = Path { p in
                    p.move(to: CGPoint(x: cx + xSign * 18 * u, y: cy - 16 * u))
                    p.addCurve(
                        to: CGPoint(x: cx + xSign * 50 * u, y: cy - 16 * u),
                        control1: CGPoint(x: cx + xSign * 28 * u, y: cy - 34 * u),
                        control2: CGPoint(x: cx + xSign * 48 * u, y: cy - 32 * u)
                    )
                    p.addCurve(
                        to: CGPoint(x: cx + xSign * 44 * u, y: cy + 28 * u),
                        control1: CGPoint(x: cx + xSign * 58 * u, y: cy - 2 * u),
                        control2: CGPoint(x: cx + xSign * 56 * u, y: cy + 20 * u)
                    )
                    p.addCurve(
                        to: CGPoint(x: cx + xSign * 32 * u, y: cy + 26 * u),
                        control1: CGPoint(x: cx + xSign * 40 * u, y: cy + 34 * u),
                        control2: CGPoint(x: cx + xSign * 36 * u, y: cy + 34 * u)
                    )
                    p.addCurve(
                        to: CGPoint(x: cx + xSign * 18 * u, y: cy - 16 * u),
                        control1: CGPoint(x: cx + xSign * 26 * u, y: cy + 10 * u),
                        control2: CGPoint(x: cx + xSign * 14 * u, y: cy - 4 * u)
                    )
                    p.closeSubpath()
                }
                context.fill(ear, with: .linearGradient(
                    Gradient(colors: [furDark, furDark.opacity(0.8)]),
                    startPoint: CGPoint(x: cx + xSign * 34 * u, y: cy - 28 * u),
                    endPoint: CGPoint(x: cx + xSign * 40 * u, y: cy + 30 * u)
                ))
            }

            // ── HEAD (cute dog shape — wide forehead, puffy cheeks, softer chin) ──
            let headPath = Path { p in
                // Start at top center
                p.move(to: CGPoint(x: cx, y: cy - 32 * u))
                // Top-right: narrower forehead, widens to cheek
                p.addCurve(
                    to: CGPoint(x: cx + 36 * u, y: cy - 6 * u),
                    control1: CGPoint(x: cx + 16 * u, y: cy - 32 * u),
                    control2: CGPoint(x: cx + 32 * u, y: cy - 22 * u)
                )
                // Right cheek puff, then taper to chin
                p.addCurve(
                    to: CGPoint(x: cx + 18 * u, y: cy + 28 * u),
                    control1: CGPoint(x: cx + 36 * u, y: cy + 10 * u),
                    control2: CGPoint(x: cx + 28 * u, y: cy + 26 * u)
                )
                // Chin — soft rounded
                p.addCurve(
                    to: CGPoint(x: cx - 18 * u, y: cy + 28 * u),
                    control1: CGPoint(x: cx + 8 * u, y: cy + 34 * u),
                    control2: CGPoint(x: cx - 8 * u, y: cy + 34 * u)
                )
                // Left cheek puff back up
                p.addCurve(
                    to: CGPoint(x: cx - 36 * u, y: cy - 6 * u),
                    control1: CGPoint(x: cx - 28 * u, y: cy + 26 * u),
                    control2: CGPoint(x: cx - 36 * u, y: cy + 10 * u)
                )
                // Top-left: back to top center
                p.addCurve(
                    to: CGPoint(x: cx, y: cy - 32 * u),
                    control1: CGPoint(x: cx - 32 * u, y: cy - 22 * u),
                    control2: CGPoint(x: cx - 16 * u, y: cy - 32 * u)
                )
                p.closeSubpath()
            }
            context.fill(headPath, with: .linearGradient(
                Gradient(colors: [furLight, furMid]),
                startPoint: CGPoint(x: cx, y: cy - 32 * u),
                endPoint: CGPoint(x: cx, y: cy + 30 * u)
            ))

            // Head highlight (subtle top glow)
            let highlightRect = CGRect(
                x: cx - 20 * u, y: cy - 30 * u,
                width: 40 * u, height: 28 * u
            )
            context.fill(Path(ellipseIn: highlightRect), with: .linearGradient(
                Gradient(colors: [furHighlight.opacity(0.5), furHighlight.opacity(0)]),
                startPoint: CGPoint(x: cx, y: cy - 30 * u),
                endPoint: CGPoint(x: cx, y: cy - 8 * u)
            ))

            // ── SNOUT / MUZZLE (lighter bump) ──
            let snoutRect = CGRect(
                x: cx - 20 * u, y: cy + 2 * u,
                width: 40 * u, height: 30 * u
            )
            context.fill(Path(ellipseIn: snoutRect), with: .linearGradient(
                Gradient(colors: [snoutLight, snoutTan]),
                startPoint: CGPoint(x: cx, y: cy + 2 * u),
                endPoint: CGPoint(x: cx, y: cy + 32 * u)
            ))

            // ── NOSE ──
            let noseW: CGFloat = 14 * u
            let noseH: CGFloat = 10 * u
            let noseY: CGFloat = cy + 4 * u
            let noseRect = CGRect(x: cx - noseW / 2, y: noseY, width: noseW, height: noseH)
            let nosePath = Path(roundedRect: noseRect, cornerRadius: 5 * u)
            context.fill(nosePath, with: .linearGradient(
                Gradient(colors: [noseDark, noseDark.opacity(0.9)]),
                startPoint: CGPoint(x: cx, y: noseY),
                endPoint: CGPoint(x: cx, y: noseY + noseH)
            ))

            // Nose shine
            let shineRect = CGRect(x: cx - 3.5 * u, y: noseY + 1.5 * u, width: 7 * u, height: 4 * u)
            context.fill(Path(ellipseIn: shineRect), with: .color(.white.opacity(0.35)))

            // ── EYES (solid dark, Apple Memoji-style) ──
            let eyeRadius: CGFloat = 7 * u
            let eyeY: CGFloat = cy - 8 * u
            let eyeSpacing: CGFloat = 14 * u

            // Left eye — solid dark oval
            let leftEyeRect = CGRect(
                x: cx - eyeSpacing - eyeRadius,
                y: eyeY - eyeRadius * 1.15,
                width: eyeRadius * 2,
                height: eyeRadius * 2.3
            )
            context.fill(Path(ellipseIn: leftEyeRect), with: .color(eyeDark))

            // Left eye shine (small bright dot, top-right)
            let lShine = CGRect(
                x: cx - eyeSpacing + 1.5 * u,
                y: eyeY - eyeRadius * 0.7,
                width: 4 * u, height: 4 * u
            )
            context.fill(Path(ellipseIn: lShine), with: .color(.white.opacity(0.85)))

            // Left eye secondary shine (smaller, lower-left)
            let lShine2 = CGRect(
                x: cx - eyeSpacing - 2.5 * u,
                y: eyeY + 2 * u,
                width: 2.5 * u, height: 2.5 * u
            )
            context.fill(Path(ellipseIn: lShine2), with: .color(.white.opacity(0.4)))

            // Right eye — solid dark oval
            let rightEyeRect = CGRect(
                x: cx + eyeSpacing - eyeRadius,
                y: eyeY - eyeRadius * 1.15,
                width: eyeRadius * 2,
                height: eyeRadius * 2.3
            )
            context.fill(Path(ellipseIn: rightEyeRect), with: .color(eyeDark))

            // Right eye shine
            let rShine = CGRect(
                x: cx + eyeSpacing + 1.5 * u,
                y: eyeY - eyeRadius * 0.7,
                width: 4 * u, height: 4 * u
            )
            context.fill(Path(ellipseIn: rShine), with: .color(.white.opacity(0.85)))

            // Right eye secondary shine
            let rShine2 = CGRect(
                x: cx + eyeSpacing - 2.5 * u,
                y: eyeY + 2 * u,
                width: 2.5 * u, height: 2.5 * u
            )
            context.fill(Path(ellipseIn: rShine2), with: .color(.white.opacity(0.4)))

            // ── EYEBROWS (subtle fur ridges) ──
            var leftBrow = Path()
            leftBrow.move(to: CGPoint(x: cx - eyeSpacing - 8 * u, y: eyeY - 12 * u))
            leftBrow.addQuadCurve(
                to: CGPoint(x: cx - eyeSpacing + 8 * u, y: eyeY - 11 * u),
                control: CGPoint(x: cx - eyeSpacing, y: eyeY - 16 * u)
            )
            context.stroke(leftBrow, with: .color(furDark.opacity(0.5)), style: StrokeStyle(lineWidth: 2 * u, lineCap: .round))

            var rightBrow = Path()
            rightBrow.move(to: CGPoint(x: cx + eyeSpacing - 8 * u, y: eyeY - 11 * u))
            rightBrow.addQuadCurve(
                to: CGPoint(x: cx + eyeSpacing + 8 * u, y: eyeY - 12 * u),
                control: CGPoint(x: cx + eyeSpacing, y: eyeY - 16 * u)
            )
            context.stroke(rightBrow, with: .color(furDark.opacity(0.5)), style: StrokeStyle(lineWidth: 2 * u, lineCap: .round))

            // ── MOUTH (happy little smile) ──
            let mouthY: CGFloat = cy + 18 * u
            var mouth = Path()
            mouth.move(to: CGPoint(x: cx - 7 * u, y: mouthY))
            mouth.addQuadCurve(
                to: CGPoint(x: cx, y: mouthY + 4 * u),
                control: CGPoint(x: cx - 3 * u, y: mouthY + 5 * u)
            )
            mouth.addQuadCurve(
                to: CGPoint(x: cx + 7 * u, y: mouthY),
                control: CGPoint(x: cx + 3 * u, y: mouthY + 5 * u)
            )
            context.stroke(mouth, with: .color(furDark.opacity(0.6)), style: StrokeStyle(lineWidth: 1.8 * u, lineCap: .round))

            // ── TONGUE (proper shape — narrow top, round bottom) ──
            let tTop = mouthY + 1 * u
            let tBot = mouthY + 12 * u
            let tonguePath = Path { p in
                // Start top-left (narrow opening)
                p.move(to: CGPoint(x: cx - 3.5 * u, y: tTop))
                // Left edge curves outward then rounds bottom
                p.addCurve(
                    to: CGPoint(x: cx, y: tBot),
                    control1: CGPoint(x: cx - 6 * u, y: tTop + 4 * u),
                    control2: CGPoint(x: cx - 6 * u, y: tBot)
                )
                // Right side mirrors back up
                p.addCurve(
                    to: CGPoint(x: cx + 3.5 * u, y: tTop),
                    control1: CGPoint(x: cx + 6 * u, y: tBot),
                    control2: CGPoint(x: cx + 6 * u, y: tTop + 4 * u)
                )
                p.closeSubpath()
            }
            context.fill(tonguePath, with: .color(Color(red: 0.88, green: 0.25, blue: 0.30)))
            // Center crease line
            var crease = Path()
            crease.move(to: CGPoint(x: cx, y: tTop + 1.5 * u))
            crease.addLine(to: CGPoint(x: cx, y: tBot - 2.5 * u))
            context.stroke(crease, with: .color(Color(red: 0.72, green: 0.18, blue: 0.22).opacity(0.4)),
                          style: StrokeStyle(lineWidth: 1 * u, lineCap: .round))
            // Highlight
            let tongueHL = CGRect(x: cx - 1.5 * u, y: tTop + 2 * u, width: 3 * u, height: 4 * u)
            context.fill(Path(ellipseIn: tongueHL), with: .color(Color(red: 0.95, green: 0.42, blue: 0.45).opacity(0.45)))
        }
        .frame(width: size, height: size)
    }
}

struct ScandaLiciousAIChatView: View {
    @EnvironmentObject var transactionManager: TransactionManager
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var viewModel = ChatViewModel()
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var rateLimitManager = RateLimitManager.shared
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    @State private var scrollOffset: CGFloat = 0
    @State private var showWelcome = true
    @State private var showManageSubscription = false
    @State private var showRateLimitAlert = false
    @State private var showClearButton = false

    // Entrance animation states
    @State private var viewAppeared = false
    @State private var contentOpacity: Double = 0
    @State private var inputAreaOffset: CGFloat = 30
    @State private var inputAreaOpacity: Double = 0
    @State private var backgroundGlowOpacity: Double = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            backgroundView
            chatContentView
                .opacity(contentOpacity)
            floatingInputArea
                .offset(y: inputAreaOffset)
                .opacity(inputAreaOpacity)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showClearButton {
                clearButtonToolbarItem
            }
        }
        .manageSubscriptionsSheet(isPresented: $showManageSubscription)
        .alert("Message Limit Reached", isPresented: $showRateLimitAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(rateLimitManager.rateLimitMessage ?? "You've used all your messages for this period. Your limit resets on \(rateLimitManager.resetDateFormatted).")
        }
        .onAppear {
            viewModel.setTransactions(transactionManager.transactions)
            Task {
                await rateLimitManager.syncFromBackend()
            }

            // Trigger entrance animations
            if !viewAppeared {
                viewAppeared = true

                // All elements fade in together
                withAnimation(.easeOut(duration: 0.4)) {
                    backgroundGlowOpacity = 1.0
                    contentOpacity = 1.0
                    inputAreaOffset = 0
                    inputAreaOpacity = 1.0
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task {
                await rateLimitManager.syncFromBackend()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .receiptUploadedSuccessfully)) { _ in
            // Refresh transaction data so chat has up-to-date context
            viewModel.setTransactions(transactionManager.transactions)
        }
        .onDisappear {
            // Reset entrance animation states for next appearance
            viewAppeared = false
            contentOpacity = 0
            inputAreaOffset = 30
            inputAreaOpacity = 0
            backgroundGlowOpacity = 0
        }
    }
    
    // MARK: - View Components
    
    private var backgroundView: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                Color.miloBackground

                // Indigo gradient header (fades in with entrance animation)
                LinearGradient(
                    stops: [
                        .init(color: Color.miloHeaderIndigo, location: 0.0),
                        .init(color: Color.miloHeaderIndigo.opacity(0.7), location: 0.25),
                        .init(color: Color.miloHeaderIndigo.opacity(0.3), location: 0.5),
                        .init(color: Color.clear, location: 0.75)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: geometry.size.height * 0.45 + geometry.safeAreaInsets.top)
                .frame(maxWidth: .infinity)
                .offset(y: -geometry.safeAreaInsets.top)
                .opacity(backgroundGlowOpacity)
                .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
    }
    
    @ViewBuilder
    private var chatContentView: some View {
        if viewModel.messages.isEmpty && showWelcome {
            // Welcome view without ScrollView for proper layout
            WelcomeView(
                messageText: $messageText,
                isInputFocused: $isInputFocused,
                onSend: sendMessage
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 100) // Space for input area
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        } else {
            // Scrollable messages view
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Top spacing
                        Color.clear.frame(height: 20)

                        // Messages with refined spacing
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(message: message)
                                .environmentObject(viewModel)
                                .id(message.id)
                                .transition(.opacity)
                        }

                        // Bottom padding for input area
                        Color.clear.frame(height: 120)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: viewModel.messages.count) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        if let lastMessage = viewModel.messages.last {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                    if !viewModel.messages.isEmpty && !showClearButton {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showClearButton = true
                        }
                    }
                }
                .onChange(of: isInputFocused) {
                    if isInputFocused {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if let lastMessage = viewModel.messages.last {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var floatingInputArea: some View {
        VStack(spacing: 0) {
            gradientFade
            inputContainer
        }
    }
    
    private var gradientFade: some View {
        LinearGradient(
            colors: [
                Color.miloBackground.opacity(0),
                Color.miloBackground.opacity(0.95),
                Color.miloBackground
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 40)
    }
    
    private var inputContainer: some View {
        HStack(alignment: .bottom, spacing: 12) {
            textInputField
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 24)
        .background(Color.miloBackground)
    }
    
    private var textInputField: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Ask Milo anything...", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .focused($isInputFocused)
                .lineLimit(1...6)
                .tint(Color.miloPurple)

            sendButton
        }
        .background(textInputBackground)
        .animation(.easeInOut(duration: 0.2), value: isInputFocused)
    }
    
    private var sendButton: some View {
        Button {
            if viewModel.isLoading {
                viewModel.stopGeneration()
            } else {
                sendMessage()
            }
        } label: {
            sendButtonLabel
        }
        .disabled(messageText.isEmpty && !viewModel.isLoading)
        .padding(.trailing, 6)
        .padding(.bottom, 6)
    }
    
    @ViewBuilder
    private var sendButtonLabel: some View {
        Group {
            if viewModel.isLoading {
                Image(systemName: "stop.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.gray.opacity(0.6))
                    .clipShape(Circle())
            } else {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(messageText.isEmpty ? .gray : .white)
                    .frame(width: 32, height: 32)
                    .background(sendButtonBackground)
                    .clipShape(Circle())
            }
        }
        .animation(.easeInOut(duration: 0.2), value: messageText.isEmpty)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
    }
    
    @ViewBuilder
    private var sendButtonBackground: some View {
        if messageText.isEmpty {
            Color.white.opacity(0.1)
        } else {
            LinearGradient(
                colors: [Color.miloPurple, Color.miloPurpleLight],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var textInputBackground: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isInputFocused ? 0.2 : 0.08),
                                Color.white.opacity(isInputFocused ? 0.1 : 0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
    
    @ToolbarContentBuilder
    private var clearButtonToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                // Haptic feedback
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()

                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.clearConversation()
                    showWelcome = true
                    showClearButton = false
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.red.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
    }

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        guard rateLimitManager.canSendMessage(for: subscriptionManager.subscriptionStatus) else {
            showRateLimitAlert = true
            return
        }

        messageText = ""
        rateLimitManager.decrementLocal()

        if viewModel.messages.isEmpty {
            withAnimation(.easeInOut(duration: 0.25)) {
                showWelcome = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                completeMessageSend(text: text)
            }
        } else {
            completeMessageSend(text: text)
        }
    }

    private func completeMessageSend(text: String) {
        isInputFocused = false

        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()

        Task {
            await viewModel.sendMessage(text)
        }
    }
}

// MARK: - Welcome View
struct WelcomeView: View {
    @Binding var messageText: String
    @FocusState.Binding var isInputFocused: Bool
    let onSend: () -> Void

    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var cardsOpacity: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)

            // Hero section with staggered animation
            VStack(spacing: 16) {
                // Animated Milo mascot
                ZStack {
                    // Ambient glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.miloPurple.opacity(0.3), Color.clear],
                                center: .center,
                                startRadius: 20,
                                endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)
                        .blur(radius: 20)

                    // Milo the Dachshund
                    MiloDachshundView(size: 80)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                VStack(spacing: 6) {
                    Text("Milo")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Your helpfull shopping doggo")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .opacity(textOpacity)
            }
            .padding(.bottom, 28)

            // Sample prompts in premium glass card
            VStack(spacing: 0) {
                SamplePromptCard(
                    icon: "fork.knife",
                    iconColor: Color(red: 1.0, green: 0.6, blue: 0.2),
                    title: "Cook with what I bought",
                    subtitle: "Recipes from my last haul"
                ) {
                    messageText = "What meals can I cook using the items from my most recent grocery receipt?"
                    onSend()
                }

                LinearGradient(
                    colors: [.white.opacity(0), .white.opacity(0.2), .white.opacity(0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 0.5)
                .padding(.leading, 50)

                SamplePromptCard(
                    icon: "wand.and.stars",
                    iconColor: Color(red: 0.4, green: 0.75, blue: 1.0),
                    title: "Predict my next list",
                    subtitle: "What I'll need to restock soon"
                ) {
                    messageText = "Based on my purchase history, what grocery items will I likely need to restock soon?"
                    onSend()
                }

                LinearGradient(
                    colors: [.white.opacity(0), .white.opacity(0.2), .white.opacity(0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 0.5)
                .padding(.leading, 50)

                SamplePromptCard(
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: Color(red: 1.0, green: 0.45, blue: 0.4),
                    title: "Spot the price creep",
                    subtitle: "Are my groceries getting pricier?"
                ) {
                    messageText = "Are any of my regularly purchased grocery items getting more expensive over time?"
                    onSend()
                }

                LinearGradient(
                    colors: [.white.opacity(0), .white.opacity(0.2), .white.opacity(0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 0.5)
                .padding(.leading, 50)

                SamplePromptCard(
                    icon: "heart.fill",
                    iconColor: Color(red: 1.0, green: 0.4, blue: 0.6),
                    title: "Rate my basket",
                    subtitle: "Nutrition score breakdown"
                ) {
                    messageText = "Analyze the nutritional balance of my recent grocery purchases and give me a health score"
                    onSend()
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(white: 0.08))
                    .overlay(
                        LinearGradient(
                            colors: [Color.white.opacity(0.05), Color.white.opacity(0.02)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .opacity(cardsOpacity)

            Spacer(minLength: 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Reset states first for clean animation
            logoScale = 0.8
            logoOpacity = 0
            textOpacity = 0
            cardsOpacity = 0

            // All elements fade in together
            withAnimation(.easeOut(duration: 0.4)) {
                logoScale = 1.0
                logoOpacity = 1.0
                textOpacity = 1.0
                cardsOpacity = 1.0
            }
        }
    }
}

struct SamplePromptCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            action()
        }) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.25))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isPressed ? Color.white.opacity(0.04) : Color.clear)
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(PromptCardButtonStyle(isPressed: $isPressed))
    }
}

struct PromptCardButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    isPressed = configuration.isPressed
                }
            }
    }
}

// MARK: - Message Bubble View
struct MessageBubbleView: View {
    let message: ChatMessage
    @State private var isVisible = false
    @EnvironmentObject var viewModel: ChatViewModel

    private var isStreaming: Bool {
        message.id == viewModel.streamingMessageId && viewModel.isLoading
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                if message.role == .user {
                    Spacer(minLength: 20)
                }

                // Message content
                VStack(alignment: .leading, spacing: 0) {
                    Group {
                        if message.role == .assistant && message.content.isEmpty && message.id == viewModel.streamingMessageId && viewModel.isLoading {
                            TypingDotsView()
                        } else if message.role == .assistant {
                            MarkdownMessageView(content: message.content)
                                .textSelection(.enabled)
                        } else {
                            Text(message.content)
                                .font(.system(size: 16))
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                        }
                    }

                    // Extra padding while streaming
                    if isStreaming && !message.content.isEmpty {
                        Color.clear.frame(height: 150)
                    }
                }
                .opacity(isVisible ? 1.0 : 0.0)
                .onAppear {
                    withAnimation(.easeIn(duration: 0.3)) {
                        isVisible = true
                    }
                }

                if message.role == .assistant {
                    Spacer(minLength: 20)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
            .background(message.role == .assistant ? Color(.systemGray6).opacity(0.5) : Color.clear)

            // Extra scroll space while streaming
            if isStreaming {
                Color.clear
                    .frame(height: 100)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }
}

// MARK: - Typing Dots
struct TypingDotsView: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 8, height: 8)
                    .opacity(animating ? 0.3 : 1.0)
                    .animation(
                        Animation
                            .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .padding(.top, 4)
        .onAppear { animating = true }
        .onDisappear { animating = false }
    }
}

// MARK: - Markdown Message View
struct MarkdownMessageView: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if hasMarkdownTable(content) {
                renderContentWithTables(content)
            } else {
                let paragraphs = content.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

                ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                    if let attributedString = try? AttributedString(markdown: paragraph) {
                        Text(attributedString)
                            .font(.system(size: 16))
                            .lineSpacing(2)
                            .textSelection(.enabled)
                    } else {
                        Text(paragraph)
                            .font(.system(size: 16))
                            .lineSpacing(2)
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func hasMarkdownTable(_ text: String) -> Bool {
        text.contains("|") && text.contains("---")
    }

    @ViewBuilder
    private func renderContentWithTables(_ text: String) -> some View {
        let components = splitContentByTables(text)

        ForEach(Array(components.enumerated()), id: \.offset) { index, component in
            if component.isTable {
                MarkdownTableView(markdown: component.text)
                    .padding(.vertical, 4)
            } else if !component.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let paragraphs = component.text.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

                ForEach(Array(paragraphs.enumerated()), id: \.offset) { pIndex, paragraph in
                    if let attributedString = try? AttributedString(markdown: paragraph) {
                        Text(attributedString)
                            .font(.system(size: 16))
                            .lineSpacing(2)
                            .textSelection(.enabled)
                    } else {
                        Text(paragraph)
                            .font(.system(size: 16))
                            .lineSpacing(2)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    private func splitContentByTables(_ text: String) -> [(text: String, isTable: Bool)] {
        var result: [(String, Bool)] = []
        var currentText = ""
        var inTable = false

        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            let isTableLine = line.contains("|")

            if isTableLine != inTable {
                if !currentText.isEmpty {
                    result.append((currentText, inTable))
                    currentText = ""
                }
                inTable = isTableLine
            }

            currentText += line + "\n"
        }

        if !currentText.isEmpty {
            result.append((currentText, inTable))
        }

        return result
    }
}

// MARK: - Markdown Table View
struct MarkdownTableView: View {
    let markdown: String

    private var parsedTable: (headers: [String], rows: [[String]]) {
        parseMarkdownTable(markdown)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                ForEach(Array(parsedTable.headers.enumerated()), id: \.offset) { index, header in
                    Text(header)
                        .font(.system(size: 13, weight: .semibold))
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray4))
                        .overlay(
                            Rectangle()
                                .stroke(Color(.systemGray3), lineWidth: 0.5)
                        )
                }
            }

            // Data rows
            ForEach(Array(parsedTable.rows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { colIndex, cell in
                        Text(cell)
                            .font(.system(size: 13))
                            .padding(8)
                            .frame(maxWidth: .infinity)
                            .background(rowIndex % 2 == 0 ? Color(.systemGray6) : Color(.systemGray5))
                            .overlay(
                                Rectangle()
                                    .stroke(Color(.systemGray3), lineWidth: 0.5)
                            )
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray3), lineWidth: 1)
        )
    }

    private func parseMarkdownTable(_ markdown: String) -> (headers: [String], rows: [[String]]) {
        let lines = markdown.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0.contains("|") }

        guard lines.count >= 2 else {
            return ([], [])
        }

        let headers = lines[0]
            .components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let rows = lines.dropFirst(2).map { line in
            line.components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }

        return (headers, rows)
    }
}

// MARK: - Chat View Model
@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var streamingMessageId: UUID?
    @Published var displayedStreamingContent: String = ""

    private var transactions: [Transaction] = []
    private var currentTask: Task<Void, Never>?
    private var streamingTask: Task<Void, Never>?

    private var fullStreamedContent: String = ""
    private let chunkSize = 150
    private let chunkInterval: Duration = .milliseconds(120)

    func setTransactions(_ transactions: [Transaction]) {
        self.transactions = transactions
    }

    func sendMessage(_ text: String) async {
        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)

        isLoading = true

        let assistantMessageId = UUID()
        let assistantMessage = ChatMessage(id: assistantMessageId, role: .assistant, content: "")
        messages.append(assistantMessage)
        streamingMessageId = assistantMessageId
        displayedStreamingContent = ""
        fullStreamedContent = ""

        startSmoothStreaming(messageId: assistantMessageId)

        currentTask = Task {
            do {
                let stream = await MiloAIChatService.shared.sendMessageStreaming(
                    text,
                    transactions: transactions,
                    conversationHistory: messages.filter { $0.id != assistantMessageId }
                )

                for try await chunk in stream {
                    if Task.isCancelled {
                        streamingTask?.cancel()
                        isLoading = false
                        streamingMessageId = nil
                        return
                    }

                    fullStreamedContent += chunk
                }

                while displayedStreamingContent.count < fullStreamedContent.count && !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(10))
                }

                streamingTask?.cancel()

                if let index = messages.firstIndex(where: { $0.id == assistantMessageId }) {
                    messages[index] = ChatMessage(
                        id: assistantMessageId,
                        role: .assistant,
                        content: fullStreamedContent,
                        timestamp: messages[index].timestamp
                    )
                }

                streamingMessageId = nil
                displayedStreamingContent = ""
                fullStreamedContent = ""

            } catch {
                if Task.isCancelled {
                    streamingTask?.cancel()
                    isLoading = false
                    streamingMessageId = nil
                    return
                }

                streamingTask?.cancel()

                if let index = messages.firstIndex(where: { $0.id == assistantMessageId }) {
                    messages[index] = ChatMessage(
                        id: assistantMessageId,
                        role: .assistant,
                        content: "I'm sorry, I encountered an error: \(error.localizedDescription). Please try again.",
                        timestamp: messages[index].timestamp
                    )
                }
                streamingMessageId = nil
                displayedStreamingContent = ""
                fullStreamedContent = ""
            }

            isLoading = false
        }

        await currentTask?.value
    }

    private func startSmoothStreaming(messageId: UUID) {
        streamingTask?.cancel()

        streamingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: chunkInterval)

                guard !Task.isCancelled else { break }

                if displayedStreamingContent.count < fullStreamedContent.count {
                    let targetIndex = min(
                        displayedStreamingContent.count + chunkSize,
                        fullStreamedContent.count
                    )

                    let endIndex = fullStreamedContent.index(
                        fullStreamedContent.startIndex,
                        offsetBy: targetIndex
                    )

                    let newContent = String(fullStreamedContent[..<endIndex])

                    withAnimation(.easeInOut(duration: 1.2)) {
                        displayedStreamingContent = newContent

                        if let index = messages.firstIndex(where: { $0.id == messageId }) {
                            messages[index] = ChatMessage(
                                id: messageId,
                                role: .assistant,
                                content: displayedStreamingContent,
                                timestamp: messages[index].timestamp
                            )
                        }
                    }
                }
            }
        }
    }

    func stopGeneration() {
        currentTask?.cancel()
        streamingTask?.cancel()
        currentTask = nil
        streamingTask = nil
        isLoading = false

        if let messageId = streamingMessageId,
           let index = messages.firstIndex(where: { $0.id == messageId }),
           !displayedStreamingContent.isEmpty {
            withAnimation(.easeOut(duration: 0.2)) {
                messages[index] = ChatMessage(
                    id: messageId,
                    role: .assistant,
                    content: displayedStreamingContent,
                    timestamp: messages[index].timestamp
                )
            }
        }

        streamingMessageId = nil
        displayedStreamingContent = ""
        fullStreamedContent = ""
    }

    func clearConversation() {
        currentTask?.cancel()
        streamingTask?.cancel()
        currentTask = nil
        streamingTask = nil
        messages.removeAll()
        isLoading = false
        streamingMessageId = nil
        displayedStreamingContent = ""
        fullStreamedContent = ""
    }

    func resetForNewConversation() {
        clearConversation()
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        ScandaLiciousAIChatView()
            .environmentObject(TransactionManager())
            .environmentObject(AuthenticationManager())
    }
}
