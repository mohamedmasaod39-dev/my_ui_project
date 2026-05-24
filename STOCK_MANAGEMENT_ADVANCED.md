# Stock Deduction - Advanced Options & Best Practices

## Three Approaches to Stock Management

This guide explains the pros/cons of each approach and when to use them.

---

## Approach 1: Deduct at Checkout ✅ RECOMMENDED

**File**: `supabase_fix_stock_deduction.sql` (default)

### How It Works:
- Stock is decremented when order items are inserted (immediately after checkout)
- Prevents overselling of products
- Most accurate inventory tracking

### Trigger:
```sql
CREATE TRIGGER trg_deduct_stock_after_order_items
AFTER INSERT ON public.order_items
FOR EACH ROW
EXECUTE FUNCTION public.deduct_stock_on_order_creation();
```

### Pros:
✅ Prevents overselling (stock reserved immediately)  
✅ Accurate, real-time inventory  
✅ Simple logic - straightforward for developers  
✅ Best for fast-moving inventory  

### Cons:
❌ If orders are cancelled, must restore stock manually (you'd need cancellation logic)  
❌ Tied-up inventory if customers don't complete orders  

### When to Use:
- Physical products with limited stock
- Fast-moving inventory (drops in minutes)
- Popular items that sell out quickly
- When overselling would cause fulfillment issues

### Implementation:
Just run the default `supabase_fix_stock_deduction.sql`

---

## Approach 2: Deduct at Delivery

**When**: Stock decrements only when order status changes to `'delivered'`

### How It Works:
- Product remains "available" in cart until delivery confirmed
- Stock deducts when seller confirms delivery
- Allows for cancellations without manual stock restoration

### Trigger Code:
```sql
CREATE OR REPLACE FUNCTION public.deduct_stock_on_delivery()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    item_record RECORD;
BEGIN
    IF (OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'delivered') THEN
        FOR item_record IN 
            SELECT product_id, quantity FROM public.order_items 
            WHERE order_id = NEW.id
        LOOP
            UPDATE public.products 
            SET stock_qty = GREATEST(0, stock_qty - item_record.quantity)
            WHERE id = item_record.product_id;
        END LOOP;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_deduct_stock_on_delivery
AFTER UPDATE ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.deduct_stock_on_delivery();
```

### Pros:
✅ Simplifies order cancellation (no stock restoration needed)  
✅ Real-time inventory while order is in transit  
✅ Works for subscription-based or pre-order models  

### Cons:
❌ Risk of overselling (product can be purchased multiple times)  
❌ Stock appears available even though orders are pending  
❌ More complex cancellation logic needed  

### When to Use:
- Made-to-order products
- Subscription services
- Products with high margins and high quantity
- When your fulfillment team needs flexibility

### To Switch to This Approach:
1. Open `supabase_fix_stock_deduction.sql`
2. Comment out the first trigger (lines 1-35)
3. Uncomment the alternative trigger (lines 40-73)
4. Run the SQL

---

## Approach 3: Reserved Stock System

**When**: Separate tracking of reserved vs. available stock

### How It Works:
- Maintains two columns: `stock_qty` (available) and `reserved_qty`
- At checkout: Move quantity from `stock_qty` to `reserved_qty`
- At delivery: Remove from `reserved_qty`
- At cancellation: Move back from `reserved_qty` to `stock_qty`

### Database Schema Changes:
```sql
-- Add column to products table if it doesn't exist
ALTER TABLE public.products 
ADD COLUMN reserved_qty INT DEFAULT 0;

-- Show available stock as calculated column in queries
SELECT 
    id, 
    title, 
    stock_qty, 
    reserved_qty,
    (stock_qty - reserved_qty) as available_qty
FROM public.products;
```

### Trigger Code:
```sql
CREATE OR REPLACE FUNCTION public.reserve_stock_on_order()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    item_record RECORD;
BEGIN
    FOR item_record IN 
        SELECT product_id, quantity FROM public.order_items 
        WHERE order_id = NEW.id
    LOOP
        UPDATE public.products 
        SET reserved_qty = GREATEST(0, reserved_qty + item_record.quantity)
        WHERE id = item_record.product_id;
    END LOOP;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_reserve_stock_on_order
AFTER INSERT ON public.order_items
FOR EACH ROW
EXECUTE FUNCTION public.reserve_stock_on_order();
```

### Pros:
✅ Prevents overselling  
✅ Easy cancellation handling  
✅ Clear visibility of reserved vs available stock  
✅ Can handle complex workflows  

### Cons:
❌ Requires database schema migration  
❌ More complex logic in queries  
❌ Need to update cart validation code  

### When to Use:
- Complex order workflows
- Multi-step purchasing (e.g., marketplace with escrow)
- When you need to track both available and reserved separately
- High-value items with long fulfillment times

---

## Comparison Table

| Feature | Approach 1 (Checkout) | Approach 2 (Delivery) | Approach 3 (Reserved) |
|---------|----------------------|----------------------|----------------------|
| **Prevents Overselling** | ✅ Yes | ❌ No | ✅ Yes |
| **Cancellation Handling** | ❌ Manual restore needed | ✅ Automatic | ✅ Automatic |
| **Real-time Accuracy** | ✅ High | ⚠️ Medium | ✅ High |
| **Database Changes** | ❌ None | ❌ None | ✅ Schema migration |
| **Code Complexity** | ✅ Simple | ⚠️ Medium | ❌ Complex |
| **Best For** | Fast-moving inventory | Flexible orders | Complex workflows |

---

## Current Implementation Status

### Default (Recommended):
**Approach 1 - Deduct at Checkout**

This is what's in `supabase_fix_stock_deduction.sql` and gives you:
- ✅ Stock decreases by exact quantity purchased
- ✅ Stock is reserved at checkout
- ✅ No overselling
- ✅ Simple implementation

### To Switch Approaches:

**To Approach 2 (Deduct at Delivery)**:
```bash
# Edit supabase_fix_stock_deduction.sql
# Comment lines 13-35 (Approach 1 trigger)
# Uncomment lines 40-73 (Approach 2 trigger)
# Run in Supabase SQL editor
```

**To Approach 3 (Reserved Stock)**:
1. Add `reserved_qty` column to products table
2. Create new trigger functions for reserve/unreserve
3. Update cart validation to use `available_qty`
4. Update order cancellation to unreserve stock

---

## Additional Safety Features

### 1. Stock Validation Before Insertion
Add this to your Dart checkout code to double-check:

```dart
// Before inserting order items, verify stock exists
for (final item in orderItems) {
    final product = await supabase
        .from('products')
        .select('stock_qty')
        .eq('id', item.product_id)
        .single();
    
    if (product['stock_qty'] < item.quantity) {
        throw Exception('Insufficient stock for ${item.product_name}');
    }
}
```

### 2. Logging Stock Changes
Add audit logging to track all stock changes:

```sql
CREATE TABLE public.stock_audit_log (
    id BIGSERIAL PRIMARY KEY,
    product_id BIGINT NOT NULL,
    order_id INT,
    quantity_changed INT,
    previous_stock INT,
    new_stock INT,
    change_reason TEXT,
    changed_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (product_id) REFERENCES products(id),
    FOREIGN KEY (order_id) REFERENCES orders(id)
);

-- Update trigger to log changes
-- INSERT INTO stock_audit_log (...) as part of stock deduction
```

### 3. Stock Alert for Low Inventory
Notify sellers when stock is running low:

```sql
CREATE OR REPLACE FUNCTION public.alert_low_stock()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.stock_qty < 5 AND OLD.stock_qty >= 5 THEN
        INSERT INTO public.notifications (user_id, title, body, type)
        SELECT seller_id, 'Low Stock Alert', 'Product "' || NEW.title || '" stock is running low (' || NEW.stock_qty || ' left)', 'alert'
        WHERE seller_id = NEW.seller_id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_alert_low_stock
AFTER UPDATE ON public.products
FOR EACH ROW
EXECUTE FUNCTION public.alert_low_stock();
```

---

## Troubleshooting Decision Tree

```
Is stock decreasing?
├─ YES: Is it decreasing by the correct quantity?
│   ├─ YES: ✅ Issue is FIXED! All done
│   └─ NO: Multiple items showing quantity not correct?
│       ├─ YES: Check that you're buying multiple items in same order
│       └─ NO: Check order_items table for quantity values
│
└─ NO: Stock not changing at all?
    ├─ Check if trigger exists:
    │   SELECT * FROM information_schema.triggers WHERE trigger_name = 'trg_deduct_stock_after_order_items'
    │
    ├─ Check if order_items are being created:
    │   SELECT * FROM order_items WHERE order_id = <YOUR_TEST_ORDER>
    │
    └─ Check Supabase logs for trigger errors
```

---

## Recommendation

**Use Approach 1 (Checkout Deduction)** - the default in `supabase_fix_stock_deduction.sql`.

It's the best balance for a marketplace:
- Prevents overselling
- Simple implementation
- Accurate inventory
- Most stable for production

Only switch to Approach 2 or 3 if you have specific business requirements that demand it.
