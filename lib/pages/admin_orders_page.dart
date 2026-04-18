import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_ui_project/theme/app_theme_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminOrderItemModel {
  const AdminOrderItemModel({
    required this.id,
    required this.orderId,
    required this.buyerId,
    required this.sellerId,
    required this.price,
    required this.quantity,
    required this.orderStatus,
    required this.customerName,
    required this.shippingAddress,
    required this.city,
    required this.state,
    required this.zipcode,
    required this.paymentMethod,
    required this.cancelledByRole,
    required this.adminCancelReason,
    required this.createdAt,
    required this.productTitle,
    required this.productImage,
  });

  final int id;
  final int orderId;
  final String buyerId;
  final String sellerId;
  final double price;
  final int quantity;
  final String orderStatus;
  final String customerName;
  final String shippingAddress;
  final String city;
  final String state;
  final String zipcode;
  final String paymentMethod;
  final String cancelledByRole;
  final String adminCancelReason;
  final DateTime createdAt;
  final String productTitle;
  final String? productImage;

  factory AdminOrderItemModel.fromMap(Map<String, dynamic> map) {
    final rawPrice = map['price'];
    final order = map['orders'] as Map<String, dynamic>?;
    final product = map['products'] as Map<String, dynamic>?;

    return AdminOrderItemModel(
      id: map['id'] as int,
      orderId: map['order_id'] as int,
      buyerId: (order?['buyer_id'] ?? '').toString(),
      sellerId: (map['seller_id'] ?? '').toString(),
      price: rawPrice is num
          ? rawPrice.toDouble()
          : double.tryParse('${rawPrice ?? 0}') ?? 0,
      quantity: map['quantity'] as int? ?? 1,
      orderStatus: (order?['status'] ?? 'pending').toString(),
      customerName: (order?['customer_name'] ?? '').toString(),
      shippingAddress: (order?['shipping_address'] ?? '').toString(),
      city: (order?['city'] ?? '').toString(),
      state: (order?['state'] ?? '').toString(),
      zipcode: (order?['zipcode'] ?? '').toString(),
      paymentMethod: (order?['payment_method'] ?? 'Card').toString(),
      cancelledByRole: (order?['cancelled_by_role'] ?? '').toString(),
      adminCancelReason: (order?['admin_cancel_reason'] ?? '').toString(),
      createdAt: DateTime.tryParse('${order?['created_at']}') ?? DateTime.now(),
      productTitle: (product?['title'] ?? 'Product').toString(),
      productImage: product?['main_image_url']?.toString(),
    );
  }
}

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  static const Color primaryRed = Color(0xFFDB4444);

  final supabase = Supabase.instance.client;
  RealtimeChannel? _ordersChannel;

  bool _isLoading = true;
  String? _errorMessage;
  List<AdminOrderItemModel> _orders = [];
  Map<String, String> _buyerNames = {};
  Map<String, String> _sellerNames = {};

  @override
  void initState() {
    super.initState();
    _subscribeToOrderChanges();
    _loadOrders();
  }

  @override
  void dispose() {
    final channel = _ordersChannel;
    _ordersChannel = null;
    if (channel != null) {
      channel.unsubscribe();
      supabase.removeChannel(channel);
    }
    super.dispose();
  }

  void _subscribeToOrderChanges() {
    _ordersChannel = supabase
        .channel('public:orders:admin')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (_) {
            if (mounted) {
              _loadOrders();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'order_items',
          callback: (_) {
            if (mounted) {
              _loadOrders();
            }
          },
        )
        .subscribe();
  }

  Future<void> _loadOrders() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final user = supabase.auth.currentUser;
      if (user == null) {
        _redirectUnauthorized('/login');
        return;
      }

      final profile = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      if ((profile?['role'] ?? '').toString() != 'admin') {
        _redirectUnauthorized('/home');
        return;
      }

      final response = await supabase
          .from('order_items')
          .select(
            'id, order_id, seller_id, price, quantity, orders!inner(buyer_id, status, customer_name, shipping_address, city, state, zipcode, payment_method, cancelled_by_role, admin_cancel_reason, created_at), products(title, main_image_url)',
          )
          .order('id', ascending: false);

      final loadedOrders = (response as List)
          .map(
            (item) =>
                AdminOrderItemModel.fromMap(Map<String, dynamic>.from(item as Map)),
          )
          .toList();

      final buyerIds = loadedOrders
          .map((item) => item.buyerId)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      final sellerIds = loadedOrders
          .map((item) => item.sellerId)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      final buyerNames = await _loadProfileNames(buyerIds);
      final sellerNames = await _loadProfileNames(sellerIds);

      if (!mounted) return;
      setState(() {
        _orders = loadedOrders;
        _buyerNames = buyerNames;
        _sellerNames = sellerNames;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load admin orders\n$e';
        _isLoading = false;
      });
    }
  }

  Future<Map<String, String>> _loadProfileNames(List<String> ids) async {
    if (ids.isEmpty) return {};

    final response = await supabase
        .from('profiles')
        .select('id, full_name, email')
        .inFilter('id', ids);

    final profiles = (response as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    return {
      for (final profile in profiles)
        profile['id'].toString(): ((profile['full_name'] ?? '').toString().trim().isNotEmpty
            ? profile['full_name'].toString()
            : (profile['email'] ?? 'Unknown user').toString()),
    };
  }

  void _redirectUnauthorized(String routeName) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Only admins can view all marketplace orders.')),
    );
    Navigator.pushNamedAndRemoveUntil(context, routeName, (_) => false);
  }

  String _displayName(String id, Map<String, String> names, String fallback) {
    return names[id] ?? fallback;
  }

  String _formatPrice(double price) => 'EGP ${price.toStringAsFixed(0)}';

  bool _canAdminCancel(AdminOrderItemModel order) {
    return order.orderStatus != 'cancelled' && order.orderStatus != 'delivered';
  }

  Future<void> _cancelOrderAsAdmin(AdminOrderItemModel order) async {
    final reasonController = TextEditingController();

    try {
      final reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          final textColor = AppThemeColors.textPrimary(dialogContext);
          return AlertDialog(
            backgroundColor: AppThemeColors.elevatedSurface(dialogContext),
            title: Text(
              'Cancel Order #${order.orderId}',
              style: GoogleFonts.poppins(
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: TextField(
              controller: reasonController,
              maxLines: 4,
              style: GoogleFonts.inter(color: textColor),
              decoration: InputDecoration(
                labelText: 'Reason',
                hintText: 'Why is this order being cancelled?',
                hintStyle: GoogleFonts.inter(
                  color: AppThemeColors.textSecondary(dialogContext),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  final reason = reasonController.text.trim();
                  if (reason.isEmpty) return;
                  Navigator.pop(dialogContext, reason);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryRed,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Cancel Order'),
              ),
            ],
          );
        },
      );

      if (reason == null || reason.trim().isEmpty) return;

      await supabase
          .from('orders')
          .update({
            'status': 'cancelled',
            'cancelled_by_role': 'admin',
            'admin_cancel_reason': reason.trim(),
          })
          .eq('id', order.orderId);

      await _loadOrders();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order cancelled by admin')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel order: $e')),
      );
    } finally {
      reasonController.dispose();
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'shipped':
        return Colors.blue;
      case 'confirmed':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppThemeColors.textPrimary(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Admin Orders',
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadOrders,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return ListView(
        children: [
          SizedBox(height: 500, child: Center(child: Text(_errorMessage!))),
        ],
      );
    }

    if (_orders.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: 500,
            child: Center(
              child: Text(
                'No orders yet',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  color: AppThemeColors.textSecondary(context),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _orders.length,
      itemBuilder: (context, index) {
        final order = _orders[index];
        final textColor = AppThemeColors.textPrimary(context);
        final buyerName = _displayName(order.buyerId, _buyerNames, 'Buyer');
        final sellerName = _displayName(order.sellerId, _sellerNames, 'Seller');

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppThemeColors.elevatedSurface(context),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child:
                        order.productImage != null && order.productImage!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              order.productImage!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(Icons.inventory_2_outlined),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.productTitle,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Order #${order.orderId}',
                          style: GoogleFonts.inter(
                            color: AppThemeColors.textSecondary(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_formatPrice(order.price)} x ${order.quantity}',
                          style: GoogleFonts.poppins(
                            color: primaryRed,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Status: ${order.orderStatus.toUpperCase()}',
                          style: GoogleFonts.inter(
                            color: _statusColor(order.orderStatus),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _detailLine('Buyer', buyerName),
              _detailLine('Seller', sellerName),
              _detailLine('Payment', order.paymentMethod),
              if (order.customerName.trim().isNotEmpty)
                _detailLine('Customer Name', order.customerName),
              if (order.shippingAddress.trim().isNotEmpty)
                _detailLine('Address', order.shippingAddress),
              if (order.city.trim().isNotEmpty ||
                  order.state.trim().isNotEmpty ||
                  order.zipcode.trim().isNotEmpty)
                _detailLine(
                  'City/State/Zip',
                  [
                    if (order.city.trim().isNotEmpty) order.city,
                    if (order.state.trim().isNotEmpty) order.state,
                    if (order.zipcode.trim().isNotEmpty) order.zipcode,
                  ].join(', '),
                ),
              if (order.orderStatus == 'cancelled' &&
                  order.cancelledByRole == 'admin' &&
                  order.adminCancelReason.trim().isNotEmpty)
                _detailLine('Admin Reason', order.adminCancelReason),
              _detailLine(
                'Created',
                order.createdAt.toLocal().toString().split('.').first,
                muted: true,
              ),
              if (_canAdminCancel(order)) ...[
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => _cancelOrderAsAdmin(order),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Cancel Order'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _detailLine(String label, String value, {bool muted = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              '$label:',
              style: GoogleFonts.inter(
                color: muted
                    ? AppThemeColors.textMuted(context)
                    : AppThemeColors.textSecondary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: muted
                    ? AppThemeColors.textMuted(context)
                    : AppThemeColors.textPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
