import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_ui_project/theme/app_theme_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'index_page.dart';

class SellerProfilePage extends StatefulWidget {
  const SellerProfilePage({super.key});

  @override
  State<SellerProfilePage> createState() => _SellerProfilePageState();
}

class _SellerProfilePageState extends State<SellerProfilePage> {
  static const Color primaryRed = Color(0xFFDB4444);

  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _errorMessage;
  String? _sellerId;
  Map<String, dynamic>? _sellerProfile;
  List<Product> _products = [];
  List<Map<String, dynamic>> _reviews = [];
  int _selectedTab = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    final sellerId = args is String ? args.trim() : '';
    if (sellerId.isEmpty || sellerId == _sellerId) return;
    _sellerId = sellerId;
    _loadSellerProfile();
  }

  Future<void> _loadSellerProfile() async {
    final sellerId = _sellerId;
    if (sellerId == null || sellerId.isEmpty) return;

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final profileFuture = supabase
          .from('profiles')
          .select(
            'id, full_name, email, role, shop_name, bio, location, phone, avatar_url',
          )
          .eq('id', sellerId)
          .maybeSingle();

      final productsFuture = supabase
          .from('products')
          .select()
          .eq('seller_id', sellerId)
          .eq('validated', true)
          .inFilter('status', ['active', 'sold'])
          .order('created_at', ascending: false);

      final reviewsFuture = supabase
          .from('reviews')
          .select('id, order_id, rating, comment, created_at, buyer_id')
          .eq('seller_id', sellerId)
          .order('created_at', ascending: false);

      final results = await Future.wait([
        profileFuture,
        productsFuture,
        reviewsFuture,
      ]);

      final profile = results[0] as Map<String, dynamic>?;
      final products = results[1] as List;
      final reviews = results[2] as List;

      if (!mounted) return;
      setState(() {
        _sellerProfile = profile == null
            ? null
            : Map<String, dynamic>.from(profile);
        _products = products
            .map(
              (item) => Product.fromMap(Map<String, dynamic>.from(item as Map)),
            )
            .toList();
        _reviews = reviews
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load seller profile';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  double get _averageRating {
    if (_reviews.isEmpty) return 0;
    final total = _reviews.fold<double>(
      0,
      (sum, review) => sum + ((review['rating'] as num?)?.toDouble() ?? 0),
    );
    return total / _reviews.length;
  }

  String get _headerName {
    final profile = _sellerProfile;
    if (profile == null) return 'Seller';
    final shopName = (profile['shop_name'] ?? '').toString().trim();
    if (shopName.isNotEmpty) return shopName;
    final fullName = (profile['full_name'] ?? '').toString().trim();
    if (fullName.isNotEmpty) return fullName;
    final email = (profile['email'] ?? '').toString().trim();
    return email.isNotEmpty ? email : 'Seller';
  }

  Future<void> _messageSeller() async {
    final user = supabase.auth.currentUser;
    final sellerId = _sellerId;
    if (user == null ||
        sellerId == null ||
        sellerId.isEmpty ||
        sellerId == user.id) {
      return;
    }

    try {
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
              'seller_name': _headerName,
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
          'otherUserName': _headerName,
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to open seller chat: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppThemeColors.textPrimary(context);
    final secondaryText = AppThemeColors.textSecondary(context);
    final profile = _sellerProfile;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Seller Profile',
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadSellerProfile,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? ListView(
                children: [
                  SizedBox(
                    height: 500,
                    child: Center(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.inter(color: secondaryText),
                      ),
                    ),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppThemeColors.surface(context),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 34,
                              backgroundColor: primaryRed.withValues(
                                alpha: 0.12,
                              ),
                              backgroundImage:
                                  (profile?['avatar_url'] ?? '')
                                      .toString()
                                      .trim()
                                      .isNotEmpty
                                  ? NetworkImage(
                                      profile!['avatar_url'].toString(),
                                    )
                                  : null,
                              child:
                                  (profile?['avatar_url'] ?? '')
                                      .toString()
                                      .trim()
                                      .isEmpty
                                  ? const Icon(
                                      Icons.storefront_outlined,
                                      color: primaryRed,
                                      size: 30,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _headerName,
                                    style: GoogleFonts.poppins(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  if ((profile?['location'] ?? '')
                                      .toString()
                                      .trim()
                                      .isNotEmpty)
                                    Text(
                                      profile!['location'].toString(),
                                      style: GoogleFonts.inter(
                                        color: secondaryText,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_reviews.isEmpty)
                          Text(
                            'No reviews yet',
                            style: GoogleFonts.inter(color: secondaryText),
                          )
                        else
                          Row(
                            children: [
                              ...List.generate(
                                5,
                                (index) => Icon(
                                  index < _averageRating.round()
                                      ? Icons.star
                                      : Icons.star_border,
                                  size: 18,
                                  color: Colors.amber,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_averageRating.toStringAsFixed(1)} / 5 (${_reviews.length})',
                                style: GoogleFonts.inter(color: secondaryText),
                              ),
                            ],
                          ),
                        if ((profile?['bio'] ?? '')
                            .toString()
                            .trim()
                            .isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            profile!['bio'].toString(),
                            style: GoogleFonts.inter(
                              color: secondaryText,
                              height: 1.5,
                            ),
                          ),
                        ],
                        if (supabase.auth.currentUser?.id != _sellerId) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _messageSeller,
                              icon: const Icon(Icons.chat_bubble_outline),
                              label: const Text('Message Seller'),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _tabButton('Products', 0)),
                      const SizedBox(width: 10),
                      Expanded(child: _tabButton('Reviews', 1)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_selectedTab == 0)
                    _buildProductsTab(textColor, secondaryText),
                  if (_selectedTab == 1)
                    _buildReviewsTab(textColor, secondaryText),
                ],
              ),
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? primaryRed : AppThemeColors.surface(context),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            '$label (${index == 0 ? _products.length : _reviews.length})',
            style: GoogleFonts.poppins(
              color: isSelected
                  ? Colors.white
                  : AppThemeColors.textPrimary(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductsTab(Color textColor, Color secondaryText) {
    if (_products.isEmpty) {
      return Text(
        'No listings yet.',
        style: GoogleFonts.inter(color: secondaryText),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.74,
      ),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];
        final isUnavailable = product.isUnavailable;
        return GestureDetector(
          onTap: () =>
              Navigator.pushNamed(context, '/details', arguments: product),
          child: Container(
            decoration: BoxDecoration(
              color: AppThemeColors.surface(context),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child:
                              product.image != null && product.image!.isNotEmpty
                              ? Image.network(
                                  product.image!,
                                  fit: BoxFit.contain,
                                )
                              : const Icon(
                                  Icons.image_not_supported,
                                  color: Colors.grey,
                                ),
                        ),
                      ),
                      if (isUnavailable)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              product.availabilityLabel,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${product.currency} ${product.price.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          color: isUnavailable ? Colors.grey : primaryRed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReviewsTab(Color textColor, Color secondaryText) {
    if (_reviews.isEmpty) {
      return Text(
        'No reviews yet.',
        style: GoogleFonts.inter(color: secondaryText),
      );
    }

    return Column(
      children: _reviews.map((review) {
        final rating = (review['rating'] as num?)?.toInt() ?? 0;
        final comment = (review['comment'] ?? '').toString().trim();
        final createdAt = DateTime.tryParse('${review['created_at']}');
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppThemeColors.surface(context),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ...List.generate(
                    5,
                    (index) => Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      size: 18,
                      color: Colors.amber,
                    ),
                  ),
                  const Spacer(),
                  if (createdAt != null)
                    Text(
                      '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: secondaryText,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                comment.isEmpty ? 'No comment left.' : comment,
                style: GoogleFonts.inter(
                  color: comment.isEmpty ? secondaryText : textColor,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Order #${review['order_id']}',
                style: GoogleFonts.inter(fontSize: 12, color: secondaryText),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
