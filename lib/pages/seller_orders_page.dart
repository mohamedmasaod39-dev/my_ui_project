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
    required this.customerEmail,
    required this.phoneNumber,
    required this.shippingAddress,
    required this.addressLine2,
    required this.city,
    required this.state,
    required this.zipcode,
    required this.paymentMethod,
    required this.currency,
    required this.lineTotalPrice,
    required this.cardHolderName,
    required this.cardLast4,
    required this.cardExpiry,
    required this.productTitle,
    required this.productImage,
    required this.buyerId,
    this.buyerConfirmed = false,
    this.sellerConfirmed = false,
    this.buyerProofUrl,
    this.sellerProofUrl,
  });

  final int id;
  final int orderId;
  final double price;
  final int quantity;
  final String orderStatus;
  final String customerName;
  final String customerEmail;
  final String phoneNumber;
  final String shippingAddress;
  final String addressLine2;
  final String city;
  final String state;
  final String zipcode;
  final String paymentMethod;
  final String currency;
  final double lineTotalPrice;
  final String cardHolderName;
  final String cardLast4;
  final String cardExpiry;
  final String productTitle;
  final String? productImage;
  final String buyerId;
  final bool buyerConfirmed;
  final bool sellerConfirmed;
  final String? buyerProofUrl;
  final String? sellerProofUrl;

  factory SellerOrderModel.fromMap(Map<String, dynamic> map) {
    final rawPrice = map['price'];
    final rawLineTotal = map['line_total_price'];
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

    return SellerOrderModel(
      id: map['id'] as int,
      orderId: map['order_id'] as int,
      price: rawPrice is num
          ? rawPrice.toDouble()
          : double.tryParse('${rawPrice ?? 0}') ?? 0,
      quantity: map['quantity'] as int? ?? 1,
      orderStatus: (order?['status'] ?? 'pending').toString(),
      customerName: (order?['customer_name'] ?? '').toString(),
      customerEmail: (order?['customer_email'] ?? '').toString(),
      phoneNumber: (order?['phone_number'] ?? '').toString(),
      shippingAddress: (order?['shipping_address'] ?? '').toString(),
      addressLine2: (order?['address_line2'] ?? '').toString(),
      city: (order?['city'] ?? '').toString(),
      state: (order?['state'] ?? '').toString(),
      zipcode: (order?['zipcode'] ?? '').toString(),
      paymentMethod: (order?['payment_method'] ?? 'Card').toString(),
      currency: (map['currency'] ?? order?['currency'] ?? 'EGP').toString(),
      lineTotalPrice: rawLineTotal is num
          ? rawLineTotal.toDouble()
          : double.tryParse('${rawLineTotal ?? 0}') ?? 0,
      cardHolderName: (order?['card_holder_name'] ?? '').toString(),
      cardLast4: (order?['card_last4'] ?? '').toString(),
      cardExpiry: (order?['card_expiry'] ?? '').toString(),
      productTitle: (map['product_name'] ?? product?['title'] ?? 'Product')
          .toString(),
      productImage:
          (map['image_url'] ?? product?['main_image_url'])?.toString(),
      buyerId: (order?['buyer_id'] ?? '').toString(),
      buyerConfirmed: bConf,
      sellerConfirmed: sConf,
      buyerProofUrl: bProof,
      sellerProofUrl: sProof,
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
          .from('order_items')
          .select(
            'id, order_id, price, quantity, product_name, image_url, line_total_price, currency, orders(status, customer_name, customer_email, phone_number, shipping_address, address_line2, city, state, zipcode, payment_method, card_holder_name, card_last4, card_expiry, currency, buyer_id, escrow_confirmations(role, confirmed, proof_image_url)), products(title, main_image_url)',
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

  String _formatPrice(SellerOrderModel order, double price) =>
      '${order.currency} ${price.toStringAsFixed(0)}';

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



  Widget _buildSellerEscrowStatusCard(SellerOrderModel order) {
    final textColor = AppThemeColors.textPrimary(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
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
          _escrowActorRow('Your confirmation', order.sellerConfirmed),
          const SizedBox(height: 8),
          _escrowActorRow('Buyer confirmation', order.buyerConfirmed),
          const SizedBox(height: 16),
          if (order.orderStatus != 'completed' && order.orderStatus != 'cancelled') ...[
            if (!order.sellerConfirmed)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.pushNamed(
                      context,
                      '/escrow',
                      arguments: {'orderId': order.orderId, 'role': 'seller'},
                    );
                    _loadOrders();
                  },
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: const Text('Confirm & Upload Proof'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              )
            else if (order.buyerConfirmed)
              Center(
                child: Text(
                  'Both confirmed — awaiting admin to release payment.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'You confirmed dispatch',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
          ] else if (order.orderStatus == 'completed') ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Payment released to you',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
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
                          '${_formatPrice(order, order.price)} x ${order.quantity}',
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
                        if (order.phoneNumber.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Phone: ${order.phoneNumber}',
                            style: GoogleFonts.inter(
                              color: AppThemeColors.textSecondary(context),
                            ),
                          ),
                        ],
                        if (order.customerEmail.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Email: ${order.customerEmail}',
                            style: GoogleFonts.inter(
                              color: AppThemeColors.textSecondary(context),
                            ),
                          ),
                        ],
                        if (order.shippingAddress.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            [
                              order.shippingAddress,
                              if (order.addressLine2.trim().isNotEmpty)
                                order.addressLine2,
                            ].join(', '),
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
                const SizedBox(height: 14),
                if (order.orderStatus == 'cancelled') ...[  
                  // Cancelled – no further actions.
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
                        const Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Order cancelled – no further actions',
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
                  _buildSellerEscrowStatusCard(order),
                ],
              ],
            ),
        );
      },
    );
  }
}
