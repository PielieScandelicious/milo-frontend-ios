//
//  DobbyAIChatView.swift
//  Dobby
//
//  ChatGPT-like Experience
//  Created by Gilles Moenaert on 19/01/2026.
//

import SwiftUI
import Combine

struct DobbyAIChatView: View {
    @EnvironmentObject var transactionManager: TransactionManager
    @StateObject private var viewModel = ChatViewModel()
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    @State private var scrollOffset: CGFloat = 0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main chat area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if viewModel.messages.isEmpty {
                            WelcomeView(
                                messageText: $messageText,
                                isInputFocused: $isInputFocused,
                                onSend: sendMessage
                            )
                            .padding(.horizontal)
                            .padding(.top, 20)
                        } else {
                            // Messages - no extra padding needed
                            ForEach(viewModel.messages) { message in
                                MessageBubbleView(message: message)
                                    .id(message.id)
                            }
                        }
                        
                        if viewModel.isLoading {
                            TypingIndicatorView()
                                .id("typing")
                        }
                        
                        // Bottom padding for input area
                        Color.clear
                            .frame(height: 100)
                    }
                }
                .onChange(of: viewModel.messages.count) { _ in
                    withAnimation(.easeOut(duration: 0.3)) {
                        if let lastMessage = viewModel.messages.last {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: viewModel.isLoading) { isLoading in
                    if isLoading {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo("typing", anchor: .bottom)
                        }
                    }
                }
                .onChange(of: isInputFocused) { focused in
                    if focused {
                        // Scroll to bottom when keyboard appears
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation {
                                if viewModel.isLoading {
                                    proxy.scrollTo("typing", anchor: .bottom)
                                } else if let lastMessage = viewModel.messages.last {
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
                .frame(height: 20)
                
                HStack(alignment: .bottom, spacing: 8) {
                    // Message input field
                    HStack(alignment: .bottom, spacing: 8) {
                        TextField("Message", text: $messageText, axis: .vertical)
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
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
            }
        }
        .navigationTitle(viewModel.messages.isEmpty ? "" : "Dobby")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        withAnimation {
                            viewModel.clearConversation()
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
        .onAppear {
            viewModel.setTransactions(transactionManager.transactions)
        }
    }
    
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        messageText = ""
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
                // Avatar image - make sure avatar.png is added to Assets.xcassets
                if let uiImage = UIImage(named: "avatar") {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .padding(.bottom, 8)
                } else {
                    // Fallback to sparkles if avatar not found
                    Image(systemName: "sparkles")
                        .font(.system(size: 64))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(.bottom, 8)
                }
                
                Text("Dobby")
                    .font(.system(size: 34, weight: .bold))
                
                Text("Your shopping elf")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
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
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(iconColor)
                    .frame(width: 32, height: 32)
                    .background(iconColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Message Bubble View
struct MessageBubbleView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .user {
                Spacer(minLength: 20)
            }
            
            // Avatar for assistant
            if message.role == .assistant {
                if let uiImage = UIImage(named: "avatar") {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                } else {
                    // Fallback icon
                    Image(systemName: "sparkles")
                        .font(.system(size: 20))
                        .foregroundStyle(.blue)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.blue.opacity(0.1)))
                }
            }
            
            // Message content
            if message.role == .assistant {
                MarkdownMessageView(content: message.content)
                    .textSelection(.enabled)
            } else {
                Text(message.content)
                    .font(.system(size: 16))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            }
            
            if message.role == .assistant {
                Spacer(minLength: 20)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
        .background(message.role == .assistant ? Color(.systemGray6).opacity(0.5) : Color.clear)
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

// MARK: - Typing Indicator
struct TypingIndicatorView: View {
    @State private var animating = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let uiImage = UIImage(named: "avatar") {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
            } else {
                // Fallback icon
                Image(systemName: "sparkles")
                    .font(.system(size: 20))
                    .foregroundStyle(.blue)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.blue.opacity(0.1)))
            }
            
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
            
            Spacer(minLength: 20)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6).opacity(0.5))
        .onAppear {
            animating = true
        }
        .onDisappear {
            animating = false
        }
    }
}

// MARK: - Chat View Model
@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var streamingMessageId: UUID?
    
    private var transactions: [Transaction] = []
    private var currentTask: Task<Void, Never>?
    
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
        
        // Create a cancellable task
        currentTask = Task {
            do {
                let stream = await DobbyAIChatService.shared.sendMessageStreaming(
                    text,
                    transactions: transactions,
                    conversationHistory: messages.filter { $0.id != assistantMessageId }
                )
                
                var fullResponse = ""
                
                for try await chunk in stream {
                    // Check if cancelled
                    if Task.isCancelled {
                        isLoading = false
                        streamingMessageId = nil
                        return
                    }
                    
                    fullResponse += chunk
                    
                    // Update the message in place
                    if let index = messages.firstIndex(where: { $0.id == assistantMessageId }) {
                        messages[index] = ChatMessage(
                            id: assistantMessageId,
                            role: .assistant,
                            content: fullResponse,
                            timestamp: messages[index].timestamp
                        )
                    }
                }
                
                streamingMessageId = nil
                
            } catch {
                // Check if cancelled
                if Task.isCancelled {
                    isLoading = false
                    streamingMessageId = nil
                    return
                }
                
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
            }
            
            isLoading = false
        }
        
        await currentTask?.value
    }
    
    func stopGeneration() {
        currentTask?.cancel()
        currentTask = nil
        isLoading = false
        streamingMessageId = nil
    }
    
    func clearConversation() {
        currentTask?.cancel()
        currentTask = nil
        messages.removeAll()
        isLoading = false
        streamingMessageId = nil
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        DobbyAIChatView()
            .environmentObject(TransactionManager())
    }
}
