import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_ui_project/theme/app_theme_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SellerOrderModel {
  const SellerOrderModel({
    required this.id,
    required this.orderId,
    required this.price,
    required this.quantity,
    required this.orderStatus,
    required this.customerName,
    required this.shippingAddress,
    required this.city,
    required this.state,
    required this.zipcode,
    required this.paymentMethod,
    required this.cardHolderName,
    required this.cardLast4,
    required this.cardExpiry,
    required this.productTitle,
    required this.productImage,
  });

  final int id;
  final int orderId;
  final double price;
  final int quantity;
  final String orderStatus;
  final String customerName;
  final String shippingAddress;
  final String city;
  final String state;
  final String zipcode;
  final String paymentMethod;
  final String cardHolderName;
  final String cardLast4;
  final String cardExpiry;
  final String productTitle;
  final String? productImage;

  factory SellerOrderModel.fromMap(Map<String, dynamic> map) {
    final rawPrice = map['price'];
    final order = map['orders'] as Map<String, dynamic>?;
    final product = map['products'] as Map<String, dynamic>?;

    return SellerOrderModel(
      id: map['id'] as int,
      orderId: map['order_id'] as int,
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
      cardHolderName: (order?['card_holder_name'] ?? '').toString(),
      cardLast4: (order?['card_last4'] ?? '').toString(),
      cardExpiry: (order?['card_expiry'] ?? '').toString(),
      productTitle: (product?['title'] ?? 'Product').toString(),
      productImage: product?['main_image_url']?.toString(),
    );
  }
}

class SellerOrdersPage extends StatefulWidget {
  const SellerOrdersPage({super.key});

  @override
  State<SellerOrdersPage> createState() => _SellerOrdersPageState();
}

class _SellerOrdersPageState extends State<SellerOrdersPage> {
  static const Color primaryRed = Color(0xFFDB4444);

  final supabase = Supabase.instance.client;
  RealtimeChannel? _ordersChannel;
  bool _isLoading = true;
  String? _errorMessage;
  List<SellerOrderModel> _orders = [];

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
        .channel('public:orders:seller')
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
          .from('order_items')
          .select(
            'id, order_id, price, quantity, orders(status, customer_name, shipping_address, city, state, zipcode, payment_method, card_holder_name, card_last4, card_expiry), products(title, main_image_url)',
          )
          .eq('seller_id', user.id)
          .order('id', ascending: false);

      final loadedOrders = (response as List)
          .map((item) => SellerOrderModel.fromMap(item as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _orders = loadedOrders;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load seller orders\n$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatPrice(double price) => 'EGP ${price.toStringAsFixed(0)}';

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

  List<String> _nextStatuses(String currentStatus) {
    switch (currentStatus) {
      case 'pending':
        return ['confirmed', 'cancelled'];
      case 'confirmed':
        return ['shipped', 'cancelled'];
      case 'shipped':
        return ['delivered'];
      default:
        return [];
    }
  }

  Future<void> _updateOrderStatus(SellerOrderModel order, String newStatus) async {
    try {
      await supabase
          .from('orders')
          .update({'status': newStatus})
          .eq('id', order.orderId);

      final refreshedOrderItem = await supabase
          .from('order_items')
          .select('orders(status)')
          .eq('id', order.id)
          .maybeSingle();

      final refreshedOrder = refreshedOrderItem?['orders'] as Map<String, dynamic>?;
      final refreshedStatus = (refreshedOrder?['status'] ?? '').toString();

      if (refreshedStatus != newStatus) {
        throw Exception('Order status was not saved.');
      }

      await _loadOrders();
      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order updated to $newStatus')),
      );
    } catch (e) {
      await _loadOrders();
      if (!mounted) return;
      final message = e is PostgrestException && e.message.isNotEmpty
          ? e.message
          : e.toString();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
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
          'Seller Orders',
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'No seller orders yet',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: AppThemeColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/my_products'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryRed,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Manage Products'),
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
        final nextStatuses = _nextStatuses(order.orderStatus);
        final textColor = AppThemeColors.textPrimary(context);
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
                          '${_formatPrice(order.price)} x ${order.quantity}',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFDB4444),
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
                        const SizedBox(height: 4),
                        Text(
                          'Payment: ${order.paymentMethod}',
                          style: GoogleFonts.inter(
                            color: AppThemeColors.textSecondary(context),
                          ),
                        ),
                        if (order.customerName.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Customer: ${order.customerName}',
                            style: GoogleFonts.inter(
                              color: AppThemeColors.textSecondary(context),
                            ),
                          ),
                        ],
                        if (order.shippingAddress.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            order.shippingAddress,
                            style: GoogleFonts.inter(
                              color: AppThemeColors.textSecondary(context),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (order.city.trim().isNotEmpty ||
                            order.state.trim().isNotEmpty ||
                            order.zipcode.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            [
                              if (order.city.trim().isNotEmpty) order.city,
                              if (order.state.trim().isNotEmpty) order.state,
                              if (order.zipcode.trim().isNotEmpty) order.zipcode,
                            ].join(', '),
                            style: GoogleFonts.inter(
                              color: AppThemeColors.textSecondary(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (nextStatuses.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: nextStatuses
                      .map(
                        (status) => ElevatedButton(
                          onPressed: () => _updateOrderStatus(order, status),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: status == 'cancelled'
                                ? Colors.black
                                : primaryRed,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(status.toUpperCase()),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
