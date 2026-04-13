import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SellerOrderModel {
  const SellerOrderModel({
    required this.id,
    required this.orderId,
    required this.price,
    required this.quantity,
    required this.orderStatus,
    required this.shippingAddress,
    required this.paymentMethod,
    required this.productTitle,
    required this.productImage,
  });

  final int id;
  final int orderId;
  final double price;
  final int quantity;
  final String orderStatus;
  final String shippingAddress;
  final String paymentMethod;
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
      shippingAddress: (order?['shipping_address'] ?? '').toString(),
      paymentMethod: (order?['payment_method'] ?? 'N/A').toString(),
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
    if (channel != null) {
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
          .select('id, order_id, price, quantity, orders(status, shipping_address, payment_method), products(title, main_image_url)')
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
        return Colors.black54;
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
      final updatedOrder = await supabase
          .from('orders')
          .update({'status': newStatus})
          .eq('id', order.orderId)
          .select('id, status')
          .maybeSingle();

      if (updatedOrder == null) {
        throw Exception('Order status update was blocked or no row was changed.');
      }

      if (!mounted) return;
      setState(() {
        _orders = _orders.map((item) {
          if (item.id != order.id) return item;
          return SellerOrderModel(
            id: item.id,
            orderId: item.orderId,
            price: item.price,
            quantity: item.quantity,
            orderStatus: (updatedOrder['status'] ?? newStatus).toString(),
            shippingAddress: item.shippingAddress,
            paymentMethod: item.paymentMethod,
            productTitle: item.productTitle,
            productImage: item.productImage,
          );
        }).toList();
      });

      await _loadOrders();
      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order updated to $newStatus')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not update order',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Seller Orders',
          style: GoogleFonts.poppins(
            color: Colors.black,
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
                    style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey),
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
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
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
                      color: Colors.white,
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
                          style: GoogleFonts.inter(color: Colors.black54),
                        ),
                        if (order.shippingAddress.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            order.shippingAddress,
                            style: GoogleFonts.inter(color: Colors.black54),
                            maxLines: 2,
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
