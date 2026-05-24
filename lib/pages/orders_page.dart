import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_ui_project/theme/app_theme_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderModel {
  final int id;
  final double totalPrice;
  final String status;
  final List<String> productTitles;
  final String? customerName;
  final String? customerEmail;
  final String? phoneNumber;
  final String? company;
  final String? shippingAddress;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? zipcode;
  final String? paymentMethod;
  final String currency;
  final double subtotalPrice;
  final double shippingPrice;
  final String? cancelledByRole;
  final String? adminCancelReason;
  final String? cardHolderName;
  final String? cardLast4;
  final String? cardExpiry;
  final DateTime createdAt;
  final String? sellerId;
  final bool hasReview;
  final bool buyerConfirmed;
  final bool sellerConfirmed;
  final String? buyerProofUrl;
  final String? sellerProofUrl;

  const OrderModel({
    required this.id,
    required this.totalPrice,
    required this.status,
    required this.productTitles,
    required this.customerName,
    required this.customerEmail,
    required this.phoneNumber,
    required this.company,
    required this.shippingAddress,
    required this.addressLine2,
    required this.city,
    required this.state,
    required this.zipcode,
    required this.paymentMethod,
    required this.currency,
    required this.subtotalPrice,
    required this.shippingPrice,
    required this.cancelledByRole,
    required this.adminCancelReason,
    required this.cardHolderName,
    required this.cardLast4,
    required this.cardExpiry,
    required this.createdAt,
    required this.sellerId,
    required this.hasReview,
    this.buyerConfirmed = false,
    this.sellerConfirmed = false,
    this.buyerProofUrl,
    this.sellerProofUrl,
  });

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    final rawPrice = map['total_price'];
    final rawSubtotal = map['subtotal_price'];
    final rawShipping = map['shipping_price'];
    final productTitles =
        (map['product_titles'] as List?)
            ?.map((title) => title.toString().trim())
            .where((title) => title.isNotEmpty)
            .toList() ??
        const <String>[];
    final confirmations = (map['escrow_confirmations'] as List?) ?? [];
    var buyerConfirmed = false;
    var sellerConfirmed = false;
    String? buyerProofUrl;
    String? sellerProofUrl;

    for (final rawConfirmation in confirmations) {
      final confirmation = rawConfirmation as Map;
      if (confirmation['role'] == 'buyer') {
        buyerConfirmed = confirmation['confirmed'] == true;
        buyerProofUrl = confirmation['proof_image_url']?.toString();
      } else if (confirmation['role'] == 'seller') {
        sellerConfirmed = confirmation['confirmed'] == true;
        sellerProofUrl = confirmation['proof_image_url']?.toString();
      }
    }

    return OrderModel(
      id: map['id'] as int,
      totalPrice: rawPrice is num
          ? rawPrice.toDouble()
          : double.tryParse('${rawPrice ?? 0}') ?? 0,
      status: (map['status'] ?? 'pending').toString(),
      productTitles: productTitles,
      customerName: map['customer_name']?.toString(),
      customerEmail: map['customer_email']?.toString(),
      phoneNumber: map['phone_number']?.toString(),
      company: map['company']?.toString(),
      shippingAddress: map['shipping_address']?.toString(),
      addressLine2: map['address_line2']?.toString(),
      city: map['city']?.toString(),
      state: map['state']?.toString(),
      zipcode: map['zipcode']?.toString(),
      paymentMethod: map['payment_method']?.toString(),
      currency: (map['currency'] ?? 'EGP').toString(),
      subtotalPrice: rawSubtotal is num
          ? rawSubtotal.toDouble()
          : double.tryParse('${rawSubtotal ?? rawPrice ?? 0}') ?? 0,
      shippingPrice: rawShipping is num
          ? rawShipping.toDouble()
          : double.tryParse('${rawShipping ?? 0}') ?? 0,
      cancelledByRole: map['cancelled_by_role']?.toString(),
      adminCancelReason: map['admin_cancel_reason']?.toString(),
      cardHolderName: map['card_holder_name']?.toString(),
      cardLast4: map['card_last4']?.toString(),
      cardExpiry: map['card_expiry']?.toString(),
      createdAt: DateTime.tryParse('${map['created_at']}') ?? DateTime.now(),
      sellerId: map['seller_id']?.toString(),
      hasReview: map['has_review'] == true,
      buyerConfirmed: buyerConfirmed,
      sellerConfirmed: sellerConfirmed,
      buyerProofUrl: buyerProofUrl,
      sellerProofUrl: sellerProofUrl,
    );
  }
}

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  static const Color primaryRed = Color(0xFFDB4444);

  final supabase = Supabase.instance.client;
  RealtimeChannel? _ordersChannel;
  bool _isLoading = true;
  String? _errorMessage;
  List<OrderModel> _orders = [];

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
        .channel('public:orders:buyer')
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
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'escrow_confirmations',
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
        setState(() {
          _orders = [];
          _isLoading = false;
        });
        return;
      }

      final response = await supabase
          .from('orders')
          .select(
            'id, total_price, subtotal_price, shipping_price, currency, status, customer_name, customer_email, phone_number, company, shipping_address, address_line2, city, state, zipcode, payment_method, cancelled_by_role, admin_cancel_reason, card_holder_name, card_last4, card_expiry, created_at, escrow_confirmations(role, confirmed, proof_image_url)',
          )
          .eq('buyer_id', user.id)
          .order('created_at', ascending: false);

      final orders = (response as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      final orderIds = orders
          .map((item) => item['id'])
          .whereType<int>()
          .toList();

      final productTitlesByOrderId = <int, List<String>>{};
      final sellerByOrderId = <int, String?>{};
      if (orderIds.isNotEmpty) {
        final orderItemsResponse = await supabase
            .from('order_items')
            .select('order_id, product_name, seller_id, products(title)')
            .inFilter('order_id', orderIds)
            .order('order_id', ascending: false);

        for (final rawItem in orderItemsResponse as List) {
          final item = Map<String, dynamic>.from(rawItem as Map);
          final orderId = item['order_id'] as int?;
          if (orderId == null) continue;

          final sellerId = item['seller_id']?.toString();
          sellerByOrderId.putIfAbsent(orderId, () => sellerId);

          final product =
              item['products'] as Map<String, dynamic>? ??
              const <String, dynamic>{};
          final productTitle = (item['product_name'] ?? product['title'] ?? '')
              .toString()
              .trim();
          if (productTitle.isEmpty) continue;

          final titles = productTitlesByOrderId.putIfAbsent(
            orderId,
            () => <String>[],
          );
          if (!titles.contains(productTitle)) {
            titles.add(productTitle);
          }
        }
      }

      final reviewedOrderIds = <int>{};
      if (orderIds.isNotEmpty) {
        final reviewsResponse = await supabase
            .from('reviews')
            .select('order_id')
            .eq('buyer_id', user.id)
            .inFilter('order_id', orderIds);
        for (final item in reviewsResponse as List) {
          final orderId = (item as Map)['order_id'] as int?;
          if (orderId != null) {
            reviewedOrderIds.add(orderId);
          }
        }
      }

      final loadedOrders = orders.map((item) {
        item['product_titles'] =
            productTitlesByOrderId[item['id']] ?? const <String>[];
        item['seller_id'] = sellerByOrderId[item['id']];
        item['has_review'] = reviewedOrderIds.contains(item['id']);
        return OrderModel.fromMap(item);
      }).toList();

      if (!mounted) return;
      setState(() {
        _orders = loadedOrders;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load orders';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatPrice(OrderModel order, double price) =>
      '${order.currency} ${price.toStringAsFixed(0)}';

  String _fullAddress(OrderModel order) {
    final parts = [
      order.shippingAddress?.trim(),
      order.addressLine2?.trim(),
    ].where((part) => part != null && part.isNotEmpty).cast<String>().toList();
    return parts.isEmpty ? 'Not set' : parts.join(', ');
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'delivered':
      case 'completed':
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

  bool _canCancel(OrderModel order) =>
      order.status != 'delivered' &&
      order.status != 'completed' &&
      order.status != 'cancelled';

  Widget _buildBuyerEscrowStatusCard(OrderModel order) {
    final textColor = AppThemeColors.textPrimary(context);
    final bothConfirmed = order.buyerConfirmed && order.sellerConfirmed;
    final isTerminal =
        order.status == 'completed' || order.status == 'cancelled';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppThemeColors.elevatedSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: bothConfirmed
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.security_rounded, size: 16, color: primaryRed),
              const SizedBox(width: 8),
              Text(
                'Escrow Status',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _escrowActorRow('Your confirmation', order.buyerConfirmed),
          const SizedBox(height: 8),
          _escrowActorRow('Seller confirmation', order.sellerConfirmed),
          if (!isTerminal) ...[
            const SizedBox(height: 14),
            Center(
              child: Text(
                bothConfirmed
                    ? 'Both confirmed - awaiting admin release.'
                    : order.buyerConfirmed
                    ? 'You confirmed receipt. Waiting for seller confirmation.'
                    : order.sellerConfirmed
                    ? 'Seller confirmed dispatch. Confirm receipt when ready.'
                    : 'Waiting for escrow confirmations.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: bothConfirmed
                      ? Colors.green
                      : AppThemeColors.textSecondary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ] else if (order.status == 'completed') ...[
            const SizedBox(height: 14),
            Center(
              child: Text(
                'Order completed - payment released to seller.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _escrowActorRow(String label, bool confirmed) {
    return Row(
      children: [
        Text(
          '$label:',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppThemeColors.textSecondary(context),
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
            confirmed ? 'Done' : 'Pending',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: confirmed ? Colors.green : Colors.grey,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _cancelOrder(OrderModel order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel order?'),
          content: Text('Cancel order #${order.id}? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(backgroundColor: primaryRed),
              child: const Text(
                'Cancel Order',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await supabase
          .from('orders')
          .update({
            'status': 'cancelled',
            'cancelled_by_role': 'buyer',
            'admin_cancel_reason': null,
          })
          .eq('id', order.id);
      await _loadOrders();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Order cancelled')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to cancel order: $e')));
    }
  }

  Future<void> _messageSeller(OrderModel order) async {
    final user = supabase.auth.currentUser;
    final sellerId = order.sellerId?.trim();
    if (user == null || sellerId == null || sellerId.isEmpty) return;

    try {
      final sellerProfile = await supabase
          .from('profiles')
          .select('full_name, email')
          .eq('id', sellerId)
          .maybeSingle();
      final sellerName =
          (sellerProfile?['full_name'] ?? sellerProfile?['email'] ?? 'Seller')
              .toString()
              .trim();

      final existingConversation = await supabase
          .from('conversations')
          .select('id')
          .eq('buyer_id', user.id)
          .eq('seller_id', sellerId)
          .maybeSingle();

      int conversationId;
      if (existingConversation != null) {
        conversationId = existingConversation['id'] as int;
      } else {
        final buyerProfile = await supabase
            .from('profiles')
            .select('full_name, email')
            .eq('id', user.id)
            .maybeSingle();
        final buyerName =
            (buyerProfile?['full_name'] ?? buyerProfile?['email'] ?? 'Buyer')
                .toString()
                .trim();

        final inserted = await supabase
            .from('conversations')
            .insert({
              'buyer_id': user.id,
              'seller_id': sellerId,
              'buyer_name': buyerName,
              'seller_name': sellerName,
            })
            .select('id')
            .single();
        conversationId = inserted['id'] as int;
      }

      if (!mounted) return;
      await Navigator.pushNamed(
        context,
        '/chat',
        arguments: {
          'conversationId': conversationId,
          'otherUserId': sellerId,
          'otherUserName': sellerName.isEmpty ? 'Seller' : sellerName,
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to open seller chat: $e')));
    }
  }

  Future<void> _leaveReview(OrderModel order) async {
    final user = supabase.auth.currentUser;
    final sellerId = order.sellerId?.trim();
    if (user == null || sellerId == null || sellerId.isEmpty) return;

    if (order.status != 'completed') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reviews are available after order completion'),
        ),
      );
      return;
    }

    int rating = 5;
    final commentController = TextEditingController();

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: Text('Review Order #${order.id}'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: List.generate(
                        5,
                        (index) => IconButton(
                          onPressed: () {
                            setDialogState(() {
                              rating = index + 1;
                            });
                          },
                          icon: Icon(
                            index < rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                    ),
                    TextField(
                      controller: commentController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Comment',
                        hintText: 'How was your experience?',
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Close'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryRed,
                    ),
                    child: const Text(
                      'Submit',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );

      if (confirmed != true) return;

      await supabase.from('reviews').insert({
        'order_id': order.id,
        'seller_id': sellerId,
        'buyer_id': user.id,
        'rating': rating,
        'comment': commentController.text.trim(),
      });

      await _loadOrders();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted. Thank you!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to submit review: $e')));
    } finally {
      commentController.dispose();
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
          'My Orders',
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: RefreshIndicator(onRefresh: _loadOrders, child: _buildBody()),
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'No orders yet',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: AppThemeColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/home'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryRed,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Start Shopping'),
                  ),
                ],
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
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #${order.id}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: textColor,
                    ),
                  ),
                  Text(
                    order.status.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: _statusColor(order.status),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (order.productTitles.isNotEmpty) ...[
                Text(
                  order.productTitles.join(', '),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Text(
                _formatPrice(order, order.totalPrice),
                style: GoogleFonts.poppins(
                  color: primaryRed,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              if (order.customerName?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(
                  'Name: ${order.customerName}',
                  style: GoogleFonts.inter(color: textColor),
                ),
              ],
              if (order.customerEmail?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(
                  'Email: ${order.customerEmail}',
                  style: GoogleFonts.inter(color: textColor),
                ),
              ],
              if (order.phoneNumber?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(
                  'Phone: ${order.phoneNumber}',
                  style: GoogleFonts.inter(color: textColor),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Payment: ${order.paymentMethod?.isNotEmpty == true ? order.paymentMethod : 'Not set'}',
                style: GoogleFonts.inter(color: textColor),
              ),
              if (order.status == 'cancelled' &&
                  order.cancelledByRole == 'admin' &&
                  order.adminCancelReason?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(
                  'Cancelled by admin: ${order.adminCancelReason}',
                  style: GoogleFonts.inter(color: Colors.redAccent),
                ),
              ],
              if (order.cardHolderName?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(
                  'Card Name: ${order.cardHolderName}',
                  style: GoogleFonts.inter(
                    color: AppThemeColors.textSecondary(context),
                  ),
                ),
              ],
              if (order.cardLast4?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(
                  'Card Last 4: ${order.cardLast4}',
                  style: GoogleFonts.inter(
                    color: AppThemeColors.textSecondary(context),
                  ),
                ),
              ],
              if (order.cardExpiry?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(
                  'Expiry: ${order.cardExpiry}',
                  style: GoogleFonts.inter(
                    color: AppThemeColors.textSecondary(context),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'Address: ${_fullAddress(order)}',
                style: GoogleFonts.inter(
                  color: AppThemeColors.textSecondary(context),
                ),
              ),
              if (order.shippingPrice > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'Shipping: ${_formatPrice(order, order.shippingPrice)}',
                  style: GoogleFonts.inter(
                    color: AppThemeColors.textSecondary(context),
                  ),
                ),
              ],
              if (order.city?.isNotEmpty == true ||
                  order.state?.isNotEmpty == true ||
                  order.zipcode?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(
                  'City/State/Zip: ${[if (order.city?.isNotEmpty == true) order.city, if (order.state?.isNotEmpty == true) order.state, if (order.zipcode?.isNotEmpty == true) order.zipcode].join(', ')}',
                  style: GoogleFonts.inter(
                    color: AppThemeColors.textSecondary(context),
                  ),
                ),
              ],
              if (order.status != 'cancelled')
                _buildBuyerEscrowStatusCard(order),
              const SizedBox(height: 14),
              if (order.status == 'cancelled') ...[
                // Order is cancelled – no further actions are available.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.cancel_outlined,
                        color: Colors.red,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Order cancelled – no further actions available',
                        style: GoogleFonts.inter(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Active order – show relevant action buttons
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        '/escrow',
                        arguments: {'orderId': order.id, 'role': 'buyer'},
                      ),
                      icon: const Icon(
                        Icons.check_circle_outline,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: Text(
                        order.status == 'completed'
                            ? 'View & Review'
                            : order.buyerConfirmed
                            ? 'View Escrow Status'
                            : 'View & Confirm',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    if (order.sellerId != null && order.sellerId!.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => _messageSeller(order),
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text('Message Seller'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    if (_canCancel(order))
                      OutlinedButton.icon(
                        onPressed: () => _cancelOrder(order),
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: const Text('Cancel Order'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryRed,
                          side: const BorderSide(color: primaryRed),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    if (order.status == 'completed' &&
                        !order.hasReview &&
                        order.sellerId != null &&
                        order.sellerId!.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => _leaveReview(order),
                        icon: const Icon(Icons.rate_review_outlined, size: 18),
                        label: const Text('Leave Review'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    if (order.hasReview) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppThemeColors.surface(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppThemeColors.border(context),
                          ),
                        ),
                        child: Text(
                          'Review submitted',
                          style: GoogleFonts.inter(
                            color: AppThemeColors.textSecondary(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
