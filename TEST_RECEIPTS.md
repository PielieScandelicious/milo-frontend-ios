# Test Receipts for Dobby App

Copy and paste these receipts into the app to test the AI categorization feature!

## Test Receipt 1: ALDI

```
ALDI
Store #1234
Rue de la Station 45
1000 Brussels, Belgium

Date: 18/01/2026
Time: 14:23

---------------------------
ITEMS
---------------------------
Bananas 1kg              2.50
Milk Semi-Skimmed 1L     1.20
Free Range Eggs (12)     3.50
Chicken Breast Fillet    8.50
Tomatoes 500g            2.80
White Bread              1.50
Butter 250g              2.50
Yogurt Natural 4x125g    2.80
Coca Cola 2L             2.10
Orange Juice 1L          2.50
Chocolate Bar            1.80
Potato Chips             1.50
---------------------------
SUBTOTAL:               33.70
---------------------------

Payment Method: Card
Card Number: ****1234

Thank you for shopping at ALDI!
Visit us at www.aldi.be
```

Expected Categories:
- Bananas → Fresh Produce
- Milk → Dairy & Eggs
- Eggs → Dairy & Eggs
- Chicken Breast → Meat & Fish
- Tomatoes → Fresh Produce
- White Bread → Bakery
- Butter → Dairy & Eggs
- Yogurt → Dairy & Eggs
- Coca Cola → Drinks (Soft/Soda)
- Orange Juice → Drinks (Soft/Soda)
- Chocolate Bar → Snacks & Sweets
- Potato Chips → Snacks & Sweets

---

## Test Receipt 2: COLRUYT

```
COLRUYT LOWEST PRICES
Store: Colruyt Leuven
Diestsestraat 100
3000 Leuven

Receipt #: 2026011800123
Date: 18/01/2026 16:45

================================
Ground Beef 500g         €9.50
Salmon Fillet 400g      €15.90
Red Wine Cabernet       €12.00
Craft Beer 6-pack        €8.50
Dish Soap               €3.50
Laundry Detergent      €12.00
Paper Towels            €6.50
Sponges 3-pack          €4.00
Shampoo Pantene         €5.50
Toothpaste Colgate      €3.00
Pasta Penne 500g        €1.50
Rice 2kg                €5.00
Olive Oil Extra Virgin  €8.50
Tomato Sauce            €2.25
Sparkling Water 6pk     €2.50
================================
TOTAL:                 €100.15
================================

Paid: Debit Card
Points Earned: 100

Thank you for choosing COLRUYT!
Your savings today: €15.20
```

Expected Categories:
- Ground Beef → Meat & Fish
- Salmon Fillet → Meat & Fish
- Red Wine → Alcohol
- Craft Beer → Alcohol
- Dish Soap → Household
- Laundry Detergent → Household
- Paper Towels → Household
- Sponges → Household
- Shampoo → Personal Care
- Toothpaste → Personal Care
- Pasta → Pantry
- Rice → Pantry
- Olive Oil → Pantry
- Tomato Sauce → Pantry
- Sparkling Water → Drinks (Water)

---

## Test Receipt 3: Mixed Categories

```
DELHAIZE
Your neighborhood supermarket
Avenue Louise 123, Brussels

Transaction: 2026-01-18 10:30:15
Cashier: Sophie

------------------------------------
Fresh Produce Section:
  Carrots 1kg                  2.50
  Bell Peppers Red 3pc         3.50
  Lettuce Iceberg              1.80
  Apples Gala 1.5kg            4.00

Meat & Seafood:
  Pork Chops 6pc              14.50
  Shrimp Frozen 500g           9.00

Frozen Foods:
  Frozen Pizza Margherita      4.00
  Chicken Nuggets 1kg          5.40
  Fish Sticks 450g             3.50

Dairy Aisle:
  Greek Yogurt 500g            3.80
  Cheddar Cheese 400g          5.20
  Cream Cheese 200g            2.90

Beverages:
  Still Water 6x1.5L           3.50
  Apple Juice 1L               2.80
  Prosecco                     9.00

Snacks & Candy:
  Chocolate Cookies            3.00
  Gummy Bears                  2.50
  Granola Bars 6pc             3.50

Bakery:
  Croissants 6pc               4.50
  Baguette                     1.20

------------------------------------
SUBTOTAL:                     €94.60
VAT (6%):                      €5.68
------------------------------------
TOTAL:                       €100.28
------------------------------------

Payment: MasterCard ending 5678
Loyalty Points: +94

Visit us online: www.delhaize.be
Thank you for shopping with us!
```

Expected Categories:
- Carrots → Fresh Produce
- Bell Peppers → Fresh Produce
- Lettuce → Fresh Produce
- Apples → Fresh Produce
- Pork Chops → Meat & Fish
- Shrimp → Meat & Fish
- Frozen Pizza → Ready Meals
- Chicken Nuggets → Ready Meals
- Fish Sticks → Ready Meals
- Greek Yogurt → Dairy & Eggs
- Cheddar Cheese → Dairy & Eggs
- Cream Cheese → Dairy & Eggs
- Still Water → Drinks (Water)
- Apple Juice → Drinks (Soft/Soda)
- Prosecco → Alcohol
- Chocolate Cookies → Snacks & Sweets
- Gummy Bears → Snacks & Sweets
- Granola Bars → Snacks & Sweets
- Croissants → Bakery
- Baguette → Bakery

---

## Test Receipt 4: Simple ALDI Receipt

```
ALDI
18/01/2026

Bananas                     2.50
Milk 1L                     1.20
Eggs                        3.50
Bread                       1.50

TOTAL: 8.70 EUR
```

This tests minimal receipt format!

---

## Test Receipt 5: LIDL

```
LIDL België
Mechelsesteenweg 55
2018 Antwerpen

18.01.2026  18:45
Bon: 0123

1  Bananen                   1.99
1  Volle melk 1L            0.99
1  Kip filet 500g           5.99
1  Brood wit                1.29
1  Eieren 10st              2.49
1  Coca-Cola 1.5L           1.49
1  Chips paprika            0.99
1  Chocolade reep           1.49
1  Sla                      1.29

Te betalen EUR             17.01
Betaald: Bancontact

Bedankt voor uw bezoek!
```

Expected Categories:
- Bananen (Bananas) → Fresh Produce
- Volle melk (Milk) → Dairy & Eggs
- Kip filet (Chicken) → Meat & Fish
- Brood (Bread) → Bakery
- Eieren (Eggs) → Dairy & Eggs
- Coca-Cola → Drinks (Soft/Soda)
- Chips → Snacks & Sweets
- Chocolade (Chocolate) → Snacks & Sweets
- Sla (Lettuce) → Fresh Produce

---

## How to Test

1. Open the Dobby app
2. Go to the "Scan" tab
3. Tap "Paste Receipt Text"
4. Copy and paste one of the receipts above
5. Tap "Process"
6. Wait for AI categorization
7. Review the results
8. Tap "Save" to add to your transactions
9. Go to "View" tab to see the data

## Tips for Testing

- Test with different receipt formats
- Try mixing multiple stores
- Test with receipts in different languages (Dutch, French, English)
- Verify that AI correctly categorizes ambiguous items
- Check that store detection works properly
- Try editing items before saving

## Testing Without Receipts

If you don't have access to real receipts:
1. Use the sample receipts above
2. Take a photo of your screen showing a receipt
3. Use the camera feature to scan the screen
4. The app should still extract the text!

Enjoy testing! 🛒✨
