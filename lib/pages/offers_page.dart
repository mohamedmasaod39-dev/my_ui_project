import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OfferModel {
  final int id;
  final int productId;
  final String buyerId;
  final String sellerId;
  final double offerPrice;
  final String status;
  final DateTime createdAt;
  final String productTitle;
  final String? productImage;

  const OfferModel({
    required this.id,
    required this.productId,
    required this.buyerId,
    required this.sellerId,
    required this.offerPrice,
    required this.status,
    required this.createdAt,
    required this.productTitle,
    required this.productImage,
  });

  factory OfferModel.fromMap(Map<String, dynamic> map) {
    final rawPrice = map['offer_price'];
    final product = map['products'] as Map<String, dynamic>?;
    return OfferModel(
      id: map['id'] as int,
      productId: map['product_id'] as int,
      buyerId: (map['buyer_id'] ?? '').toString(),
      sellerId: (map['seller_id'] ?? '').toString(),
      offerPrice: rawPrice is num
          ? rawPrice.toDouble()
          : double.tryParse('${rawPrice ?? 0}') ?? 0,
      status: (map['status'] ?? 'pending').toString(),
      createdAt: DateTime.tryParse('${map['created_at']}') ?? DateTime.now(),
      productTitle: (product?['title'] ?? 'Unknown product').toString(),
      productImage: product?['main_image_url']?.toString(),
    );
  }
}

class OffersPage extends StatefulWidget {
  const OffersPage({super.key});

  @override
  State<OffersPage> createState() => _OffersPageState();
}

class _OffersPageState extends State<OffersPage> {
  static const Color primaryRed = Color(0xFFDB4444);

  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isCheckingOut = false;
  String? _errorMessage;
  List<OfferModel> _offers = [];

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _offers = [];
          _isLoading = false;
        });
        return;
      }

      final response = await supabase
          .from('offers')
          .select('id, product_id, buyer_id, seller_id, offer_price, status, created_at, products(title, main_image_url)')
          .eq('buyer_id', user.id)
          .order('created_at', ascending: false);

      final loaded = (response as List)
          .map((item) => OfferModel.fromMap(item as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _offers = loaded;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load offers';
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

  Future<void> _checkoutAcceptedOffer(OfferModel offer) async {
    if (_isCheckingOut) return;

    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first')),
      );
      return;
    }

    final addressController = TextEditingController();
    String paymentMethod = 'Cash on Delivery';
    bool isSubmitting = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Complete Checkout'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: addressController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Shipping Address',
                        hintText: 'Enter your address',
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: paymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'Payment Method',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Cash on Delivery',
                          child: Text('Cash on Delivery'),
                        ),
                        DropdownMenuItem(
                          value: 'Card',
                          child: Text('Card'),
                        ),
                        DropdownMenuItem(
                          value: 'Wallet',
                          child: Text('Wallet'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          paymentMethod = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () {
                          setDialogState(() {
                            isSubmitting = true;
                          });
                          Navigator.of(dialogContext).pop(true);
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) {
      addressController.dispose();
      return;
    }

    setState(() {
      _isCheckingOut = true;
    });

    try {
      final insertedOrder = await supabase
          .from('orders')
          .insert({
            'buyer_id': user.id,
            'total_price': offer.offerPrice,
            'shipping_address': addressController.text.trim().isEmpty
                ? null
                : addressController.text.trim(),
            'payment_method': paymentMethod,
          })
          .select('id')
          .single();

      final orderId = insertedOrder['id'] as int;

      await supabase.from('order_items').insert({
        'order_id': orderId,
        'product_id': offer.productId,
        'seller_id': offer.sellerId,
        'price': offer.offerPrice,
        'quantity': 1,
      });

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/checkout_success',
        (route) => route.settings.name == '/home',
        arguments: orderId,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Checkout failed: $e')),
      );
    } finally {
      addressController.dispose();
      if (mounted) {
        setState(() {
          _isCheckingOut = false;
        });
      }
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
          'My Offers',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadOffers,
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

    if (_offers.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: 500,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'No offers yet',
                    style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/home'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryRed,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Browse Products'),
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
      itemCount: _offers.length,
      itemBuilder: (context, index) {
        final offer = _offers[index];
        final canCheckout = offer.status == 'accepted';
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
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: offer.productImage != null && offer.productImage!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(offer.productImage!, fit: BoxFit.cover),
                          )
                        : const Icon(Icons.image, color: Colors.grey),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          offer.productTitle,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatPrice(offer.offerPrice),
                          style: GoogleFonts.poppins(
                            color: primaryRed,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Status: ${offer.status.toUpperCase()}',
                          style: GoogleFonts.inter(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (canCheckout) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isCheckingOut
                        ? null
                        : () => _checkoutAcceptedOffer(offer),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryRed,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      _isCheckingOut ? 'PROCESSING...' : 'CHECKOUT',
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
