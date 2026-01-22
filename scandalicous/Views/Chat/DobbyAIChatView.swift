//
//  ScandaLiciousAIChatView.swift
//  Scandalicious
//
//  ChatGPT-like Experience
//  Created by Gilles Moenaert on 19/01/2026.
//

import SwiftUI
import Combine
import FirebaseAuth
import StoreKit

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
    @Binding var showSignOutConfirmation: Bool
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            Color(white: 0.05)
                .ignoresSafeArea()

            // Main chat area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if viewModel.messages.isEmpty && showWelcome {
                            WelcomeView(
                                messageText: $messageText,
                                isInputFocused: $isInputFocused,
                                onSend: sendMessage
                            )
                            .padding(.horizontal)
                            .padding(.top, 20)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        } else {
                            // Messages - no extra padding needed
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
                        Color.clear
                            .frame(height: 100)
                    }
                }
                .onChange(of: viewModel.messages.count) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        if let lastMessage = viewModel.messages.last {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: isInputFocused) {
                    if isInputFocused {
                        // Scroll to bottom when keyboard appears
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation {
                                if let lastMessage = viewModel.messages.last {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
            }
            
            // Floating input area
            VStack(spacing: 0) {
                // Gradient fade effect above input
                LinearGradient(
                    colors: [
                        Color(.systemBackground).opacity(0),
                        Color(.systemBackground).opacity(0.8),
                        Color(.systemBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 25)
                
                HStack(alignment: .bottom, spacing: 8) {
                    // Message input field
                    HStack(alignment: .bottom, spacing: 8) {
                        TextField("Ask Dobby", text: $messageText, axis: .vertical)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .focused($isInputFocused)
                            .lineLimit(1...6)
                        
                        // Send or Stop button
                        Button {
                            if viewModel.isLoading {
                                viewModel.stopGeneration()
                            } else {
                                sendMessage()
                            }
                        } label: {
                            if viewModel.isLoading {
                                Image(systemName: "stop.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(.gray)
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(messageText.isEmpty ? Color(.systemGray3) : .white)
                                    .background(
                                        Circle()
                                            .fill(messageText.isEmpty ? Color.clear : Color.blue)
                                            .frame(width: 28, height: 28)
                                    )
                            }
                        }
                        .disabled(messageText.isEmpty && !viewModel.isLoading)
                        .padding(.trailing, 4)
                        .padding(.bottom, 4)
                    }
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 20)
                .background(Color(white: 0.05))
            }
        }
        .navigationTitle(viewModel.messages.isEmpty ? "" : "Dobby")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Profile button - leading (left side)
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    // User Email
                    if let user = authManager.user {
                        Section {
                            Text(user.email ?? "No email")
                                .font(.headline)
                        }
                    }

                    // Usage & Subscription
                    Section {
                        // Message rate limit usage display with smart color
                        Button(action: {}) {
                            Label(rateLimitManager.usageDisplayString, systemImage: usageIconName)
                        }
                        .tint(usageColor)

                        // Receipt upload limit
                        Button(action: {}) {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(rateLimitManager.receiptsRemaining)/\(rateLimitManager.receiptsLimit) receipts remaining")
                                    Text(rateLimitManager.resetDaysFormatted)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            } icon: {
                                Image(systemName: receiptLimitIcon)
                            }
                        }
                        .tint(receiptLimitColor)

                        // Show subscription status
                        Label(subscriptionManager.subscriptionStatus.displayText, systemImage: "crown.fill")

                        // Manage subscription button
                        Button {
                            showManageSubscription = true
                        } label: {
                            Label("Manage Subscription", systemImage: "creditcard")
                        }
                    }

                    // Sign Out
                    Section {
                        Button(role: .destructive) {
                            showSignOutConfirmation = true
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                } label: {
                    ZStack(alignment: .bottomTrailing) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.secondary)

                        // Usage indicator dot
                        Circle()
                            .fill(usageColor)
                            .frame(width: 10, height: 10)
                            .overlay(
                                Circle()
                                    .stroke(Color(.systemBackground), lineWidth: 1.5)
                            )
                            .offset(x: 2, y: 2)
                    }
                }
            }

            // Clear chat button - trailing (right side)
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.clearConversation()
                            showWelcome = true
                        }
                    } label: {
                        Label("Clear Chat", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
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
            // Sync rate limit on appear
            Task {
                await rateLimitManager.syncFromBackend()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Sync rate limit when app returns to foreground
            Task {
                await rateLimitManager.syncFromBackend()
            }
        }
    }

    // MARK: - Usage Display Helpers

    private var usageIconName: String {
        let used = rateLimitManager.usagePercentage
        if used >= 0.95 {
            return "exclamationmark.bubble.fill"
        } else if used >= 0.8 {
            return "bubble.left.and.exclamationmark.bubble.right.fill"
        } else {
            return "bubble.left.fill"
        }
    }

    private var usageColor: Color {
        let used = rateLimitManager.usagePercentage
        // Interpolate from green (0% used) to red (100% used)
        // Green: RGB(0.2, 0.8, 0.2) -> Red: RGB(0.9, 0.2, 0.2)
        let red = 0.2 + (used * 0.7)    // 0.2 -> 0.9
        let green = 0.8 - (used * 0.6)  // 0.8 -> 0.2
        let blue = 0.2
        return Color(red: red, green: green, blue: blue)
    }

    // Receipt limit status icon
    private var receiptLimitIcon: String {
        switch rateLimitManager.receiptLimitState {
        case .normal:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .exhausted:
            return "xmark.circle.fill"
        }
    }

    // Receipt limit status color
    private var receiptLimitColor: Color {
        switch rateLimitManager.receiptLimitState {
        case .normal:
            return .green
        case .warning:
            return .orange
        case .exhausted:
            return .red
        }
    }
    
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Check rate limit
        guard rateLimitManager.canSendMessage(for: subscriptionManager.subscriptionStatus) else {
            showRateLimitAlert = true
            return
        }

        messageText = ""

        // Optimistically decrement the local counter
        rateLimitManager.decrementLocal()

        // Smooth transition: hide welcome screen first
        if viewModel.messages.isEmpty {
            withAnimation(.easeInOut(duration: 0.3)) {
                showWelcome = false
            }

            // Wait for welcome screen to fade out before sending
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                completeMessageSend(text: text)
            }
        } else {
            completeMessageSend(text: text)
        }
    }
    
    private func completeMessageSend(text: String) {
        isInputFocused = false
        
        // Haptic feedback
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

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero section
            VStack(spacing: 16) {
                // Purple AI magic stars logo - transparent background
                Image(systemName: "sparkles")
                    .font(.system(size: 64, weight: .bold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(
                        Color(red: 0.45, green: 0.15, blue: 0.85),  // Deep vibrant purple
                        Color(red: 0.55, green: 0.25, blue: 0.95)   // Slightly lighter purple accent
                    )
                    .padding(.bottom, 8)

                Text("Dobby")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Your AI shopping assistant")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.bottom, 40)

            // Sample prompts
            VStack(spacing: 12) {
                SamplePromptCard(
                    icon: "leaf.fill",
                    iconColor: .green,
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
                    iconColor: .blue,
                    title: "Shopping habits",
                    subtitle: "Am I buying enough vegetables?"
                ) {
                    messageText = "Am I buying enough vegetables?"
                    onSend()
                }

                SamplePromptCard(
                    icon: "dollarsign.circle.fill",
                    iconColor: .green,
                    title: "Save money",
                    subtitle: "Where can I cut costs?"
                ) {
                    messageText = "Where can I save money?"
                    onSend()
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            
            action()
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 36, height: 36)
                    .background(iconColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(14)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(ScaleButtonStyle(isPressed: $isPressed))
    }
}

// Custom button style for smooth press effect
struct ScaleButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
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
    
    // Check if this message is currently streaming
    private var isStreaming: Bool {
        message.id == viewModel.streamingMessageId && viewModel.isLoading
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                if message.role == .user {
                    Spacer(minLength: 20)
                }
                
                // Message content with smooth slide-in animation
                VStack(alignment: .leading, spacing: 0) {
                    Group {
                        if message.role == .assistant && message.content.isEmpty && message.id == viewModel.streamingMessageId && viewModel.isLoading {
                            // Show typing indicator inline
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
                    
                    // Extra padding at the bottom INSIDE the bubble while streaming
                    if isStreaming && !message.content.isEmpty {
                        Color.clear
                            .frame(height: 150)
                    }
                }
                .opacity(isVisible ? 1.0 : 0.0)
                .offset(x: isVisible ? 0 : (message.role == .assistant ? -30 : 30))
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.8).delay(0.1)) {
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
            
            // Extra padding OUTSIDE the bubble for scrolling breathing room
            if isStreaming {
                Color.clear
                    .frame(height: 100)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }
}

// MARK: - Typing Dots (inline in message)
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
        .onAppear {
            animating = true
        }
        .onDisappear {
            animating = false
        }
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
                // Split by double newlines to create paragraphs
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
                // Also handle paragraphs in non-table content
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
        
        // Parse header
        let headers = lines[0]
            .components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        // Parse rows (skip separator line at index 1)
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
    
    // Buffer for incoming chunks
    private var fullStreamedContent: String = ""
    private let chunkSize = 150 // Characters per chunk for smooth streaming with large chunks
    private let chunkInterval: Duration = .milliseconds(120) // Delay between chunks
    
    func setTransactions(_ transactions: [Transaction]) {
        self.transactions = transactions
    }
    
    func sendMessage(_ text: String) async {
        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        
        isLoading = true
        
        // Create a placeholder message for streaming
        let assistantMessageId = UUID()
        let assistantMessage = ChatMessage(id: assistantMessageId, role: .assistant, content: "")
        messages.append(assistantMessage)
        streamingMessageId = assistantMessageId
        displayedStreamingContent = ""
        fullStreamedContent = ""
        
        // Start smooth streaming display
        startSmoothStreaming(messageId: assistantMessageId)
        
        // Create a cancellable task
        currentTask = Task {
            do {
                let stream = await DobbyAIChatService.shared.sendMessageStreaming(
                    text,
                    transactions: transactions,
                    conversationHistory: messages.filter { $0.id != assistantMessageId }
                )
                
                for try await chunk in stream {
                    // Check if cancelled
                    if Task.isCancelled {
                        streamingTask?.cancel()
                        isLoading = false
                        streamingMessageId = nil
                        return
                    }
                    
                    // Append to the full content buffer
                    fullStreamedContent += chunk
                }
                
                // Wait for streaming display to catch up
                while displayedStreamingContent.count < fullStreamedContent.count && !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(10))
                }
                
                // Cancel streaming task
                streamingTask?.cancel()
                
                // Final update with complete message
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
                // Check if cancelled
                if Task.isCancelled {
                    streamingTask?.cancel()
                    isLoading = false
                    streamingMessageId = nil
                    return
                }
                
                // Cancel streaming
                streamingTask?.cancel()
                
                // Replace placeholder with error message
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
                
                // Display characters in chunks progressively
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
                    
                    // Update with smooth, slower animation for cooler effect
                    withAnimation(.easeInOut(duration: 1.2)) {
                        displayedStreamingContent = newContent
                        
                        // Update the message in the array
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
        
        // If we have partial content, save it with animation
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
        ScandaLiciousAIChatView(showSignOutConfirmation: .constant(false))
            .environmentObject(TransactionManager())
            .environmentObject(AuthenticationManager())
    }
}
