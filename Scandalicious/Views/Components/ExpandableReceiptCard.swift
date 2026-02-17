//
//  ExpandableReceiptCard.swift
//  Scandalicious
//
//  Unified receipt card component with expandable transaction dropdown.
//  Used consistently throughout the app for receipt display.
//

import SwiftUI

// MARK: - Receipt Display Protocol

/// Protocol for displaying receipts uniformly across the app
protocol ReceiptDisplayable: Identifiable {
    var displayId: String { get }
    var displayStoreName: String { get }
    var displayDate: Date? { get }
    var displayDateString: String? { get }
    var displayTotalAmount: Double { get }
    var displayItemsCount: Int { get }
    var displayTransactions: [ReceiptItemDisplayable] { get }
    var displayHealthScore: Double? { get }
}

/// Protocol for displaying receipt items uniformly
protocol ReceiptItemDisplayable: Identifiable {
    var displayItemName: String { get }
    var displayItemPrice: Double { get }
    var displayQuantity: Int { get }
    var displayHealthScore: Int? { get }
    /// Unique identifier for deletion - returns item_id from backend if available
    var deletableItemId: String? { get }
}

// MARK: - APIReceipt Conformance

extension APIReceipt: ReceiptDisplayable {
    var displayId: String { receiptId }
    // Note: displayStoreName and displayTotalAmount already exist in APIReceipt
    var displayDate: Date? { dateParsed }
    var displayDateString: String? { receiptDate }
    var displayItemsCount: Int {
        // Sum quantities to get actual item count (not just line items)
        transactions.reduce(0) { $0 + $1.quantity }
    }
    var displayTransactions: [ReceiptItemDisplayable] { transactions }
    var displayHealthScore: Double? { averageHealthScore }
}

extension APIReceiptItem: ReceiptItemDisplayable {
    var displayItemName: String { displayName }
    var displayItemPrice: Double { itemPrice }
    var displayQuantity: Int { quantity }
    var displayHealthScore: Int? { healthScore }
    var deletableItemId: String? { itemId }
}

// MARK: - ReceiptUploadResponse Conformance

extension ReceiptUploadResponse: Identifiable {
    var id: String { receiptId }
}

extension ReceiptUploadResponse: ReceiptDisplayable {
    var displayId: String { receiptId }
    var displayStoreName: String { storeName ?? "Unknown Store" }
    var displayDate: Date? { parsedDate }
    var displayDateString: String? { receiptDate }
    var displayTotalAmount: Double { totalAmount ?? 0 }
    var displayItemsCount: Int {
        // Sum quantities to get actual item count (not just line items)
        transactions.reduce(0) { $0 + $1.quantity }
    }
    var displayTransactions: [ReceiptItemDisplayable] { transactions }
    var displayHealthScore: Double? { averageHealthScore }
}

extension ReceiptTransaction: ReceiptItemDisplayable {
    var displayItemName: String { displayName }
    var displayItemPrice: Double { itemPrice }
    var displayQuantity: Int { quantity }
    var displayHealthScore: Int? { healthScore }
    var deletableItemId: String? { itemId } // Uses backend item_id if available
}

// MARK: - Expandable Receipt Card

/// A unified receipt card component with expandable transaction dropdown.
/// Use this component anywhere receipts need to be displayed for consistency.
struct ExpandableReceiptCard<Receipt: ReceiptDisplayable>: View {
    let receipt: Receipt
    let isExpanded: Bool
    let onTap: () -> Void
    let onDelete: (() -> Void)?
    /// Callback when a line item is deleted - receives (receiptId, itemId)
    let onDeleteItem: ((String, String) -> Void)?
    /// Callback when split with friends is tapped
    let onSplit: (() -> Void)?

    /// Optional accent color for the card (e.g., green for "Recent Scan")
    var accentColor: Color = .white

    /// Optional badge text (e.g., "Recent Scan")
    var badgeText: String? = nil

    /// Whether to show the date in the card header
    var showDate: Bool = true

    /// Whether to show the item count badge in the card header
    var showItemCount: Bool = true

    @State private var showDeleteConfirmation = false
    @State private var deletingItemIds: Set<String> = []
    @State private var isEditMode = false
    @State private var itemToDelete: (id: String, name: String)?

    /// Refresh trigger to force view update when split is saved
    @State private var splitRefreshTrigger = UUID()

    /// Observe split cache for updates
    @ObservedObject private var splitCache = SplitCacheManager.shared

    init(
        receipt: Receipt,
        isExpanded: Bool,
        onTap: @escaping () -> Void,
        onDelete: (() -> Void)? = nil,
        onDeleteItem: ((String, String) -> Void)? = nil,
        onSplit: (() -> Void)? = nil,
        accentColor: Color = .white,
        badgeText: String? = nil,
        showDate: Bool = true,
        showItemCount: Bool = true
    ) {
        self.receipt = receipt
        self.isExpanded = isExpanded
        self.onTap = onTap
        self.onDelete = onDelete
        self.onDeleteItem = onDeleteItem
        self.onSplit = onSplit
        self.accentColor = accentColor
        self.badgeText = badgeText
        self.showDate = showDate
        self.showItemCount = showItemCount
    }

    /// Get cached split data for this receipt
    private var splitData: CachedSplitData? {
        splitCache.getSplit(for: receipt.displayId)
    }

    /// Check if receipt has been split with friends
    private var hasSplit: Bool {
        splitData != nil
    }

    private var formattedDate: String {
        guard let date = receipt.displayDate else {
            return receipt.displayDateString ?? "Unknown"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private var formattedTime: String {
        guard let date = receipt.displayDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private var itemCount: Int {
        receipt.displayItemsCount
    }

    private var hasAccent: Bool {
        accentColor != .white
    }

    /// Check if any transaction items are deletable (have item IDs)
    private var hasDeletableItems: Bool {
        onDeleteItem != nil && receipt.displayTransactions.contains { $0.deletableItemId != nil }
    }

    /// Transactions sorted by nutri score (healthy first), then alphabetically for items without scores
    private var sortedTransactions: [ReceiptItemDisplayable] {
        receipt.displayTransactions.sorted { item1, item2 in
            let score1 = item1.displayHealthScore
            let score2 = item2.displayHealthScore

            // Both have scores - sort by score descending (higher = healthier first)
            if let s1 = score1, let s2 = score2 {
                return s1 > s2
            }

            // Item with score comes before item without score
            if score1 != nil && score2 == nil {
                return true
            }
            if score1 == nil && score2 != nil {
                return false
            }

            // Neither has score - sort alphabetically
            return item1.displayItemName.localizedCaseInsensitiveCompare(item2.displayItemName) == .orderedAscending
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main card content - always visible
            Button(action: onTap) {
                HStack(spacing: 10) {
                    // Badge indicator (if present)
                    if let badge = badgeText {
                        Text(badge)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(accentColor.opacity(0.15))
                            )
                    }

                    // Store name - use localized capitalized for consistent casing
                    Text(receipt.displayStoreName.localizedCapitalized)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    // Date inline (conditionally shown)
                    if showDate {
                        Text("•")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.3))

                        Text(formattedDate)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }

                    Spacer()

                    // Split indicator (show if receipt has been split)
                    if hasSplit {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.blue.opacity(0.8))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.blue.opacity(0.15))
                            )
                    }

                    // Item count pill (conditionally shown)
                    if showItemCount {
                        Text("\(itemCount)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                            )
                    }

                    // Total amount
                    Text(String(format: "€%.2f", receipt.displayTotalAmount))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 70, alignment: .trailing)

                    // Chevron indicator
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.25))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .contentShape(Rectangle())
            }
            .buttonStyle(ExpandableReceiptCardButtonStyle())

            // Expanded content - show ALL items
            if isExpanded {
                VStack(spacing: 0) {
                    // Divider
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)
                        .padding(.horizontal, 14)

                    // All items sorted by health score (healthy first)
                    if !sortedTransactions.isEmpty {
                        VStack(spacing: 6) {
                            ForEach(Array(sortedTransactions.enumerated()), id: \.offset) { index, item in
                                let itemId = item.deletableItemId
                                let canDelete = itemId != nil && onDeleteItem != nil
                                let isDeleting = itemId.map { deletingItemIds.contains($0) } ?? false

                                // Get split participants for this item
                                let splitParticipants: [SplitParticipantInfo] = {
                                    guard let itemId = item.deletableItemId,
                                          let split = splitData else { return [] }
                                    return split.participantsForTransaction(itemId)
                                }()

                                EditableLineItemRow(
                                    item: item,
                                    isEditMode: isEditMode,
                                    canDelete: canDelete && !isDeleting,
                                    splitParticipants: splitParticipants,
                                    onDelete: {
                                        if let itemId = itemId {
                                            // Show confirmation dialog
                                            itemToDelete = (id: itemId, name: item.displayItemName)
                                        }
                                    }
                                )
                                .opacity(isDeleting ? 0.5 : 1.0)
                                .transition(.asymmetric(
                                    insertion: .opacity,
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 12)
                        .padding(.bottom, 10)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: sortedTransactions.count)
                    }

                    // Action buttons row
                    if onDelete != nil || hasDeletableItems || onSplit != nil {
                        VStack(spacing: 8) {
                            // Split with Friends button (prominent, full width)
                            if let splitAction = onSplit, !receipt.displayTransactions.isEmpty {
                                Button {
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                    splitAction()
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "person.2.fill")
                                            .font(.system(size: 14, weight: .medium))
                                        Text(L("split_with_friends"))
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.blue.opacity(0.12))
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }

                            HStack(spacing: 10) {
                                // Edit Items button (only if there are deletable items)
                                if hasDeletableItems {
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            isEditMode.toggle()
                                        }
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.impactOccurred()
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: isEditMode ? "checkmark" : "pencil")
                                                .font(.system(size: 13, weight: .medium))
                                            Text(isEditMode ? L("done") : L("edit_items"))
                                                .font(.system(size: 13, weight: .semibold))
                                        }
                                        .foregroundColor(isEditMode ? .green.opacity(0.9) : .white.opacity(0.7))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(isEditMode ? Color.green.opacity(0.12) : Color.white.opacity(0.06))
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }

                                // Delete Receipt button
                                if let deleteAction = onDelete {
                                    Button {
                                        showDeleteConfirmation = true
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "trash")
                                                .font(.system(size: 13, weight: .medium))
                                            Text(L("delete_receipt"))
                                                .font(.system(size: 13, weight: .semibold))
                                        }
                                        .foregroundColor(.red.opacity(0.8))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color.red.opacity(0.08))
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .confirmationDialog("Delete Receipt", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                                        Button("Delete", role: .destructive) {
                                            deleteAction()
                                        }
                                        Button("Cancel", role: .cancel) {}
                                    } message: {
                                        Text(L("delete_receipt_confirm"))
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    }
                }
                .transition(.opacity)
            }
        }
        .background(Color.clear)
        .confirmationDialog("Delete Item", isPresented: Binding(
            get: { itemToDelete != nil },
            set: { if !$0 { itemToDelete = nil } }
        ), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let item = itemToDelete {
                    // Mark as deleting for visual feedback
                    deletingItemIds.insert(item.id)

                    // Trigger haptic
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)

                    // Call delete handler
                    onDeleteItem?(receipt.displayId, item.id)
                }
                itemToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                itemToDelete = nil
            }
        } message: {
            if let item = itemToDelete {
                Text("Remove \"\(item.name)\" from this receipt?")
            }
        }
        .onChange(of: isExpanded) { _, expanded in
            // Reset edit mode when card collapses
            if !expanded && isEditMode {
                withAnimation(.easeOut(duration: 0.2)) {
                    isEditMode = false
                }
            }

            // Fetch split data when expanded (if not already cached)
            if expanded && splitData == nil {
                Task {
                    await splitCache.fetchSplit(for: receipt.displayId)
                }
            }
        }
        .task {
            // Check for existing split on first appearance
            if splitData == nil {
                await splitCache.fetchSplit(for: receipt.displayId)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .expenseSplitSaved)) { notification in
            // Force refresh when a split is saved for this receipt
            if let receiptId = notification.userInfo?["receiptId"] as? String,
               receiptId == receipt.displayId {
                splitRefreshTrigger = UUID()
            }
        }
        .id(splitRefreshTrigger)
    }
}

// MARK: - Editable Line Item Row

/// A clean row component for line items with optional delete button in edit mode
struct EditableLineItemRow: View {
    let item: ReceiptItemDisplayable
    let isEditMode: Bool
    let canDelete: Bool
    var splitParticipants: [SplitParticipantInfo] = []
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Delete button (shown in edit mode)
            if isEditMode && canDelete {
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    onDelete()
                } label: {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.red.opacity(0.85))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(PlainButtonStyle())
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }

            // Nutri-Score letter (only shown when score exists)
            if item.displayHealthScore != nil {
                Text(item.displayHealthScore.nutriScoreLetter)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(item.displayHealthScore.healthScoreColor)
                    .frame(width: 16, height: 16)
                    .background(
                        Circle()
                            .fill(item.displayHealthScore.healthScoreColor.opacity(0.15))
                    )
                    .overlay(
                        Circle()
                            .stroke(item.displayHealthScore.healthScoreColor.opacity(0.3), lineWidth: 0.5)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.displayItemName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(2)

                    if item.displayQuantity > 1 {
                        Text("×\(item.displayQuantity)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                            )
                    }

                    // Split participant avatars
                    if !splitParticipants.isEmpty {
                        MiniSplitAvatars(participants: splitParticipants)
                            .accessibilityIdentifier("split-avatar-indicator")
                    }
                }
            }

            Spacer()

            Text(String(format: "€%.2f", item.displayItemPrice))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isEditMode && canDelete ? Color.red.opacity(0.03) : Color.clear)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isEditMode)
    }
}

// MARK: - Mini Split Avatars

/// Compact display of friend avatars for split items (excludes "Me")
struct MiniSplitAvatars: View {
    let participants: [SplitParticipantInfo]

    /// Maximum avatars to show before "+N"
    private let maxVisible = 3

    /// Filter out "Me" - only show friends
    private var friendsOnly: [SplitParticipantInfo] {
        participants.filter { !$0.isMe }
    }

    var body: some View {
        // Only show if there are friends (not just "Me")
        if !friendsOnly.isEmpty {
            HStack(spacing: -4) {
                // Show up to maxVisible avatars
                ForEach(Array(friendsOnly.prefix(maxVisible).enumerated()), id: \.element.id) { index, participant in
                    Circle()
                        .fill(participant.swiftUIColor)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Text(String(participant.name.prefix(1)).uppercased())
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color(white: 0.1), lineWidth: 1)
                        )
                        .zIndex(Double(maxVisible - index))
                }

                // Show "+N" if more participants
                if friendsOnly.count > maxVisible {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 14, height: 14)
                        .overlay(
                            Text("+\(friendsOnly.count - maxVisible)")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                        )
                        .overlay(
                            Circle()
                                .stroke(Color(white: 0.1), lineWidth: 1)
                        )
                }
            }
            .padding(.leading, 4)
        }
    }
}

// MARK: - Button Style

struct ExpandableReceiptCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.04 : 0))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(white: 0.05).ignoresSafeArea()

        VStack(spacing: 16) {
            // Preview would go here with mock data
            Text("ExpandableReceiptCard Preview")
                .foregroundColor(.white)
        }
        .padding()
    }
}
