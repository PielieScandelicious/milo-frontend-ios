//
//  GroceryListSheet.swift
//  Scandalicious
//

import SwiftUI

struct GroceryListSheet: View {
    @ObservedObject private var store = GroceryListStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var checkedTrigger = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Premium dark gradient background
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.06, green: 0.09, blue: 0.14), location: 0.0),
                        .init(color: Color(red: 0.04, green: 0.06, blue: 0.10), location: 0.4),
                        .init(color: Color(red: 0.03, green: 0.04, blue: 0.07), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                if store.activeItems.isEmpty {
                    emptyState
                } else {
                    listContent
                }
            }
            .navigationTitle(L("grocery_list"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("done")) { dismiss() }
                        .foregroundColor(.white.opacity(0.7))
                }

                if store.activeItems.contains(where: { $0.isChecked }) {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                store.removeChecked()
                            }
                        } label: {
                            Text(L("clear_checked"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.red.opacity(0.8))
                        }
                    }
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: checkedTrigger)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            store.removeExpired()
        }
    }

    // MARK: - List Content

    private var listContent: some View {
        List {
            // Summary header
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(store.activeItemCount) \(store.activeItemCount == 1 ? "item" : "items")")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        if store.uncheckedCount < store.activeItemCount {
                            Text("\(store.uncheckedCount) remaining")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    Spacer()
                    if store.totalSavings > 0 {
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(L("total_savings"))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                                .textCase(.uppercase)
                            Text(String(format: "€%.2f", store.totalSavings))
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(Color(red: 0.20, green: 0.85, blue: 0.50))
                        }
                    }
                }
                .padding(.vertical, 4)
                .listRowBackground(
                    Color(red: 0.20, green: 0.85, blue: 0.50).opacity(0.08)
                )
            }

            // Store sections
            ForEach(store.itemsByStore, id: \.storeName) { section in
                Section {
                    ForEach(section.items) { item in
                        GroceryListItemRow(
                            item: item,
                            onToggleChecked: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    store.toggleChecked(id: item.id)
                                }
                                checkedTrigger.toggle()
                            },
                            onDelete: {
                                withAnimation {
                                    store.remove(id: item.id)
                                }
                            }
                        )
                        .listRowBackground(Color.white.opacity(0.06))
                    }
                } header: {
                    HStack(spacing: 8) {
                        StoreLogoView(storeName: section.storeName, height: 18)
                        Text(GroceryStore.fromCanonical(section.storeName)?.displayName ?? section.storeName.capitalized)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        let storeSavings = section.items.reduce(0.0) { $0 + $1.savings }
                        if storeSavings > 0 {
                            Text(String(format: "-€%.2f", storeSavings))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(Color(red: 0.20, green: 0.85, blue: 0.50).opacity(0.8))
                        }
                        Text("\(section.items.count)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label(L("grocery_list_empty_title"), systemImage: "cart")
                .foregroundColor(.white.opacity(0.6))
        } description: {
            Text(L("grocery_list_empty_description"))
                .foregroundColor(.white.opacity(0.4))
        } actions: {
            Button {
                dismiss()
            } label: {
                Text(L("browse_deals_to_add"))
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.20, green: 0.85, blue: 0.50))
        }
    }
}
