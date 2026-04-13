import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_ui_project/theme/app_theme_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderModel {
  final int id;
  final double totalPrice;
  final String status;
  final String? customerName;
  final String? shippingAddress;
  final String? city;
  final String? state;
  final String? zipcode;
  final String? paymentMethod;
  final String? cardHolderName;
  final String? cardLast4;
  final String? cardExpiry;
  final DateTime createdAt;

  const OrderModel({
    required this.id,
    required this.totalPrice,
    required this.status,
    required this.customerName,
    required this.shippingAddress,
    required this.city,
    required this.state,
    required this.zipcode,
    required this.paymentMethod,
    required this.cardHolderName,
    required this.cardLast4,
    required this.cardExpiry,
    required this.createdAt,
  });

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    final rawPrice = map['total_price'];
    return OrderModel(
      id: map['id'] as int,
      totalPrice: rawPrice is num
          ? rawPrice.toDouble()
          : double.tryParse('${rawPrice ?? 0}') ?? 0,
      status: (map['status'] ?? 'pending').toString(),
      customerName: map['customer_name']?.toString(),
      shippingAddress: map['shipping_address']?.toString(),
      city: map['city']?.toString(),
      state: map['state']?.toString(),
      zipcode: map['zipcode']?.toString(),
      paymentMethod: map['payment_method']?.toString(),
      cardHolderName: map['card_holder_name']?.toString(),
      cardLast4: map['card_last4']?.toString(),
      cardExpiry: map['card_expiry']?.toString(),
      createdAt: DateTime.tryParse('${map['created_at']}') ?? DateTime.now(),
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
    if (channel != null) {
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
            'id, total_price, status, customer_name, shipping_address, city, state, zipcode, payment_method, card_holder_name, card_last4, card_expiry, created_at',
          )
          .eq('buyer_id', user.id)
          .order('created_at', ascending: false);

      final loadedOrders = (response as List)
          .map((item) => OrderModel.fromMap(item as Map<String, dynamic>))
          .toList();

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
              Text(
                _formatPrice(order.totalPrice),
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
              const SizedBox(height: 8),
              Text(
                'Payment: ${order.paymentMethod?.isNotEmpty == true ? order.paymentMethod : 'Not set'}',
                style: GoogleFonts.inter(color: textColor),
              ),
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
                'Address: ${order.shippingAddress?.isNotEmpty == true ? order.shippingAddress : 'Not set'}',
                style: GoogleFonts.inter(
                  color: AppThemeColors.textSecondary(context),
                ),
              ),
              if (order.city?.isNotEmpty == true ||
                  order.state?.isNotEmpty == true ||
                  order.zipcode?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(
                  'City/State/Zip: ${[
                    if (order.city?.isNotEmpty == true) order.city,
                    if (order.state?.isNotEmpty == true) order.state,
                    if (order.zipcode?.isNotEmpty == true) order.zipcode,
                  ].join(', ')}',
                  style: GoogleFonts.inter(
                    color: AppThemeColors.textSecondary(context),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                'Created: ${order.createdAt.toLocal().toString().split('.').first}',
                style: GoogleFonts.inter(
                  color: AppThemeColors.textMuted(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
