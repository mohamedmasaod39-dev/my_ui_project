import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_ui_project/pages/index_page.dart' show Product;
import 'package:my_ui_project/theme/app_theme_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PublicSellerProfilePage extends StatefulWidget {
  const PublicSellerProfilePage({super.key});

  @override
  State<PublicSellerProfilePage> createState() =>
      _PublicSellerProfilePageState();
}

class _PublicSellerProfilePageState extends State<PublicSellerProfilePage> {
  static const Color primaryRed = Color(0xFFDB4444);
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _errorMessage;

  Map<String, dynamic>? _profile;
  List<Product> _products = [];
  List<Map<String, dynamic>> _reviews = [];
  double _avgRating = 0.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sellerId = ModalRoute.of(context)?.settings.arguments as String?;
    if (sellerId != null && _isLoading) {
      _loadData(sellerId);
    }
  }

  Future<void> _loadData(String sellerId) async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Load profile
      final profileData = await supabase
          .from('profiles')
          .select()
          .eq('id', sellerId)
          .maybeSingle();

      // Load products
      final productsData = await supabase
          .from('products')
          .select()
          .eq('seller_id', sellerId)
          .inFilter('status', ['active', 'sold'])
          .eq('validated', true);

      final productsList = (productsData as List)
          .map(
            (item) => Product.fromMap(Map<String, dynamic>.from(item as Map)),
          )
          .toList();

      // Load reviews - using a safer join syntax or fallback
      List<Map<String, dynamic>> reviewsList = [];
      try {
        final reviewsData = await supabase
            .from('reviews')
            .select(
              'rating, comment, created_at, profiles!inner(full_name, email)',
            )
            .eq('seller_id', sellerId)
            .order('created_at', ascending: false);

        reviewsList = (reviewsData as List).map((item) {
          final r = Map<String, dynamic>.from(item as Map);
          final p = r['profiles'] as Map<String, dynamic>? ?? {};
          r['buyer_name'] = p['full_name'] ?? p['email'] ?? 'A buyer';
          return r;
        }).toList();
      } catch (reviewError) {
        // Fallback: load reviews without profile names if join fails
        final reviewsData = await supabase
            .from('reviews')
            .select('rating, comment, created_at, buyer_id')
            .eq('seller_id', sellerId)
            .order('created_at', ascending: false);

        reviewsList = (reviewsData as List).map((item) {
          final r = Map<String, dynamic>.from(item as Map);
          r['buyer_name'] = 'A buyer'; // Default name since join failed
          return r;
        }).toList();
      }

      double avg = 0.0;
      if (reviewsList.isNotEmpty) {
        final sum = reviewsList.fold<double>(
          0.0,
          (prev, element) => prev + (element['rating'] as num).toDouble(),
        );
        avg = sum / reviewsList.length;
      }

      if (mounted) {
        setState(() {
          _profile = profileData;
          _products = productsList;
          _reviews = reviewsList;
          _avgRating = avg;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load seller profile: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppThemeColors.textPrimary(context);
    final secondaryTextColor = AppThemeColors.textSecondary(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: textColor),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: textColor),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Text(
            _errorMessage!,
            style: GoogleFonts.inter(color: Colors.red),
          ),
        ),
      );
    }

    final shopName =
        _profile?['shop_name'] ?? _profile?['full_name'] ?? 'Seller';
    final bio = _profile?['bio'] ?? '';
    final location = _profile?['location'] ?? '';
    final avatarUrl = _profile?['avatar_url'];

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
          shopName,
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppThemeColors.elevatedSurface(context),
                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl == null || avatarUrl.isEmpty
                      ? Icon(
                          Icons.storefront,
                          size: 40,
                          color: secondaryTextColor,
                        )
                      : null,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shopName,
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      if (location.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: secondaryTextColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              location,
                              style: GoogleFonts.inter(
                                color: secondaryTextColor,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            _avgRating > 0
                                ? _avgRating.toStringAsFixed(1)
                                : 'New',
                            style: GoogleFonts.inter(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            ' (${_reviews.length} reviews)',
                            style: GoogleFonts.inter(color: secondaryTextColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (bio.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'About',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                bio,
                style: GoogleFonts.inter(
                  color: secondaryTextColor,
                  height: 1.5,
                ),
              ),
            ],
            if (_profile == null && _products.isEmpty) ...[
              const SizedBox(height: 100),
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.person_off_outlined,
                      size: 64,
                      color: secondaryTextColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Seller information not found',
                      style: GoogleFonts.poppins(
                        color: secondaryTextColor,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            if (_products.isNotEmpty) ...[
              Text(
                'Listings',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                itemCount: _products.length,
                itemBuilder: (context, index) {
                  final product = _products[index];
                  final isUnavailable = product.isUnavailable;
                  return GestureDetector(
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/details',
                      arguments: product,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppThemeColors.surface(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppThemeColors.border(context),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(16),
                                  ),
                                  child: product.image != null
                                      ? Image.network(
                                          product.image!,
                                          width: double.infinity,
                                          height: double.infinity,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          color: Colors.grey.withValues(
                                            alpha: 0.2,
                                          ),
                                        ),
                                ),
                                if (isUnavailable)
                                  Positioned(
                                    top: 8,
                                    left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black87,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
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
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.title,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${product.currency} ${product.price.toStringAsFixed(0)}',
                                  style: GoogleFonts.poppins(
                                    color: isUnavailable
                                        ? Colors.grey
                                        : primaryRed,
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
              ),
              const SizedBox(height: 32),
            ],
            if (_reviews.isNotEmpty) ...[
              Text(
                'Recent Reviews',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _reviews.length,
                separatorBuilder: (_, __) => const Divider(height: 32),
                itemBuilder: (context, index) {
                  final review = _reviews[index];
                  final rating = review['rating'] as int? ?? 5;
                  final comment = review['comment'] as String? ?? '';
                  final buyerName = review['buyer_name'] as String? ?? 'Buyer';
                  final date = DateTime.tryParse(
                    review['created_at']?.toString() ?? '',
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            buyerName,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          if (date != null)
                            Text(
                              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                              style: GoogleFonts.inter(
                                color: secondaryTextColor,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 16,
                          ),
                        ),
                      ),
                      if (comment.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          comment,
                          style: GoogleFonts.inter(
                            color: secondaryTextColor,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
