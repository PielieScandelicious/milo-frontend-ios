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
    @State private var inputAreaOpacity: Double = 1.0

    var body: some View {
        ZStack(alignment: .bottom) {
            backgroundView
            chatContentView
            floatingInputArea
        }
        .navigationTitle(viewModel.messages.isEmpty ? "" : "Milo")
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
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task {
                await rateLimitManager.syncFromBackend()
            }
        }
    }
    
    // MARK: - View Components
    
    private var backgroundView: some View {
        ZStack {
            Color.miloBackground

            // Subtle purple ambient glow at top
            RadialGradient(
                colors: [Color.miloPurple.opacity(0.08), Color.clear],
                center: .top,
                startRadius: 0,
                endRadius: 400
            )
        }
        .ignoresSafeArea()
    }
    
    private var chatContentView: some View {
        ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Top spacing
                        Color.clear.frame(height: 20)

                        if viewModel.messages.isEmpty && showWelcome {
                            WelcomeView(
                                messageText: $messageText,
                                isInputFocused: $isInputFocused,
                                onSend: sendMessage
                            )
                            .padding(.horizontal, 20)
                            .padding(.top, 40)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        } else {
                            // Messages with refined spacing
                            ForEach(viewModel.messages) { message in
                                MessageBubbleView(message: message)
                                    .environmentObject(viewModel)
                                    .id(message.id)
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                                        removal: .opacity
                                    ))
                            }
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
            Spacer()

            // Hero section with staggered animation
            VStack(spacing: 20) {
                // Animated logo
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

                    // Icon
                    Image(systemName: "sparkles")
                        .font(.system(size: 52, weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(
                            Color.miloPurple,
                            Color.miloPurpleLight
                        )
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                VStack(spacing: 8) {
                    Text("Milo")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Your AI shopping assistant")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .opacity(textOpacity)
            }
            .padding(.bottom, 48)

            // Sample prompts with staggered animation
            VStack(spacing: 10) {
                SamplePromptCard(
                    icon: "leaf.fill",
                    iconColor: Color(red: 0.2, green: 0.8, blue: 0.4),
                    title: "Analyze my diet",
                    subtitle: "Do I have enough protein?"
                ) {
                    messageText = "Do I have enough protein in my diet?"
                    onSend()
                }

                SamplePromptCard(
                    icon: "chart.pie.fill",
                    iconColor: .orange,
                    title: "Review spending",
                    subtitle: "What's my biggest expense?"
                ) {
                    messageText = "What's my biggest expense category?"
                    onSend()
                }

                SamplePromptCard(
                    icon: "cart.fill",
                    iconColor: Color(red: 0.4, green: 0.7, blue: 1.0),
                    title: "Shopping habits",
                    subtitle: "Am I buying enough vegetables?"
                ) {
                    messageText = "Am I buying enough vegetables?"
                    onSend()
                }

                SamplePromptCard(
                    icon: "banknote.fill",
                    iconColor: Color(red: 0.3, green: 0.85, blue: 0.6),
                    title: "Save money",
                    subtitle: "Where can I cut costs?"
                ) {
                    messageText = "Where can I save money?"
                    onSend()
                }
            }
            .opacity(cardsOpacity)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Staggered entrance animation
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.25)) {
                textOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
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
                // Icon with subtle gradient background
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconColor.opacity(0.15))

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.25))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(isPressed ? 0.10 : 0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
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
