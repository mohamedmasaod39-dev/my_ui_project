/*
COMPREHENSIVE CODE CHANGES FOR ALL FEATURES
This document outlines all Dart/Flutter code changes needed
*/

// =============================================================
// CHANGE 1: CART PAGE - Ensure Zero Shipping Cost Always
// File: lib/pages/cart_page.dart
// =============================================================

// MODIFICATION 1: Update _calculateActualShipping to return 0
// Find this method and replace it:

double _calculateActualShipping(double subtotal) {
  // CHANGE: Shipping is now always FREE (zero)
  // This ensures shipping remains 0 from cart to checkout
  return 0;
}

// The checkout code already calls _calculateActualShipping, 
// so totalShipping will now be 0, making all orders have 0 shipping.


// =============================================================
// CHANGE 2: MY PRODUCTS PAGE - Make Items Clickable
// File: lib/pages/my_products_page.dart
// =============================================================

// ADD THIS: Navigation handler method in _MyProductsPageState class

Future<void> _viewProductDetails(Product product) async {
  if (!mounted) return;
  final updated = await Navigator.pushNamed(
    context,
    '/details',
    arguments: product,
  );
  
  if (updated == true) {
    // Reload products if user edited the product
    await _loadMyProducts();
  }
}

// MODIFY: The product list item to be tappable
// Find where products are displayed in the ListView and wrap with GestureDetector:

GestureDetector(
  onTap: () => _viewProductDetails(product),
  child: Card(
    // ... existing card content ...
    child: Column(
      children: [
        // Product image and details
        Text(product.title),
        Text('${product.price} ${product.currency}'),
        Text('Stock: ${product.stockQty}'),
        // ... rest of card content ...
      ],
    ),
  ),
)


// =============================================================
// CHANGE 3: HANDLE OUT-OF-STOCK WITH 'SOLD' LABEL
// File: lib/pages/details_page.dart and index_page.dart
// =============================================================

// ADD THIS: Helper method to get visibility status
String _getProductVisibility(Product product) {
  if (product.stockQty <= 0) {
    return 'SOLD';
  }
  return 'IN STOCK';
}

// ADD THIS: Visual indicator widget
Widget _buildStockBadge(Product product) {
  final isSold = product.stockQty <= 0;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: isSold ? Colors.grey[600] : Color(0xFF34C759),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      isSold ? 'SOLD OUT' : 'IN STOCK',
      style: GoogleFonts.poppins(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    ),
  );
}

// IN details_page.dart: Replace the "Add to Cart" button logic:
if (product.stockQty <= 0) {
  // Show SOLD label instead of Add to Cart button
  return Center(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[600],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'SOLD OUT',
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    ),
  );
} else {
  // Show Add to Cart button
  return ElevatedButton(/* existing button code */);
}

// IN index_page.dart: Modify product filtering to keep sold items visible
// Find _loadProducts method and modify the query:

Future<void> _loadProducts() async {
  setState(() {
    _isLoading = true;
  });
  try {
    var query = supabase
        .from('products')
        .select()
        .eq('status', 'active')
        .eq('validated', true)
        // CHANGE: Remove gt('stock_qty', 0) to keep sold items visible
        // Old: .gt('stock_qty', 0)
        // Now showing all products including sold ones
        .neq('visibility', 'hidden'); // Only hide truly hidden products

    if (_selectedCategoryId != null) {
      query = query.eq('category_id', _selectedCategoryId!);
    }

    final response = await query.order('created_at', ascending: false);
    
    var loadedProducts = (response as List)
        .map((item) => Product.fromMap(item as Map<String, dynamic>))
        .toList();

    if (_selectedSubcategory != null) {
      loadedProducts = loadedProducts.where((p) {
        final subcat = p.listingDetails['subcategory']?.toString();
        return subcat != null && subcat == _selectedSubcategory;
      }).toList();
    }

    if (!mounted) return;
    setState(() {
      _products = loadedProducts;
    });
  } catch (e) {
    if (!mounted) return;
    setState(() {
      _errorMessage = 'Failed to load products';
    });
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}


// =============================================================
// CHANGE 4: REMOVE SUBCATEGORIES (men, women, kids)
// File: lib/pages/index_page.dart
// =============================================================

// MODIFY: _loadCategories method to not show subcategories
Future<void> _loadCategories() async {
  try {
    final response = await supabase
        .from('categories')
        .select()
        .order('name', ascending: true);

    final loadedCategories = (response as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    if (!mounted) return;
    setState(() {
      _categories = loadedCategories;
      // CHANGE: Don't load subcategories
      // Remove any subcategory selection logic
      _selectedSubcategory = null;
    });
  } catch (_) {
    if (!mounted) return;
    setState(() {
      _categories = [];
    });
  }
}

// MODIFY: Remove subcategory filter UI from the category section
// Find the category filter UI and remove subcategory chips:

// OLD CODE (remove this):
// if (_selectedSubcategory != null) {
//   Text('Subcategory: $_selectedSubcategory')
// }

// Keep only main category selection, no subcategories


// =============================================================
// CHANGE 5: ADMIN NOTIFICATIONS FOR NEW PRODUCT LISTINGS
// File: lib/pages/notifications_page.dart
// =============================================================

// ADD THIS: Method to handle product approval
Future<void> _handleProductApproval(NotificationModel notification, bool approved) async {
  final productId = notification.data['product_id'];
  if (productId == null) return;

  try {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Check if user is admin
    final profile = await supabase
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();

    if (profile?['role'] != 'admin') {
      throw Exception('Only admins can approve products');
    }

    // Update product approval status
    await supabase
        .from('products')
        .update({
          'admin_approved': approved,
          'admin_approved_at': DateTime.now().toIso8601String(),
          'validated': approved,
          'status': approved ? 'active' : 'hidden',
        })
        .eq('id', productId);

    // Mark notification as read
    await supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notification.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(approved ? 'Product approved' : 'Product revoked'),
      ),
    );

    await _loadNotifications();
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}

// ADD THIS: UI widget to show product approval actions
Widget _buildProductApprovalNotification(NotificationModel notification) {
  final isDark = AppThemeColors.isDark(context);
  
  return Container(
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    decoration: BoxDecoration(
      color: isDark ? Color(0xFF2C2C2C) : Colors.grey[200],
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isDark ? Colors.white24 : Colors.grey,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          notification.title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          notification.body,
          style: GoogleFonts.inter(fontSize: 12),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _handleProductApproval(notification, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF34C759),
                ),
                child: Text(
                  'Approve',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _handleProductApproval(notification, false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[600],
                ),
                child: Text(
                  'Revoke',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// MODIFY: _buildNotificationTile to handle product notifications
Widget _buildNotificationTile(NotificationModel notification) {
  // Check if this is a product approval notification
  if (notification.type == 'product_approval') {
    return _buildProductApprovalNotification(notification);
  }

  // ... existing notification tile code ...
}


// =============================================================
// CHANGE 6: TRIGGER ADMIN NOTIFICATIONS ON NEW PRODUCT LISTING
// File: lib/pages/add_edit_product_page.dart
// =============================================================

// ADD THIS: Send notification to admins when product is created
Future<void> _notifyAdminsOfNewListing(int productId) async {
  try {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Get product details
    final product = await supabase
        .from('products')
        .select()
        .eq('id', productId)
        .maybeSingle();

    if (product == null) return;

    // Get all admins
    final admins = await supabase
        .from('profiles')
        .select('id')
        .eq('role', 'admin');

    // Send notification to each admin
    for (final admin in admins) {
      await supabase
          .from('notifications')
          .insert({
            'user_id': admin['id'],
            'sender_id': user.id,
            'title': 'New Product Listing for Review',
            'body': '${product['title']} by ${user.email} is pending approval.',
            'type': 'product_approval',
            'product_id': productId,
            'data': {
              'product_id': productId,
              'action_type': 'approve'
            },
          });
    }
  } catch (e) {
    print('Error notifying admins: $e');
  }
}

// In the product creation/save method, add:
// After successfully creating the product:
if (createdProduct != null) {
  await _notifyAdminsOfNewListing(createdProduct['id']);
}


// =============================================================
// CHANGE 7: ORDER CANCELLATION - Hide Actions on Cancelled Orders
// File: lib/pages/orders_page.dart
// =============================================================

// MODIFY: Order status checking to hide actions when cancelled
bool _isCancelled(OrderModel order) {
  return order.cancelledByRole != null && order.cancelledByRole!.isNotEmpty;
}

// ADD THIS: Method to handle order cancellation
Future<void> _cancelOrder(int orderId) async {
  try {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancel Order?'),
        content: Text('Are you sure you want to cancel this order? This action is final.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep Order'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Cancel Order', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await supabase
        .from('orders')
        .update({
          'cancelled_by_role': 'buyer',
          'status': 'cancelled',
        })
        .eq('id', orderId)
        .eq('buyer_id', user.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Order cancelled. No further actions possible.')),
    );

    await _loadOrders();
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}

// MODIFY: Order card to hide action buttons when cancelled
Widget _buildOrderCard(OrderModel order) {
  final isCancelled = _isCancelled(order);

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: isCancelled ? Colors.grey[300] : Colors.white,
      borderRadius: BorderRadius.circular(12),
      opacity: isCancelled ? 0.6 : 1.0,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Order #${order.id}'),
        Text('Status: ${order.status}'),
        if (isCancelled)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red[300],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'CANCELLED - No further actions possible',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.red[900],
                  fontSize: 12,
                ),
              ),
            ),
          )
        else
          // Show action buttons only if NOT cancelled
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: () => _viewOrderDetails(order),
                  child: Text('View'),
                ),
                SizedBox(width: 8),
                if (order.status != 'cancelled')
                  ElevatedButton(
                    onPressed: () => _cancelOrder(order.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: Text('Cancel'),
                  ),
              ],
            ),
          ),
      ],
    ),
  );
}


// =============================================================
// CHANGE 8: SELLER ORDERS - Hide Actions on Cancelled Orders
// File: lib/pages/seller_orders_page.dart
// =============================================================

// ADD THIS: Method to check if order is cancelled
bool _isCancelled(String status, String? cancelledByRole) {
  return cancelledByRole != null && cancelledByRole.isNotEmpty || status == 'cancelled';
}

// MODIFY: Order action buttons
Widget _buildOrderActions(SellerOrderModel order) {
  final isCancelled = _isCancelled(order.orderStatus, null);

  if (isCancelled) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[400],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Order Cancelled - No Actions Available',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          color: Colors.grey[800],
        ),
      ),
    );
  }

  return Row(
    children: [
      ElevatedButton(
        onPressed: () => _confirmShipment(order.orderId),
        child: Text('Confirm Shipment'),
      ),
      SizedBox(width: 8),
      ElevatedButton(
        onPressed: () => _confirmDelivery(order.orderId),
        child: Text('Confirm Delivery'),
      ),
      SizedBox(width: 8),
      ElevatedButton(
        onPressed: () => _cancelOrder(order.orderId),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        child: Text('Cancel'),
      ),
    ],
  );
}


// =============================================================
// CHANGE 9: DELIVERY CONFIRMATION - Trigger Stock Deduction
// File: lib/pages/seller_orders_page.dart
// =============================================================

// ADD THIS: Method to confirm delivery and trigger stock deduction
Future<void> _confirmDelivery(int orderId) async {
  try {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm Delivery?'),
        content: Text('Confirming delivery will deduct stock and finalize this order.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Confirm Delivery'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Update order status to delivered and set delivery_confirmed_at
    // This will trigger the database function to deduct stock
    await supabase
        .from('orders')
        .update({
          'status': 'delivered',
          'delivery_confirmed_at': DateTime.now().toIso8601String(),
          'delivered_by_role': 'seller',
        })
        .eq('id', orderId);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Delivery confirmed! Stock has been deducted.')),
    );

    await _loadOrders();
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}


// =============================================================
// ADDITIONAL: Index page model update for visibility field
// File: lib/pages/index_page.dart - Product class
// =============================================================

// Update the Product class to include visibility field:
// (This may already exist, but ensure it's mapped from the database)

class Product {
  final int id;
  final int? categoryId;
  final String? sellerId;
  final String title;
  final double price;
  final String? image;
  final String tag;
  final String description;
  final String status;
  final String currency;
  final int stockQty;
  final String? slug;
  final bool validated;
  final Map<String, dynamic> listingDetails;
  final String visibility; // ADD THIS FIELD
  final DateTime? outOfStockSince; // ADD THIS FIELD

  const Product({
    required this.id,
    required this.categoryId,
    required this.sellerId,
    required this.title,
    required this.price,
    required this.image,
    required this.tag,
    required this.description,
    required this.status,
    required this.currency,
    required this.stockQty,
    required this.slug,
    required this.validated,
    required this.listingDetails,
    this.visibility = 'visible', // ADD THIS
    this.outOfStockSince, // ADD THIS
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    // ... existing code ...
    return Product(
      // ... existing fields ...
      visibility: (map['visibility'] ?? 'visible').toString(), // ADD THIS
      outOfStockSince: map['out_of_stock_since'] != null 
        ? DateTime.tryParse(map['out_of_stock_since'].toString())
        : null, // ADD THIS
    );
  }

  bool get isBuyable => status.toLowerCase() == 'active' && stockQty > 0 && visibility != 'hidden';
  bool get isSold => visibility == 'sold' || stockQty <= 0;
}
