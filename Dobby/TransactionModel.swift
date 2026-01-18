//
//  TransactionModel.swift
//  Dobby
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import Foundation
import Combine

struct Transaction: Identifiable, Codable, Equatable {
    let id: UUID
    let storeName: String
    let category: String
    let itemName: String
    let amount: Double
    let date: Date
    let quantity: Int
    let paymentMethod: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case storeName = "store_name"
        case category
        case itemName = "item_name"
        case amount
        case date
        case quantity
        case paymentMethod = "payment_method"
    }
}

// MARK: - Mock Transaction Generator
extension Transaction {
    static func generateMockTransactions() -> [Transaction] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        var transactions: [Transaction] = []
        
        // COLRUYT - January 2026
        transactions.append(contentsOf: [
            // Meat & Fish (€65.40 total)
            Transaction(id: UUID(), storeName: "COLRUYT", category: "Meat & Fish", itemName: "Chicken Breast", amount: 12.50, date: dateFormatter.date(from: "2026-01-05")!, quantity: 2, paymentMethod: "Credit Card"),
            Transaction(id: UUID(), storeName: "COLRUYT", category: "Meat & Fish", itemName: "Salmon Fillet", amount: 18.90, date: dateFormatter.date(from: "2026-01-08")!, quantity: 1, paymentMethod: "Credit Card"),
            Transaction(id: UUID(), storeName: "COLRUYT", category: "Meat & Fish", itemName: "Ground Beef", amount: 9.50, date: dateFormatter.date(from: "2026-01-12")!, quantity: 3, paymentMethod: "Debit Card"),
            Transaction(id: UUID(), storeName: "COLRUYT", category: "Meat & Fish", itemName: "Pork Chops", amount: 14.50, date: dateFormatter.date(from: "2026-01-18")!, quantity: 2, paymentMethod: "Credit Card"),
            Transaction(id: UUID(), storeName: "COLRUYT", category: "Meat & Fish", itemName: "Tuna Steaks", amount: 10.00, date: dateFormatter.date(from: "2026-01-22")!, quantity: 2, paymentMethod: "Credit Card"),
            
            // Alcohol (€42.50 total)
            Transaction(id: UUID(), storeName: "COLRUYT", category: "Alcohol", itemName: "Red Wine", amount: 15.00, date: dateFormatter.date(from: "2026-01-06")!, quantity: 2, paymentMethod: "Credit Card"),
            Transaction(id: UUID(), storeName: "COLRUYT", category: "Alcohol", itemName: "Craft Beer Pack", amount: 12.50, date: dateFormatter.date(from: "2026-01-10")!, quantity: 1, paymentMethod: "Credit Card"),
            Transaction(id: UUID(), storeName: "COLRUYT", category: "Alcohol", itemName: "Prosecco", amount: 9.00, date: dateFormatter.date(from: "2026-01-15")!, quantity: 1, paymentMethod: "Debit Card"),
            Transaction(id: UUID(), storeName: "COLRUYT", category: "Alcohol", itemName: "Whiskey", amount: 6.00, date: dateFormatter.date(from: "2026-01-20")!, quantity: 1, paymentMethod: "Credit Card"),
            
            // Drinks (Soft/Soda) (€28.00 total)
            Transaction(id: UUID(), storeName: "COLRUYT", category: "Drinks (Soft/Soda)", itemName: "Coca Cola 6-pack", amount: 7.50, date: dateFormatter.date(from: "2026-01-07")!, quantity: 2, paymentMethod: "Credit Card"),
            Transaction(id: UUID(), storeName: "COLRUYT", category: "Drinks (Soft/Soda)", itemName: "Orange Juice", amount: 4.50, date: dateFormatter.date(from: "2026-01-11")!, quantity: 3, paymentMethod: "Debit Card"),
            Transaction(id: UUID(), storeName: "COLRUYT", category: "Drinks (Soft/Soda)", itemName: "Sparkling Water", amount: 8.00, date: dateFormatter.date(from: "2026-01-14")!, quantity: 4, paymentMethod: "Credit Card"),
            Transaction(id: UUID(), storeName: "COLRUYT", category: "Drinks (Soft/Soda)", itemName: "Iced Tea", amount: 8.00, date: dateFormatter.date(from: "2026-01-19")!, quantity: 3, paymentMethod: "Credit Card"),
            
            // Household (€35.00 total)
            Transaction(id: UUID(), storeName: "COLRUYT", category: "Household", itemName: "Dish Soap", amount: 3.50, date: dateFormatter.date(from: "2026-01-09")!, quantity: 2, paymentMethod: "Credit Card"),
            Transaction(id: UUID(), storeName: "COLRUYT", category: "Household", itemName: "Laundry Detergent", amount: 12.00, date: dateFormatter.date(from: "2026-01-13")!, quantity: 1, paymentMethod: "Debit Card"),
            Transaction(id: UUID(), storeName: "COLRUYT", category: "Household", itemName: "Paper Towels", amount: 6.50, date: dateFormatter.date(from: "2026-01-16")!, quantity: 2, paymentMethod: "Credit Card"),
            Transaction(id: UUID(), storeName: "COLRUYT", category: "Household", itemName: "Trash Bags", amount: 5.00, date: dateFormatter.date(from: "2026-01-21")!, quantity: 1, paymentMethod: "Credit Card"),
            Transaction(id: UUID(), storeName: "COLRUYT", category: "Household", itemName: "Sponges", amount: 4.00, date: dateFormatter.date(from: "2026-01-25")!, quantity: 4, paymentMethod: "Debit Card"),
            Transaction(id: UUID(), storeName: "COLRUYT", category: "Household", itemName: "Aluminum Foil", amount: 4.00, date: dateFormatter.date(from: "2026-01-28")!, quantity: 1, paymentMethod: "Credit Card"),
            
            // Snacks & Sweets (€19.00 total)
            Transaction(id: UUID(), storeName: "COLRUYT", category: "Snacks & Sweets", itemName: "Chocolate Bar", amount: 4.50, date: dateFormatter.date(from: "2026-01-08")!, quantity: 3, paymentMethod: "Cash"),
            Transaction(id: UUID(), storeName: "COLRUYT", category: "Snacks & Sweets", itemName: "Potato Chips", amount: 4.00, date: dateFormatter.date(from: "2026-01-12")!, quantity: 2, paymentMethod: "Credit Card"),
            Transaction(id: UUID(), storeName: "COLRUYT", category: "Snacks & Sweets", itemName: "Cookies", amount: 5.50, date: dateFormatter.date(from: "2026-01-17")!, quantity: 2, paymentMethod: "Debit Card"),
            Transaction(id: UUID(), storeName: "COLRUYT", category: "Snacks & Sweets", itemName: "Candy Mix", amount: 5.00, date: dateFormatter.date(from: "2026-01-23")!, quantity: 2, paymentMethod: "Cash"),
        ])
        
        // ALDI - January 2026
        transactions.append(contentsOf: [
            // Fresh Produce (€32.10 total)
            Transaction(id: UUID(), storeName: "ALDI", category: "Fresh Produce", itemName: "Bananas", amount: 2.50, date: dateFormatter.date(from: "2026-01-04")!, quantity: 2, paymentMethod: "Debit Card"),
            Transaction(id: UUID(), storeName: "ALDI", category: "Fresh Produce", itemName: "Tomatoes", amount: 3.60, date: dateFormatter.date(from: "2026-01-07")!, quantity: 3, paymentMethod: "Credit Card"),
            Transaction(id: UUID(), storeName: "ALDI", category: "Fresh Produce", itemName: "Lettuce", amount: 2.00, date: dateFormatter.date(from: "2026-01-10")!, quantity: 2, paymentMethod: "Debit Card"),
            Transaction(id: UUID(), storeName: "ALDI", category: "Fresh Produce", itemName: "Apples", amount: 4.00, date: dateFormatter.date(from: "2026-01-14")!, quantity: 2, paymentMethod: "Credit Card"),
            Transaction(id: UUID(), storeName: "ALDI", category: "Fresh Produce", itemName: "Carrots", amount: 2.50, date: dateFormatter.date(from: "2026-01-18")!, quantity: 3, paymentMethod: "Debit Card"),
            Transaction(id: UUID(), storeName: "ALDI", category: "Fresh Produce", itemName: "Bell Peppers", amount: 3.50, date: dateFormatter.date(from: "2026-01-21")!, quantity: 2, paymentMethod: "Credit Card"),
            Transaction(id: UUID(), storeName: "ALDI", category: "Fresh Produce", itemName: "Cucumber", amount: 1.50, date: dateFormatter.date(from: "2026-01-24")!, quantity: 3, paymentMethod: "Debit Card"),
            Transaction(id: UUID(), storeName: "ALDI", category: "Fresh Produce", itemName: "Onions", amount: 2.50, date: dateFormatter.date(from: "2026-01-27")!, quantity: 2, paymentMethod: "Credit Card"),
            Transaction(id: UUID(), storeName: "ALDI", category: "Fresh Produce", itemName: "Broccoli", amount: 3.00, date: dateFormatter.date(from: "2026-01-29")!, quantity: 2, paymentMethod: "Debit Card"),
            Transaction(id: UUID(), storeName: "ALDI", category: "Fresh Produce", itemName: "Spinach", amount: 3.50, date: dateFormatter.date(from: "2026-01-30")!, quantity: 2, paymentMethod: "Credit Card"),
            Transaction(id: UUID(), storeName: "ALDI", category: "Fresh Produce", itemName: "Mushrooms", amount: 3.50, date: dateFormatter.date(from: "2026-01-31")!, quantity: 1, paymentMethod: "Debit Card"),
            
            // Dairy & Eggs (€24.50 total)
            Transaction(id: UUID(), storeName: "ALDI", category: "Dairy & Eggs", itemName: "Milk 1L", amount: 1.20, date: dateFormatter.date(from: "2026-01-05")!, quantity: 4, paymentMethod: "Credit Card"),
            Transaction(id: UUID(), storeName: "ALDI", category: "Dairy & Eggs", itemName: "Eggs Dozen", amount: 3.50, date: dateFormatter.date(from: "2026-01-09")!, quantity: 2, paymentMethod: "Debit Card"),
            Transaction(id: UUID(), storeName: "ALDI", category: "Dairy & Eggs", itemName: "Yogurt 4-pack", amount: 2.80, date: dateFormatter.date(from: "2026-01-12")!, quantity: 3, paymentMethod: "Credit Card"),
            Transaction(id: UUID(), storeName: "ALDI", category: "Dairy & Eggs", itemName: "Cheddar Cheese", amount: 4.00, date: dateFormatter.date(from: "2026-01-16")!, quantity: 2, paymentMethod: "Debit Card"),
            Transaction(id: UUID(), storeName: "ALDI", category: "Dairy & Eggs", itemName: "Butter", amount: 2.50, date: dateFormatter.date(from: "2026-01-20")!, quantity: 2, paymentMethod: "Credit Card"),
            
            // Ready Meals (€20.40 total)
            Transaction(id: UUID(), storeName: "ALDI", category: "Ready Meals", itemName: "Frozen Pizza", amount: 4.00, date: dateFormatter.date(from: "2026-01-06")!, quantity: 3, paymentMethod: "Credit Card"),
            Transaction(id: UUID(), storeName: "ALDI", category: "Ready Meals", itemName: "Lasagna", amount: 5.40, date: dateFormatter.date(from: "2026-01-11")!, quantity: 1, paymentMethod: "Debit Card"),
            Transaction(id: UUID(), storeName: "ALDI", category: "Ready Meals", itemName: "Chicken Nuggets", amount: 3.00, date: dateFormatter.date(from: "2026-01-15")!, quantity: 2, paymentMethod: "Credit Card"),
            
            // Bakery (€10.50 total)
            Transaction(id: UUID(), storeName: "ALDI", category: "Bakery", itemName: "White Bread", amount: 1.50, date: dateFormatter.date(from: "2026-01-08")!, quantity: 3, paymentMethod: "Debit Card"),
            Transaction(id: UUID(), storeName: "ALDI", category: "Bakery", itemName: "Croissants", amount: 2.50, date: dateFormatter.date(from: "2026-01-13")!, quantity: 2, paymentMethod: "Credit Card"),
            Transaction(id: UUID(), storeName: "ALDI", category: "Bakery", itemName: "Bagels", amount: 1.00, date: dateFormatter.date(from: "2026-01-19")!, quantity: 1, paymentMethod: "Debit Card"),
            
            // Drinks (Water) (€7.00 total)
            Transaction(id: UUID(), storeName: "ALDI", category: "Drinks (Water)", itemName: "Still Water 6-pack", amount: 2.50, date: dateFormatter.date(from: "2026-01-10")!, quantity: 2, paymentMethod: "Credit Card"),
            Transaction(id: UUID(), storeName: "ALDI", category: "Drinks (Water)", itemName: "Sparkling Water", amount: 2.00, date: dateFormatter.date(from: "2026-01-22")!, quantity: 1, paymentMethod: "Debit Card"),
        ])
        
        // COLRUYT - February 2026
        transactions.append(contentsOf: [
            // Pantry (€40.25 total)
            Transaction(id: UUID(), storeName: "COLRUYT", category: "Pantry", itemName: "Pasta", amount: 2.50, date: dateFormatter.date(from: "2026-02-03")!, quantity: 4, paymentMethod: "Credit Card"),
            Transaction(id: UUID(), storeName: "COLRUYT", category: "Pantry", itemName: "Rice 2kg", amount: 5.00, date: dateFormatter.date(from: "2026-02-07")!, quantity: 2, paymentMethod: "Debit Card"),
            Transaction(id: UUID(), storeName: "COLRUYT", category: "Pantry", itemName: "Olive Oil", amount: 8.50, date: dateFormatter.date(from: "2026-02-10")!, quantity: 1, paymentMethod: "Credit Card"),
            Transaction(id: UUID(), storeName: "COLRUYT", category: "Pantry", itemName: "Tomato Sauce", amount: 2.25, date: dateFormatter.date(from: "2026-02-14")!, quantity: 3, paymentMethod: "Debit Card"),
            Transaction(id: UUID(), storeName: "COLRUYT", category: "Pantry", itemName: "Canned Beans", amount: 1.50, date: dateFormatter.date(from: "2026-02-18")!, quantity: 5, paymentMethod: "Credit Card"),
            Transaction(id: UUID(), storeName: "COLRUYT", category: "Pantry", itemName: "Flour", amount: 3.00, date: dateFormatter.date(from: "2026-02-21")!, quantity: 2, paymentMethod: "Debit Card"),
            Transaction(id: UUID(), storeName: "COLRUYT", category: "Pantry", itemName: "Sugar", amount: 2.50, date: dateFormatter.date(from: "2026-02-25")!, quantity: 2, paymentMethod: "Credit Card"),
            
            // Personal Care (€25.00 total)
            Transaction(id: UUID(), storeName: "COLRUYT", category: "Personal Care", itemName: "Shampoo", amount: 5.50, date: dateFormatter.date(from: "2026-02-05")!, quantity: 2, paymentMethod: "Credit Card"),
            Transaction(id: UUID(), storeName: "COLRUYT", category: "Personal Care", itemName: "Toothpaste", amount: 3.00, date: dateFormatter.date(from: "2026-02-09")!, quantity: 3, paymentMethod: "Debit Card"),
            Transaction(id: UUID(), storeName: "COLRUYT", category: "Personal Care", itemName: "Deodorant", amount: 4.50, date: dateFormatter.date(from: "2026-02-12")!, quantity: 2, paymentMethod: "Credit Card"),
            Transaction(id: UUID(), storeName: "COLRUYT", category: "Personal Care", itemName: "Body Wash", amount: 3.00, date: dateFormatter.date(from: "2026-02-16")!, quantity: 1, paymentMethod: "Debit Card"),
            
            // Drinks (Soft/Soda) (€20.00 total)
            Transaction(id: UUID(), storeName: "COLRUYT", category: "Drinks (Soft/Soda)", itemName: "Sprite 2L", amount: 2.50, date: dateFormatter.date(from: "2026-02-06")!, quantity: 4, paymentMethod: "Credit Card"),
            Transaction(id: UUID(), storeName: "COLRUYT", category: "Drinks (Soft/Soda)", itemName: "Fanta Orange", amount: 3.00, date: dateFormatter.date(from: "2026-02-11")!, quantity: 2, paymentMethod: "Debit Card"),
            Transaction(id: UUID(), storeName: "COLRUYT", category: "Drinks (Soft/Soda)", itemName: "Lemonade", amount: 2.50, date: dateFormatter.date(from: "2026-02-20")!, quantity: 2, paymentMethod: "Credit Card"),
        ])
        
        // ALDI - February 2026
        transactions.append(contentsOf: [
            // Meat & Fish (€50.50 total)
            Transaction(id: UUID(), storeName: "ALDI", category: "Meat & Fish", itemName: "Beef Steak", amount: 15.00, date: dateFormatter.date(from: "2026-02-04")!, quantity: 2, paymentMethod: "Credit Card"),
            Transaction(id: UUID(), storeName: "ALDI", category: "Meat & Fish", itemName: "Chicken Wings", amount: 8.50, date: dateFormatter.date(from: "2026-02-08")!, quantity: 2, paymentMethod: "Debit Card"),
            Transaction(id: UUID(), storeName: "ALDI", category: "Meat & Fish", itemName: "Cod Fillet", amount: 12.00, date: dateFormatter.date(from: "2026-02-13")!, quantity: 1, paymentMethod: "Credit Card"),
            Transaction(id: UUID(), storeName: "ALDI", category: "Meat & Fish", itemName: "Shrimp", amount: 9.00, date: dateFormatter.date(from: "2026-02-17")!, quantity: 1, paymentMethod: "Debit Card"),
            Transaction(id: UUID(), storeName: "ALDI", category: "Meat & Fish", itemName: "Turkey Breast", amount: 6.00, date: dateFormatter.date(from: "2026-02-22")!, quantity: 1, paymentMethod: "Credit Card"),
            
            // Ready Meals (€30.00 total)
            Transaction(id: UUID(), storeName: "ALDI", category: "Ready Meals", itemName: "Mac & Cheese", amount: 4.50, date: dateFormatter.date(from: "2026-02-05")!, quantity: 3, paymentMethod: "Credit Card"),
            Transaction(id: UUID(), storeName: "ALDI", category: "Ready Meals", itemName: "Frozen Burgers", amount: 6.00, date: dateFormatter.date(from: "2026-02-10")!, quantity: 2, paymentMethod: "Debit Card"),
            Transaction(id: UUID(), storeName: "ALDI", category: "Ready Meals", itemName: "Fish Sticks", amount: 5.00, date: dateFormatter.date(from: "2026-02-15")!, quantity: 2, paymentMethod: "Credit Card"),
            Transaction(id: UUID(), storeName: "ALDI", category: "Ready Meals", itemName: "Chicken Wrap", amount: 3.50, date: dateFormatter.date(from: "2026-02-19")!, quantity: 2, paymentMethod: "Debit Card"),
            
            // Fresh Produce (€25.00 total)
            Transaction(id: UUID(), storeName: "ALDI", category: "Fresh Produce", itemName: "Oranges", amount: 3.50, date: dateFormatter.date(from: "2026-02-06")!, quantity: 2, paymentMethod: "Credit Card"),
            Transaction(id: UUID(), storeName: "ALDI", category: "Fresh Produce", itemName: "Grapes", amount: 4.00, date: dateFormatter.date(from: "2026-02-11")!, quantity: 2, paymentMethod: "Debit Card"),
            Transaction(id: UUID(), storeName: "ALDI", category: "Fresh Produce", itemName: "Avocados", amount: 3.00, date: dateFormatter.date(from: "2026-02-14")!, quantity: 3, paymentMethod: "Credit Card"),
            Transaction(id: UUID(), storeName: "ALDI", category: "Fresh Produce", itemName: "Cauliflower", amount: 2.50, date: dateFormatter.date(from: "2026-02-18")!, quantity: 2, paymentMethod: "Debit Card"),
            Transaction(id: UUID(), storeName: "ALDI", category: "Fresh Produce", itemName: "Strawberries", amount: 4.00, date: dateFormatter.date(from: "2026-02-23")!, quantity: 2, paymentMethod: "Credit Card"),
            
            // Snacks & Sweets (€15.00 total)
            Transaction(id: UUID(), storeName: "ALDI", category: "Snacks & Sweets", itemName: "Chocolate Cookies", amount: 3.00, date: dateFormatter.date(from: "2026-02-07")!, quantity: 3, paymentMethod: "Credit Card"),
            Transaction(id: UUID(), storeName: "ALDI", category: "Snacks & Sweets", itemName: "Granola Bars", amount: 3.00, date: dateFormatter.date(from: "2026-02-12")!, quantity: 2, paymentMethod: "Debit Card"),
            
            // Dairy & Eggs (€10.00 total)
            Transaction(id: UUID(), storeName: "ALDI", category: "Dairy & Eggs", itemName: "Greek Yogurt", amount: 4.00, date: dateFormatter.date(from: "2026-02-09")!, quantity: 2, paymentMethod: "Credit Card"),
            Transaction(id: UUID(), storeName: "ALDI", category: "Dairy & Eggs", itemName: "Cream Cheese", amount: 3.00, date: dateFormatter.date(from: "2026-02-16")!, quantity: 2, paymentMethod: "Debit Card"),
        ])
        
        return transactions
    }
}

// MARK: - Transaction Manager
class TransactionManager: ObservableObject {
    @Published var transactions: [Transaction] = []
    
    init() {
        loadTransactions()
    }
    
    func loadTransactions() {
        transactions = Transaction.generateMockTransactions()
    }
    
    // Add new transactions
    func addTransactions(_ newTransactions: [Transaction]) {
        transactions.append(contentsOf: newTransactions)
        // Sort by date
        transactions.sort { $0.date > $1.date }
    }
    
    // Add a single transaction
    func addTransaction(_ transaction: Transaction) {
        transactions.append(transaction)
        transactions.sort { $0.date > $1.date }
    }
    
    // Delete a transaction
    func deleteTransaction(_ transaction: Transaction) {
        transactions.removeAll { $0.id == transaction.id }
    }
    
    // Get transactions for a specific store and period
    func transactions(for storeName: String, period: String) -> [Transaction] {
        let calendar = Calendar.current
        let periodComponents = period.components(separatedBy: " ")
        
        guard periodComponents.count == 2,
              let month = DateFormatter().monthSymbols.firstIndex(of: periodComponents[0]),
              let year = Int(periodComponents[1]) else {
            return []
        }
        
        return transactions.filter { transaction in
            let transactionComponents = calendar.dateComponents([.month, .year], from: transaction.date)
            return transaction.storeName == storeName &&
                   transactionComponents.month == month + 1 &&
                   transactionComponents.year == year
        }.sorted { $0.date > $1.date }
    }
    
    // Get transactions for a specific category
    func transactions(for storeName: String, period: String, category: String) -> [Transaction] {
        transactions(for: storeName, period: period)
            .filter { $0.category == category }
            .sorted { $0.date > $1.date }
    }
}
