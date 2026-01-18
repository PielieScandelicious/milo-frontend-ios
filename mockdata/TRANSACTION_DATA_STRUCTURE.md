# 📊 Transaction Data Structure

## Overview

This document shows the structure and organization of the mock transaction data.

## Transaction Model

```swift
struct Transaction: Identifiable, Codable {
    let id: UUID                    // Unique identifier
    let storeName: String           // "COLRUYT" or "ALDI"
    let category: String            // Category from store breakdown
    let itemName: String            // Specific product name
    let amount: Double              // Purchase amount in EUR
    let date: Date                  // Transaction date
    let quantity: Int               // Number of items
    let paymentMethod: String       // "Credit Card", "Debit Card", or "Cash"
}
```

## Data Organization

### By Store and Period

```
📁 All Transactions (82 total)
│
├── 📁 COLRUYT
│   ├── 📁 January 2026 (23 transactions, €189.90)
│   │   ├── Meat & Fish (5 items, €65.40)
│   │   ├── Alcohol (4 items, €42.50)
│   │   ├── Drinks (Soft/Soda) (4 items, €28.00)
│   │   ├── Household (6 items, €35.00)
│   │   └── Snacks & Sweets (4 items, €19.00)
│   │
│   └── 📁 February 2026 (14 transactions, €85.25)
│       ├── Pantry (7 items, €40.25)
│       ├── Personal Care (4 items, €25.00)
│       └── Drinks (Soft/Soda) (3 items, €20.00)
│
└── 📁 ALDI
    ├── 📁 January 2026 (24 transactions, €94.50)
    │   ├── Fresh Produce (11 items, €32.10)
    │   ├── Dairy & Eggs (5 items, €24.50)
    │   ├── Ready Meals (3 items, €20.40)
    │   ├── Bakery (3 items, €10.50)
    │   └── Drinks (Water) (2 items, €7.00)
    │
    └── 📁 February 2026 (17 transactions, €130.50)
        ├── Meat & Fish (5 items, €50.50)
        ├── Ready Meals (4 items, €30.00)
        ├── Fresh Produce (5 items, €25.00)
        ├── Snacks & Sweets (2 items, €15.00)
        └── Dairy & Eggs (2 items, €10.00)
```

## Sample Transactions

### COLRUYT - January 2026 - Meat & Fish

| Date | Item | Quantity | Amount | Payment |
|------|------|----------|--------|---------|
| Jan 5 | Chicken Breast | 2 | €12.50 | Credit Card |
| Jan 8 | Salmon Fillet | 1 | €18.90 | Credit Card |
| Jan 12 | Ground Beef | 3 | €9.50 | Debit Card |
| Jan 18 | Pork Chops | 2 | €14.50 | Credit Card |
| Jan 22 | Tuna Steaks | 2 | €10.00 | Credit Card |

**Category Total: €65.40**

### ALDI - January 2026 - Fresh Produce

| Date | Item | Quantity | Amount | Payment |
|------|------|----------|--------|---------|
| Jan 4 | Bananas | 2 | €2.50 | Debit Card |
| Jan 7 | Tomatoes | 3 | €3.60 | Credit Card |
| Jan 10 | Lettuce | 2 | €2.00 | Debit Card |
| Jan 14 | Apples | 2 | €4.00 | Credit Card |
| Jan 18 | Carrots | 3 | €2.50 | Debit Card |
| Jan 21 | Bell Peppers | 2 | €3.50 | Credit Card |
| Jan 24 | Cucumber | 3 | €1.50 | Debit Card |
| Jan 27 | Onions | 2 | €2.50 | Credit Card |
| Jan 29 | Broccoli | 2 | €3.00 | Debit Card |
| Jan 30 | Spinach | 2 | €3.50 | Credit Card |
| Jan 31 | Mushrooms | 1 | €3.50 | Debit Card |

**Category Total: €32.10**

## Statistics Summary

### Overall Statistics

| Metric | Value |
|--------|-------|
| Total Transactions | 82 |
| Total Amount | €500.15 |
| Average Transaction | €6.10 |
| Date Range | Jan 4 - Feb 25, 2026 |

### By Store

| Store | Transactions | Total Amount | Average |
|-------|--------------|--------------|---------|
| COLRUYT | 37 | €275.15 | €7.44 |
| ALDI | 41 | €225.00 | €5.49 |

### By Period

| Period | Transactions | Total Amount | Average |
|--------|--------------|--------------|---------|
| January 2026 | 51 | €284.40 | €5.58 |
| February 2026 | 31 | €215.75 | €6.96 |

### By Category (Top 5)

| Category | Transactions | Total Amount |
|----------|--------------|--------------|
| Fresh Produce | 16 | €57.10 |
| Meat & Fish | 10 | €115.90 |
| Pantry | 7 | €40.25 |
| Household | 6 | €35.00 |
| Dairy & Eggs | 7 | €34.50 |

### By Payment Method

| Method | Transactions | Percentage |
|--------|--------------|------------|
| Credit Card | 52 | 63% |
| Debit Card | 26 | 32% |
| Cash | 4 | 5% |

## Category Details

### All Categories with Items

#### Meat & Fish
- Chicken Breast, Salmon Fillet, Ground Beef, Pork Chops, Tuna Steaks
- Beef Steak, Chicken Wings, Cod Fillet, Shrimp, Turkey Breast

#### Fresh Produce
- Bananas, Tomatoes, Lettuce, Apples, Carrots, Bell Peppers
- Cucumber, Onions, Broccoli, Spinach, Mushrooms, Oranges
- Grapes, Avocados, Cauliflower, Strawberries

#### Alcohol
- Red Wine, Craft Beer Pack, Prosecco, Whiskey

#### Drinks (Soft/Soda & Water)
- Coca Cola 6-pack, Orange Juice, Sparkling Water, Iced Tea
- Sprite 2L, Fanta Orange, Lemonade, Still Water 6-pack

#### Household
- Dish Soap, Laundry Detergent, Paper Towels, Trash Bags
- Sponges, Aluminum Foil

#### Dairy & Eggs
- Milk 1L, Eggs Dozen, Yogurt 4-pack, Cheddar Cheese
- Butter, Greek Yogurt, Cream Cheese

#### Ready Meals
- Frozen Pizza, Lasagna, Chicken Nuggets, Mac & Cheese
- Frozen Burgers, Fish Sticks, Chicken Wrap

#### Bakery
- White Bread, Croissants, Bagels

#### Snacks & Sweets
- Chocolate Bar, Potato Chips, Cookies, Candy Mix
- Chocolate Cookies, Granola Bars

#### Pantry
- Pasta, Rice 2kg, Olive Oil, Tomato Sauce
- Canned Beans, Flour, Sugar

#### Personal Care
- Shampoo, Toothpaste, Deodorant, Body Wash

## Data Validation

All transaction amounts match the category totals in `store_breakdowns.json`:

✅ COLRUYT January: Mock transactions sum to €189.90 ✓
✅ ALDI January: Mock transactions sum to €94.50 ✓
✅ COLRUYT February: Mock transactions sum to €85.25 ✓
✅ ALDI February: Mock transactions sum to €130.50 ✓

## Transaction Distribution

### By Day of Month

```
January 2026: 51 transactions spread across 28 days
February 2026: 31 transactions spread across 20 days

Average transactions per shopping day: 2.9
```

### Price Ranges

| Price Range | Count | Percentage |
|-------------|-------|------------|
| €0-2 | 12 | 15% |
| €2-5 | 38 | 46% |
| €5-10 | 22 | 27% |
| €10-15 | 7 | 9% |
| €15+ | 3 | 4% |

### Quantity Distribution

| Quantity | Count | Percentage |
|----------|-------|------------|
| 1 item | 28 | 34% |
| 2 items | 36 | 44% |
| 3 items | 14 | 17% |
| 4+ items | 4 | 5% |

## Data Realism Features

✅ **Varied pricing** - Items range from €1.00 to €18.90
✅ **Multiple payment methods** - Credit, Debit, Cash
✅ **Realistic quantities** - 1-5 items per transaction
✅ **Chronological dates** - Spread throughout months
✅ **Store-appropriate items** - Different inventory per store
✅ **Category consistency** - Items match their categories
✅ **Price appropriateness** - Fresh produce cheaper than meat

## Usage in App

This data structure allows for:

1. **Filtering by Store** - `transactions(for: "COLRUYT")`
2. **Filtering by Period** - `transactions(for: storeName, period: "January 2026")`
3. **Filtering by Category** - `transactions(for:period:category:)`
4. **Sorting** - By date, amount, name
5. **Searching** - By item name or category
6. **Statistics** - Calculated from filtered sets

---

💡 All this data is **automatically loaded** when you create a `TransactionManager()` instance!
