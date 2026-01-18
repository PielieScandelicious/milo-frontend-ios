//
//  ReceiptReviewView.swift
//  Dobby
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import SwiftUI

struct ReceiptReviewView: View {
    let result: ReceiptImportResult
    let onSave: ([Transaction]) -> Void
    let onCancel: () -> Void
    
    @State private var editableTransactions: [Transaction]
    @State private var storeName: String
    @State private var receiptDate: Date
    
    init(result: ReceiptImportResult, onSave: @escaping ([Transaction]) -> Void, onCancel: @escaping () -> Void) {
        self.result = result
        self.onSave = onSave
        self.onCancel = onCancel
        
        _editableTransactions = State(wrappedValue: result.transactions)
        _storeName = State(wrappedValue: result.storeName)
        _receiptDate = State(wrappedValue: result.date)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                content
            }
            .background(Color(white: 0.05))
            .navigationTitle("Review Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // Update transactions with edited values
                        let finalTransactions: [Transaction] = editableTransactions.map { transaction in
                            let updatedTransaction = Transaction(
                                id: transaction.id,
                                storeName: storeName,
                                category: transaction.category,
                                itemName: transaction.itemName,
                                amount: transaction.amount,
                                date: receiptDate,
                                quantity: transaction.quantity,
                                paymentMethod: transaction.paymentMethod
                            )
                            return updatedTransaction
                        }
                        onSave(finalTransactions)
                    }
                    .disabled(editableTransactions.isEmpty)
                }
            }
        }
    }
    
    private var content: some View {
        VStack(spacing: 24) {
                    // Store Info Card
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Store")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    Image(systemName: "storefront.fill")
                                        .foregroundStyle(.blue.gradient)
                                    Text(storeName)
                                        .font(.title3.bold())
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 8) {
                                Text("Date")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                DatePicker("", selection: $receiptDate, displayedComponents: .date)
                                    .labelsHidden()
                            }
                        }
                        
                        // Detection Status
                        HStack {
                            Image(systemName: result.detectedStore == .unknown ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .foregroundColor(result.detectedStore == .unknown ? .orange : .green)
                            
                            Text(result.detectedStore == .unknown ? "Store not automatically detected" : "Store automatically detected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // Summary
                    HStack(spacing: 40) {
                        VStack(spacing: 4) {
                            Text("\(editableTransactions.count)")
                                .font(.title2.bold())
                            Text("Items")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(spacing: 4) {
                            Text(totalAmount, format: .currency(code: "EUR"))
                                .font(.title2.bold())
                            Text("Total")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(spacing: 4) {
                            Text("\(uniqueCategories)")
                                .font(.title2.bold())
                            Text("Categories")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // Items List
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Items")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        List {
                            ForEach(editableTransactions.indices, id: \.self) { index in
                                TransactionItemCard(
                                    transaction: $editableTransactions[index],
                                    onDelete: {
                                        withAnimation {
                                            _ = editableTransactions.remove(at: index)
                                        }
                                    }
                                )
                                .listRowBackground(Color(white: 0.05))
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            }
                        }
                        .listStyle(.plain)
                        .frame(minHeight: CGFloat(editableTransactions.count) * 80)
                        .scrollDisabled(true)
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.top)
    }
    
    private var totalAmount: Double {
        editableTransactions.reduce(0) { $0 + $1.amount }
    }
    
    private var uniqueCategories: Int {
        Set(editableTransactions.map { $0.category }).count
    }
}

// MARK: - Transaction Item Card
struct TransactionItemCard: View {
    @Binding var transaction: Transaction
    let onDelete: () -> Void
    
    @State private var showingEditor = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Category Icon
            VStack {
                Image(systemName: categoryIcon)
                    .font(.title3)
                    .foregroundStyle(.blue.gradient)
                    .frame(width: 40, height: 40)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Item Details
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.itemName)
                    .font(.body)
                    .fontWeight(.medium)
                
                HStack {
                    Text(transaction.category)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text("Qty: \(transaction.quantity)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Amount
            Text(transaction.amount, format: .currency(code: "EUR"))
                .font(.headline)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button {
                showingEditor = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private var categoryIcon: String {
        switch transaction.category {
        case "Meat & Fish":
            return "fish.fill"
        case "Alcohol":
            return "wineglass.fill"
        case "Drinks (Soft/Soda)", "Drinks (Water)":
            return "drop.fill"
        case "Household":
            return "house.fill"
        case "Snacks & Sweets":
            return "cookie.fill"
        case "Fresh Produce":
            return "carrot.fill"
        case "Dairy & Eggs":
            return "birthday.cake.fill"
        case "Ready Meals":
            return "fork.knife"
        case "Bakery":
            return "croissant.fill"
        case "Pantry":
            return "cabinet.fill"
        case "Personal Care":
            return "hands.sparkles.fill"
        default:
            return "tag.fill"
        }
    }
}

#Preview {
    ReceiptReviewView(
        result: ReceiptImportResult(
            storeName: "ALDI",
            receiptText: "Sample receipt",
            detectedStore: .aldi,
            date: Date(),
            transactions: [
                Transaction(
                    id: UUID(),
                    storeName: "ALDI",
                    category: "Fresh Produce",
                    itemName: "Bananas",
                    amount: 2.50,
                    date: Date(),
                    quantity: 2,
                    paymentMethod: "Credit Card"
                ),
                Transaction(
                    id: UUID(),
                    storeName: "ALDI",
                    category: "Dairy & Eggs",
                    itemName: "Milk 1L",
                    amount: 1.20,
                    date: Date(),
                    quantity: 1,
                    paymentMethod: "Credit Card"
                )
            ]
        ),
        onSave: { _ in },
        onCancel: { }
    )
}
