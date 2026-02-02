//
//  AddFriendSheet.swift
//  Scandalicious
//
//  Created by Gilles Moenaert on 02/02/2026.
//

import SwiftUI

struct AddFriendSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var friendName: String
    let recentFriends: [RecentFriend]
    let existingParticipants: [SplitParticipant]
    var onAddNew: (String) -> Void
    var onAddRecent: (RecentFriend) -> Void

    @FocusState private var isNameFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Name Input Section
                VStack(spacing: 16) {
                    Text("Add a friend to split with")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)

                    HStack(spacing: 12) {
                        // Preview avatar
                        if !friendName.isEmpty {
                            ZStack {
                                Circle()
                                    .fill(FriendColor.fromIndex(existingParticipants.count).color)
                                    .frame(width: 50, height: 50)

                                Text(previewInitials)
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                        }

                        TextField("Friend's name", text: $friendName)
                            .font(.title3)
                            .textFieldStyle(.plain)
                            .focused($isNameFocused)
                            .submitLabel(.done)
                            .onSubmit {
                                addFriend()
                            }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    )
                    .padding(.horizontal)

                    Button {
                        addFriend()
                    } label: {
                        Text("Add Friend")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(friendName.isEmpty ? Color.gray : Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(friendName.isEmpty)
                    .padding(.horizontal)
                }
                .padding(.vertical)

                // Recent Friends Section
                if !availableRecentFriends.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Friends")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(availableRecentFriends) { friend in
                                    RecentFriendRow(friend: friend) {
                                        onAddRecent(friend)
                                        dismiss()
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top, 8)
                }

                Spacer()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                isNameFocused = true
            }
        }
    }

    // MARK: - Computed Properties

    private var previewInitials: String {
        let parts = friendName.split(separator: " ")
        if parts.count >= 2 {
            let first = parts[0].prefix(1)
            let last = parts[1].prefix(1)
            return "\(first)\(last)".uppercased()
        } else {
            return String(friendName.prefix(2)).uppercased()
        }
    }

    /// Recent friends that aren't already added
    private var availableRecentFriends: [RecentFriend] {
        let existingNames = Set(existingParticipants.map { $0.name.lowercased() })
        return recentFriends.filter { !existingNames.contains($0.name.lowercased()) }
    }

    // MARK: - Actions

    private func addFriend() {
        guard !friendName.isEmpty else { return }
        onAddNew(friendName.trimmingCharacters(in: .whitespacesAndNewlines))
        friendName = ""
        dismiss()
    }
}

// MARK: - Recent Friend Row

struct RecentFriendRow: View {
    let friend: RecentFriend
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(friend.swiftUIColor)
                        .frame(width: 40, height: 40)

                    Text(friend.initials)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                // Name
                Text(friend.name)
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()

                // Add icon
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    AddFriendSheet(
        friendName: .constant(""),
        recentFriends: [
            RecentFriend(id: "1", name: "John Doe", color: "#4ECDC4", lastUsedAt: nil, useCount: 5),
            RecentFriend(id: "2", name: "Sarah Smith", color: "#FF6B6B", lastUsedAt: nil, useCount: 3),
            RecentFriend(id: "3", name: "Mike Johnson", color: "#FFE66D", lastUsedAt: nil, useCount: 2),
        ],
        existingParticipants: [],
        onAddNew: { _ in },
        onAddRecent: { _ in }
    )
}
