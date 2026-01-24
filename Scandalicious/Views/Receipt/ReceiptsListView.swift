//
//  ReceiptsListView.swift
//  Scandalicious
//
//  Created by Claude on 24/01/2026.
//

import SwiftUI

struct ReceiptsListView: View {
    let period: String
    let storeName: String?

    @StateObject private var viewModel = ReceiptsViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedReceipt: APIReceipt?
    @State private var showingReceiptDetail = false
    @State private var isDeleting = false
    @State private var deleteError: String?

    var body: some View {
        ZStack {
            Color(white: 0.05).ignoresSafeArea()

            if viewModel.state.isLoading && viewModel.receipts.isEmpty {
                loadingView
            } else if viewModel.receipts.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.receipts) { receipt in
                                SwipeableReceiptRow(
                                    receipt: receipt,
                                    onTap: {
                                        selectedReceipt = receipt
                                        showingReceiptDetail = true
                                    },
                                    onDelete: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            deleteReceipt(receipt)
                                        }
                                    }
                                )
                                .transition(.asymmetric(
                                    insertion: .opacity,
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                            }

                            // Load more indicator
                            if viewModel.hasMorePages {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding()
                                    .onAppear {
                                        Task {
                                            await viewModel.loadNextPage(period: period, storeName: storeName)
                                        }
                                    }
                            }
                        }
                        .animation(.easeInOut(duration: 0.3), value: viewModel.receipts.count)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 32)
                    }
                }
                .refreshable {
                    await viewModel.refresh(period: period, storeName: storeName)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text("Receipts")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)

                    Text(period)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .navigationDestination(isPresented: $showingReceiptDetail) {
            if let receipt = selectedReceipt {
                ReceiptTransactionsView(receipt: receipt)
            }
        }
        .task {
            await viewModel.loadReceipts(period: period, storeName: storeName)
        }
        .alert("Error", isPresented: .constant(viewModel.state.error != nil)) {
            Button("OK") { }
        } message: {
            if let error = viewModel.state.error {
                Text(error)
            }
        }
        .alert("Delete Failed", isPresented: .constant(deleteError != nil)) {
            Button("OK") {
                deleteError = nil
            }
        } message: {
            if let error = deleteError {
                Text(error)
            }
        }
        .overlay {
            if isDeleting {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)

                        Text("Deleting...")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(white: 0.15))
                    )
                }
            }
        }
    }

    // MARK: - Delete Receipt

    private func deleteReceipt(_ receipt: APIReceipt) {
        isDeleting = true

        Task {
            do {
                try await viewModel.deleteReceipt(receipt, period: period, storeName: storeName)

                // Haptic feedback for successful deletion
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            } catch {
                deleteError = error.localizedDescription

                // Haptic feedback for failure
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
            }

            isDeleting = false
        }
    }

    // MARK: - Components

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)

            Text("Loading receipts...")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))
                .padding(.top, 60)

            Text("No Receipts")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)

            Text("No receipts found for this period")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Swipeable Receipt Row

struct SwipeableReceiptRow: View {
    let receipt: APIReceipt
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var startOffset: CGFloat = 0
    @State private var showingDeleteConfirmation = false

    private let deleteButtonWidth: CGFloat = 80
    private let swipeThreshold: CGFloat = 40

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete button (behind content)
            Button {
                showingDeleteConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "trash.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: deleteButtonWidth)
                        .frame(maxHeight: .infinity)
                }
                .background(Color.red)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)

            // Main content
            receiptRowContent
                .offset(x: offset)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { value in
                            // Calculate new offset based on starting position
                            let newOffset = startOffset + value.translation.width

                            // Clamp between -deleteButtonWidth and 0, with rubber band effect
                            if newOffset > 0 {
                                offset = newOffset * 0.2 // Rubber band right
                            } else if newOffset < -deleteButtonWidth {
                                let overshoot = newOffset + deleteButtonWidth
                                offset = -deleteButtonWidth + overshoot * 0.2 // Rubber band left
                            } else {
                                offset = newOffset
                            }
                        }
                        .onEnded { value in
                            let velocity = value.velocity.width
                            let predictedEndOffset = offset + velocity * 0.15

                            withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                                // Decide final position based on predicted end and velocity
                                if predictedEndOffset < -swipeThreshold {
                                    offset = -deleteButtonWidth
                                    startOffset = -deleteButtonWidth
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                } else {
                                    offset = 0
                                    startOffset = 0
                                }
                            }
                        }
                )
                .onTapGesture {
                    if abs(offset) < 5 {
                        onTap()
                    } else {
                        withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                            offset = 0
                            startOffset = 0
                        }
                    }
                }
        }
        .alert("Delete Receipt", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                    offset = 0
                    startOffset = 0
                }
            }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete this receipt? This action cannot be undone.")
        }
    }

    private var receiptRowContent: some View {
        HStack(spacing: 16) {
            // Receipt icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: "doc.text.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.blue)
            }

            // Receipt details
            VStack(alignment: .leading, spacing: 4) {
                Text(receipt.formattedDate)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                HStack(spacing: 8) {
                    Text(receipt.displayStoreName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))

                    Text("•")
                        .foregroundColor(.white.opacity(0.3))

                    Text("\(receipt.itemsCount) item\(receipt.itemsCount == 1 ? "" : "s")")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }

                if let healthScore = receipt.averageHealthScore {
                    HStack(spacing: 4) {
                        HealthScoreBadge(score: Int(healthScore.rounded()), size: .small, style: .subtle)

                        Text(healthScore.healthScoreLabel)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(healthScore.healthScoreColor)
                    }
                }
            }

            Spacer()

            // Amount
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "€%.2f", receipt.displayTotalAmount))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ReceiptsListView(period: "January 2026", storeName: "COLRUYT")
    }
    .preferredColorScheme(.dark)
}
