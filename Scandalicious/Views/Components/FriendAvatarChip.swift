//
//  FriendAvatarChip.swift
//  Scandalicious
//
//  Created by Gilles Moenaert on 02/02/2026.
//

import SwiftUI

// MARK: - Friend Avatar Chip

/// A circular avatar chip showing friend's initials with a vibrant color
struct FriendAvatarChip: View {
    let participant: SplitParticipant
    var isSelected: Bool = true
    var size: CGFloat = 36
    var showName: Bool = false
    var isMe: Bool = false
    var onTap: (() -> Void)?

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                onTap?()
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(isSelected ? participant.swiftUIColor : Color.gray.opacity(0.3))
                        .frame(width: size, height: size)

                    Circle()
                        .strokeBorder(isSelected ? participant.swiftUIColor : Color.gray.opacity(0.5), lineWidth: 2)
                        .frame(width: size, height: size)

                    if isMe || participant.isMe {
                        // Show person icon for "Me"
                        Image(systemName: "person.fill")
                            .font(.system(size: size * 0.45, weight: .semibold))
                            .foregroundStyle(isSelected ? .white : .gray)
                    } else {
                        Text(participant.initials)
                            .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                            .foregroundStyle(isSelected ? .white : .gray)
                    }
                }
                .scaleEffect(isSelected ? 1.0 : 0.9)

                if showName {
                    Text(participant.isMe ? "Me" : (participant.name.split(separator: " ").first.map(String.init) ?? ""))
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mini Friend Avatar (for item rows)

/// Smaller avatar for showing in item rows
struct MiniFriendAvatar: View {
    let participant: SplitParticipant
    var isSelected: Bool = true
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? participant.swiftUIColor : Color.gray.opacity(0.2))
                .frame(width: size, height: size)

            if !isSelected {
                Circle()
                    .strokeBorder(Color.gray.opacity(0.4), lineWidth: 1.5)
                    .frame(width: size, height: size)
            }

            if participant.isMe {
                // Show person icon for "Me"
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .gray.opacity(0.6))
            } else {
                Text(participant.initials)
                    .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? .white : .gray.opacity(0.6))
            }
        }
    }
}

// MARK: - Add Friend Button

/// Plus button for adding a new friend
struct AddFriendButton: View {
    var size: CGFloat = 36
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .strokeBorder(Color.gray.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                    .frame(width: size, height: size)

                Image(systemName: "plus")
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Friend Chips Row

/// Horizontal scrollable row of friend chips with add button
struct FriendChipsRow: View {
    let participants: [SplitParticipant]
    var onAddTap: () -> Void
    var onParticipantTap: ((SplitParticipant) -> Void)?
    var onParticipantLongPress: ((SplitParticipant) -> Void)?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Show "Me" avatar first (sorted by displayOrder, "Me" is always 0)
                ForEach(participants.sorted { $0.displayOrder < $1.displayOrder }) { participant in
                    if participant.isMe {
                        // "Me" avatar - no context menu (can't be removed)
                        FriendAvatarChip(
                            participant: participant,
                            isSelected: true,
                            size: 40,
                            showName: true,
                            isMe: true
                        ) {
                            onParticipantTap?(participant)
                        }
                    } else {
                        // Friend avatar - can be removed via context menu
                        FriendAvatarChip(
                            participant: participant,
                            isSelected: true,
                            size: 40,
                            showName: true
                        ) {
                            onParticipantTap?(participant)
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                onParticipantLongPress?(participant)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                }

                AddFriendButton(size: 40, onTap: onAddTap)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Item Participant Avatars

/// Row of mini avatars for an item showing who shares it
struct ItemParticipantAvatars: View {
    let participants: [SplitParticipant]
    let selectedIds: Set<String>
    var onToggle: ((SplitParticipant) -> Void)?

    /// Check if a participant is selected (case-insensitive comparison)
    private func isParticipantSelected(_ participant: SplitParticipant) -> Bool {
        let participantIdLower = participant.id.uuidString.lowercased()
        return selectedIds.contains(where: { $0.lowercased() == participantIdLower })
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(participants) { participant in
                Button {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        onToggle?(participant)
                    }
                } label: {
                    MiniFriendAvatar(
                        participant: participant,
                        isSelected: isParticipantSelected(participant),
                        size: 26
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Previews

#Preview("Friend Avatar Chip") {
    VStack(spacing: 20) {
        HStack(spacing: 16) {
            FriendAvatarChip(
                participant: SplitParticipant(name: "Gilles M", color: "#FF6B6B", displayOrder: 0),
                isSelected: true,
                showName: true
            )

            FriendAvatarChip(
                participant: SplitParticipant(name: "John Doe", color: "#4ECDC4", displayOrder: 1),
                isSelected: true,
                showName: true
            )

            FriendAvatarChip(
                participant: SplitParticipant(name: "Sarah", color: "#FFE66D", displayOrder: 2),
                isSelected: false,
                showName: true
            )

            AddFriendButton(size: 36) {}
        }

        Divider()

        HStack(spacing: 8) {
            MiniFriendAvatar(
                participant: SplitParticipant(name: "Gilles", color: "#FF6B6B", displayOrder: 0),
                isSelected: true
            )
            MiniFriendAvatar(
                participant: SplitParticipant(name: "John", color: "#4ECDC4", displayOrder: 1),
                isSelected: true
            )
            MiniFriendAvatar(
                participant: SplitParticipant(name: "Sarah", color: "#FFE66D", displayOrder: 2),
                isSelected: false
            )
        }
    }
    .padding()
}
