import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_ui_project/services/app_scaffold_messenger.dart';
import 'package:my_ui_project/theme/app_theme_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminOrderItemModel {
  AdminOrderItemModel({
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
    this.productImage,
    this.buyerConfirmed = false,
    this.sellerConfirmed = false,
    this.buyerProofUrl,
    this.sellerProofUrl,
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
  final bool buyerConfirmed;
  final bool sellerConfirmed;
  final String? buyerProofUrl;
  final String? sellerProofUrl;

  factory AdminOrderItemModel.fromMap(Map<String, dynamic> map) {
    final rawPrice = map['price'];
    final order = map['orders'] as Map<String, dynamic>?;
    final product = map['products'] as Map<String, dynamic>?;
    
    final confirmations = (order?['escrow_confirmations'] as List?) ?? [];
    bool bConf = false;
    bool sConf = false;
    String? bProof;
    String? sProof;

    for (final c in confirmations) {
      if (c['role'] == 'buyer') {
        bConf = c['confirmed'] == true;
        bProof = c['proof_image_url'];
      } else if (c['role'] == 'seller') {
        sConf = c['confirmed'] == true;
        sProof = c['proof_image_url'];
      }
    }

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
      buyerConfirmed: bConf,
      sellerConfirmed: sConf,
      buyerProofUrl: bProof,
      sellerProofUrl: sProof,
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
          callback: (_) { if (mounted) _loadOrders(); },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'order_items',
          callback: (_) { if (mounted) _loadOrders(); },
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
      if (user == null) { _redirectUnauthorized('/login'); return; }

      final profile = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      if ((profile?['role'] ?? '').toString() != 'admin') {
        _redirectUnauthorized('/home');
        return;
      }

      final args = (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?) ?? {};
      final orderIdFilter = args['order_id'];
      final userIdFilter = args['user_id'];

      var query = supabase
          .from('order_items')
          .select(
            'id, order_id, seller_id, price, quantity, '
            'orders!inner(buyer_id, status, customer_name, shipping_address, city, state, zipcode, payment_method, cancelled_by_role, admin_cancel_reason, created_at, '
            'escrow_confirmations(role, confirmed, proof_image_url)), '
            'products(title, main_image_url)',
          );
      
      if (orderIdFilter != null) {
        query = query.eq('order_id', orderIdFilter);
      }
      
      if (userIdFilter != null) {
        // PostgREST fails to parse logic trees with nested OR filters across tables.
        // We solve this by finding the order IDs for the buyer first.
        final buyerOrdersResponse = await supabase
            .from('orders')
            .select('id')
            .eq('buyer_id', userIdFilter);
        
        final buyerOrderIds = (buyerOrdersResponse as List)
            .map((o) => o['id'])
            .toList();

        if (buyerOrderIds.isEmpty) {
          query = query.eq('seller_id', userIdFilter);
        } else {
          // Filter items where user is seller OR order belongs to buyer
          query = query.or('seller_id.eq.$userIdFilter, order_id.in.(${buyerOrderIds.join(",")})');
        }
      }

      final response = await query.order('id', ascending: false);

      final loadedOrders = (response as List)
          .map((item) => AdminOrderItemModel.fromMap(
              Map<String, dynamic>.from(item as Map)))
          .toList();

      final buyerIds = loadedOrders
          .map((o) => o.buyerId)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList()
          .cast<String>();
      final sellerIds = loadedOrders
          .map((o) => o.sellerId)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList()
          .cast<String>();

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
        _errorMessage = 'Failed to load orders\n$e';
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
      for (final p in profiles)
        p['id'].toString(): ((p['full_name'] ?? '').toString().trim().isNotEmpty
            ? p['full_name'].toString()
            : (p['email'] ?? 'Unknown user').toString()),
    };
  }

  void _redirectUnauthorized(String routeName) {
    if (!mounted) return;
    
    appScaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text('Only admins can view all marketplace orders.')),
    );
    
    Future.microtask(() {
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, routeName, (_) => false);
      }
    });
  }

  String _formatPrice(double price) => 'EGP ${price.toStringAsFixed(0)}';

  bool _canAdminCancel(AdminOrderItemModel order) =>
      order.orderStatus != 'cancelled' &&
      order.orderStatus != 'delivered' &&
      order.orderStatus != 'completed';

  bool _canAdminComplete(AdminOrderItemModel order) =>
      order.orderStatus == 'delivered';

  Future<void> _cancelOrderAsAdmin(AdminOrderItemModel order) async {
    final reasonController = TextEditingController();
    try {
      final reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          final textColor = AppThemeColors.textPrimary(dialogContext);
          return AlertDialog(
            backgroundColor: AppThemeColors.elevatedSurface(dialogContext),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Cancel Order #${order.orderId}',
              style: GoogleFonts.poppins(
                  color: textColor, fontWeight: FontWeight.bold),
            ),
            content: TextField(
              controller: reasonController,
              maxLines: 4,
              style: GoogleFonts.inter(color: textColor),
              decoration: InputDecoration(
                labelText: 'Reason',
                hintText: 'Why is this order being cancelled?',
                hintStyle: GoogleFonts.inter(
                    color: AppThemeColors.textSecondary(dialogContext)),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('Close',
                    style: TextStyle(
                        color: AppThemeColors.textSecondary(dialogContext))),
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Confirm Cancel'),
              ),
            ],
          );
        },
      );

      if (reason == null || reason.trim().isEmpty) return;

      await supabase.from('orders').update({
        'status': 'cancelled',
        'cancelled_by_role': 'admin',
        'admin_cancel_reason': reason.trim(),
      }).eq('id', order.orderId);

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

  Future<void> _completeOrder(AdminOrderItemModel order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final textColor = AppThemeColors.textPrimary(dialogContext);
        return AlertDialog(
          backgroundColor: AppThemeColors.elevatedSurface(dialogContext),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Complete Order #${order.orderId}?',
            style: GoogleFonts.poppins(
                color: textColor, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Mark this order as completed? This releases the payout to the seller and cannot be undone.',
            style: GoogleFonts.inter(
                color: AppThemeColors.textSecondary(dialogContext),
                height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('Cancel',
                  style: TextStyle(
                      color: AppThemeColors.textSecondary(dialogContext))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Mark Completed'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await supabase
          .from('orders')
          .update({'status': 'completed'})
          .eq('id', order.orderId);

      await _loadOrders();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order marked as completed — payout released')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to complete order: $e')),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'delivered': return Colors.green;
      case 'completed': return Colors.teal;
      case 'cancelled': return Colors.red;
      case 'shipped':   return Colors.blue;
      case 'confirmed': return Colors.orange;
      default:          return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'delivered': return Icons.local_shipping_outlined;
      case 'completed': return Icons.verified_outlined;
      case 'cancelled': return Icons.cancel_outlined;
      case 'shipped':   return Icons.local_post_office_outlined;
      case 'confirmed': return Icons.thumb_up_outlined;
      default:          return Icons.hourglass_empty_rounded;
    }
  }

  Widget _buildEscrowStatus(AdminOrderItemModel order) {
    final secondaryText = AppThemeColors.textSecondary(context);
    final textColor = AppThemeColors.textPrimary(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppThemeColors.elevatedSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (order.buyerConfirmed && order.sellerConfirmed)
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security_rounded, size: 16, color: primaryRed),
              const SizedBox(width: 8),
              Text(
                'Escrow Confirmation',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _escrowActorRow('Buyer', order.buyerConfirmed, order.buyerProofUrl),
          const SizedBox(height: 8),
          _escrowActorRow('Seller', order.sellerConfirmed, order.sellerProofUrl),
        ],
      ),
    );
  }

  Widget _escrowActorRow(String label, bool confirmed, String? proofUrl) {
    final textColor = AppThemeColors.textPrimary(context);
    final secondaryText = AppThemeColors.textSecondary(context);

    return Row(
      children: [
        Text(
          '$label:',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: secondaryText,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: confirmed
                ? Colors.green.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            confirmed ? 'CONFIRMED' : 'PENDING',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: confirmed ? Colors.green : Colors.grey,
            ),
          ),
        ),
        if (proofUrl != null && proofUrl.isNotEmpty) ...[
          const Spacer(),
          TextButton.icon(
            onPressed: () => _viewProofImage(proofUrl),
            icon: const Icon(Icons.image_outlined, size: 14),
            label: const Text('View Proof', style: TextStyle(fontSize: 11)),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: primaryRed,
            ),
          ),
        ],
      ],
    );
  }

  void _viewProofImage(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text('Proof of Escrow', style: TextStyle(color: Colors.white)),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: InteractiveViewer(
                child: Image.network(
                  url,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(child: CircularProgressIndicator(color: primaryRed));
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
          icon:
              Icon(Icons.arrow_back_ios_rounded, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Orders',
          style: GoogleFonts.poppins(
              color: textColor, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_orders.length}',
                    style: GoogleFonts.poppins(
                        color: primaryRed,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: primaryRed,
        onRefresh: _loadOrders,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: primaryRed));
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 48,
                  color: AppThemeColors.textSecondary(context)),
              const SizedBox(height: 12),
              Text(_errorMessage!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      color: AppThemeColors.textSecondary(context),
                      height: 1.5)),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: _loadOrders,
                style: ElevatedButton.styleFrom(
                    backgroundColor: primaryRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryRed.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.receipt_long_outlined,
                  size: 48, color: primaryRed.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 16),
            Text(
              'No orders yet',
              style: GoogleFonts.poppins(
                  color: AppThemeColors.textSecondary(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      itemCount: _orders.length,
      itemBuilder: (context, index) => _buildOrderCard(_orders[index]),
    );
  }

  Widget _buildOrderCard(AdminOrderItemModel order) {
    final textColor = AppThemeColors.textPrimary(context);
    final secondaryText = AppThemeColors.textSecondary(context);
    final buyerName =
        _buyerNames[order.buyerId] ?? 'Buyer';
    final sellerName =
        _sellerNames[order.sellerId] ?? 'Seller';
    final statusColor = _statusColor(order.orderStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppThemeColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              children: [
                // Product image
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 60,
                    height: 60,
                    color: AppThemeColors.elevatedSurface(context),
                    child: order.productImage != null &&
                            order.productImage!.isNotEmpty
                        ? Image.network(order.productImage!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _imgPlaceholder())
                        : _imgPlaceholder(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.productTitle,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Order #${order.orderId}',
                        style: GoogleFonts.inter(
                            color: secondaryText, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(order.orderStatus),
                          color: statusColor, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        order.orderStatus.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Price row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Row(
              children: [
                Text(
                  _formatPrice(order.price),
                  style: GoogleFonts.poppins(
                    color: primaryRed,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '× ${order.quantity}',
                  style: GoogleFonts.inter(
                      color: secondaryText, fontSize: 13),
                ),
                const Spacer(),
                Icon(Icons.payment_rounded,
                    size: 14, color: secondaryText),
                const SizedBox(width: 4),
                Text(
                  order.paymentMethod,
                  style: GoogleFonts.inter(
                      color: secondaryText, fontSize: 12),
                ),
              ],
            ),
          ),

          // ── Divider ──
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            child: Divider(
                height: 1,
                color: AppThemeColors.elevatedSurface(context)),
          ),

          // ── Details ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            child: Column(
              children: [
                _infoRow(Icons.person_outline_rounded, 'Buyer', buyerName,
                    textColor, secondaryText),
                const SizedBox(height: 6),
                _infoRow(Icons.storefront_outlined, 'Seller', sellerName,
                    textColor, secondaryText),
                if (order.customerName.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _infoRow(Icons.badge_outlined, 'Customer',
                      order.customerName, textColor, secondaryText),
                ],
                if (order.shippingAddress.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _infoRow(Icons.location_on_outlined, 'Address',
                      _fullAddress(order), textColor, secondaryText),
                ],
                if (order.orderStatus == 'cancelled' &&
                    order.cancelledByRole == 'admin' &&
                    order.adminCancelReason.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _infoRow(Icons.info_outline_rounded, 'Admin Note',
                      order.adminCancelReason, textColor, secondaryText),
                ],
                const SizedBox(height: 6),
                _infoRow(
                    Icons.access_time_rounded,
                    'Date',
                    order.createdAt
                        .toLocal()
                        .toString()
                        .split('.')
                        .first,
                    textColor,
                    secondaryText,
                    muted: true),
              ],
            ),
          ),

          // ── Escrow Status ──
          if (order.orderStatus == 'delivered' || (order.buyerConfirmed || order.sellerConfirmed))
            _buildEscrowStatus(order),

          // ── Action buttons ──
          if (_canAdminComplete(order) || _canAdminCancel(order))
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (_canAdminComplete(order))
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _completeOrder(order),
                        icon: const Icon(Icons.verified_outlined, size: 16),
                        label: const Text('Mark as Completed'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  if (_canAdminCancel(order))
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _cancelOrderAsAdmin(order),
                        icon: const Icon(Icons.cancel_outlined, size: 16),
                        label: const Text('Cancel Order'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryRed,
                          side: const BorderSide(color: primaryRed),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                ],
              ),
            )
          else
            const SizedBox(height: 14),
        ],
      ),
    );
  }

  String _fullAddress(AdminOrderItemModel order) {
    return [
      order.shippingAddress,
      if (order.city.trim().isNotEmpty) order.city,
      if (order.state.trim().isNotEmpty) order.state,
      if (order.zipcode.trim().isNotEmpty) order.zipcode,
    ].join(', ');
  }

  Widget _imgPlaceholder() => Center(
        child: Icon(Icons.inventory_2_outlined,
            color: primaryRed.withValues(alpha: 0.4), size: 26),
      );

  Widget _infoRow(IconData icon, String label, String value, Color textColor,
      Color secondaryText,
      {bool muted = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon,
            size: 15,
            color: muted ? AppThemeColors.textMuted(context) : secondaryText),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: muted
                  ? AppThemeColors.textMuted(context)
                  : secondaryText,
              fontSize: 12,
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
                  : textColor,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}