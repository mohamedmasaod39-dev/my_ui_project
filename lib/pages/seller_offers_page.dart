import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_ui_project/theme/app_theme_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, dynamic>? _firstRelationMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  if (value is List && value.isNotEmpty) {
    final first = value.first;
    if (first is Map<String, dynamic>) {
      return first;
    }
    if (first is Map) {
      return Map<String, dynamic>.from(first);
    }
  }
  return null;
}

class SellerOfferModel {
  const SellerOfferModel({
    required this.id,
    required this.offerPrice,
    required this.status,
    required this.productTitle,
    required this.productImage,
    required this.buyerId,
  });

  final int id;
  final double offerPrice;
  final String status;
  final String productTitle;
  final String? productImage;
  final String buyerId;

  factory SellerOfferModel.fromMap(Map<String, dynamic> map) {
    final rawPrice = map['offer_price'];
    final product = _firstRelationMap(map['products']);

    return SellerOfferModel(
      id: map['id'] as int,
      offerPrice: rawPrice is num
          ? rawPrice.toDouble()
          : double.tryParse('${rawPrice ?? 0}') ?? 0,
      status: (map['status'] ?? 'pending').toString(),
      productTitle: (product?['title'] ?? 'Product').toString(),
      productImage: product?['main_image_url']?.toString(),
      buyerId: (map['buyer_id'] ?? '').toString(),
    );
  }
}

class SellerOffersPage extends StatefulWidget {
  const SellerOffersPage({super.key});

  @override
  State<SellerOffersPage> createState() => _SellerOffersPageState();
}

class _SellerOffersPageState extends State<SellerOffersPage> {
  static const Color primaryRed = Color(0xFFDB4444);

  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _errorMessage;
  List<SellerOfferModel> _offers = [];

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
          .select('id, offer_price, status, buyer_id, products(title, main_image_url)')
          .eq('seller_id', user.id)
          .order('created_at', ascending: false);

      final loadedOffers = (response as List)
          .map((item) => SellerOfferModel.fromMap(item as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _offers = loadedOffers;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load received offers';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateOffer(SellerOfferModel offer, String status) async {
    try {
      await supabase.from('offers').update({'status': status}).eq('id', offer.id);
      await _loadOffers();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Offer marked as $status')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update offer: $e')),
      );
    }
  }

  String _formatPrice(double price) => 'EGP ${price.toStringAsFixed(0)}';

  Color _statusColor(BuildContext context, String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Colors.green;
      case 'cancelled':
      case 'canceled':
      case 'rejected':
        return primaryRed;
      default:
        return AppThemeColors.textSecondary(context);
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
          'Received Offers',
          style: GoogleFonts.poppins(
            color: textColor,
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
                    'No received offers yet',
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
                    child: const Text('View My Products'),
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
        final isPending = offer.status == 'pending';
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
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppThemeColors.elevatedSurface(context),
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
                            color: textColor,
                          ),
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
                          style: GoogleFonts.inter(
                            color: _statusColor(context, offer.status),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (isPending) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _updateOffer(offer, 'rejected'),
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _updateOffer(offer, 'accepted'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryRed,
                        ),
                        child: const Text(
                          'Accept',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
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
