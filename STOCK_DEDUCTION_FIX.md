# Stock Deduction Fix - Implementation Guide

## Problem Summary
Your marketplace app was only decreasing product stock by **1 unit** instead of the **exact quantity purchased**, even when customers bought multiple items.

**Root Cause**: Multiple conflicting SQL triggers with incorrect logic, causing stock deduction issues.

---

## Solution Overview

### What Changed:
1. **Removed** all conflicting triggers from previous SQL files
2. **Created** a single, clean trigger that deducts stock by the EXACT quantity
3. **Trigger fires** when order items are inserted (at checkout time)

### Why This Works:
- The new trigger reads the `quantity` field from `order_items` table correctly
- It uses `GREATEST(0, stock_qty - item_record.quantity)` to ensure stock never goes negative
- It fires AFTER order items are inserted, guaranteeing correct data

---

## Implementation Steps

### Step 1: Run the SQL Fix
Execute the SQL in `supabase_fix_stock_deduction.sql` in your Supabase SQL editor:

**Path**: `/supabase_fix_stock_deduction.sql`

This will:
- ✅ Drop all conflicting triggers
- ✅ Remove old stock deduction functions
- ✅ Create a new, correct trigger `trg_deduct_stock_after_order_items`
- ✅ Ensure stock deduction happens at checkout time

### Step 2: Verify the Fix
After running the SQL, test your checkout flow:

1. **Before Checkout**: Note the stock quantity of a product
2. **Add to Cart**: Add 3+ items of the same product
3. **Complete Checkout**: Finish the purchase
4. **Check Stock**: Go to the product and verify stock decreased by EXACTLY the quantity you bought

**Expected Result**: If you bought 3 items, stock should decrease by 3 (not by 1)

### Step 3: Optional - Clear Test Data
If you have test orders from before the fix, manually correct the stock:

```sql
-- Manual stock correction (if needed)
UPDATE public.products 
SET stock_qty = GREATEST(0, stock_qty + 1) 
WHERE id = YOUR_PRODUCT_ID;
```

---

## How Stock Deduction Now Works

### Timeline of Stock Updates:

| Step | Action | Stock Status |
|------|--------|--------------|
| 1 | Browse products | No change |
| 2 | Add to cart | No change |
| 3 | Initiate checkout | No change |
| 4 | **Order created** | No change (yet) |
| 5 | **Order items inserted** | ✅ **Stock DECREMENTED by exact quantity** |
| 6 | Order confirmation | No change |
| 7 | Delivery/Fulfillment | No change (stock already deducted) |

---

## Key Changes in Database

### Trigger Removed:
- `tr_on_order_status_update` (was in `supabase_notifications_triggers.sql`)
- `trg_deduct_stock_on_delivery` (conflicting implementations)
- `trg_finalize_order_cancellation`

### New Trigger Created:
- **Name**: `trg_deduct_stock_after_order_items`
- **Fires**: AFTER INSERT on `order_items` table
- **Action**: Decrements `products.stock_qty` by the exact `quantity` from `order_items`

### SQL Logic:
```sql
UPDATE public.products 
SET stock_qty = GREATEST(0, stock_qty - item_record.quantity)
WHERE id = item_record.product_id;
```

This correctly:
- ✅ Uses `item_record.quantity` (the actual quantity purchased)
- ✅ Prevents negative stock with `GREATEST(0, ...)`
- ✅ Updates the correct product

---

## Dart Code (No Changes Needed)

Your Flutter checkout code in `lib/pages/cart_page.dart` is **already correct**:

```dart
final orderItems = sellerItems
    .map((item) => {
        'order_id': orderId,
        'product_id': item.product.id,
        'quantity': item.quantity,  // ✅ This is correct
        // ... other fields
    })
    .toList();

await supabase.from('order_items').insert(orderItems);
```

The `quantity` field is properly inserted. The database trigger now reads it correctly.

---

## Troubleshooting

### Issue: Stock still not decreasing correctly
**Solution**: 
1. Verify the new trigger exists: 
   ```sql
   SELECT trigger_name FROM information_schema.triggers 
   WHERE trigger_name = 'trg_deduct_stock_after_order_items';
   ```
2. Check if old triggers still exist and remove them manually
3. Test a new order to see if stock updates

### Issue: Stock going negative
**Solution**: The `GREATEST(0, ...)` function prevents this. If it's happening:
1. Check if the trigger is failing silently
2. Look at Supabase logs for errors
3. Ensure `order_items` has valid `quantity` values

### Issue: Want to revert to delivery-based deduction
**Solution**: In the SQL file, uncomment the alternative trigger at the bottom and run it.

---

## Verification Query

Run this to confirm stock deduction is working:

```sql
-- Check a recent order's impact on stock
SELECT 
    oi.order_id,
    oi.product_id,
    oi.quantity,
    p.stock_qty,
    oi.product_name
FROM public.order_items oi
JOIN public.products p ON p.id = oi.product_id
WHERE oi.order_id = YOUR_RECENT_ORDER_ID
ORDER BY oi.created_at DESC;
```

The `stock_qty` should reflect the deduction from the quantity purchased.

---

## Next Steps

1. ✅ Run the SQL fix file
2. ✅ Test with a test purchase
3. ✅ Verify stock decreases by exact quantity
4. ✅ Check your admin dashboard stats are accurate
5. ✅ Deploy to production

Your stock management is now fixed! 🎉
