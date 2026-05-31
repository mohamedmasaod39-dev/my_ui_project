import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_ui_project/services/app_mode_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_ui_project/services/wishlist_service.dart';
import 'package:my_ui_project/theme/app_theme_colors.dart';
import 'index_page.dart';

class WishlistPage extends StatefulWidget {
  const WishlistPage({super.key});

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  static const Color primaryRed = Color(0xFFDB4444);
  final supabase = Supabase.instance.client;
  final _wishlistService = WishlistService.instance;
  bool _isLoading = true;
  bool _isSellerAccount = AppModeService.instance.isSeller;
  List<Product> _wishlistProducts = [];

  @override
  void initState() {
    super.initState();
    _loadWishlist();
  }

  Future<bool> _isCurrentUserSeller(String userId) async {
    try {
      final profile = await supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      final role = (profile?['role'] ?? '').toString().trim().toLowerCase();
      final isSeller = role == 'seller';
      if (isSeller) {
        AppModeService.instance.setMode(AppMode.seller);
      } else if (role == 'buyer') {
        AppModeService.instance.setMode(AppMode.buyer);
      }
      return isSeller;
    } catch (_) {
      return AppModeService.instance.isSeller;
    }
  }

  Future<void> _loadWishlist() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (await _isCurrentUserSeller(user.id)) {
        if (!mounted) return;
        setState(() {
          _isSellerAccount = true;
          _wishlistProducts = [];
          _isLoading = false;
        });
        return;
      }

      if (mounted && _isSellerAccount) {
        setState(() {
          _isSellerAccount = false;
        });
      }

      final response = await supabase
          .from('wishlist')
          .select('product_id, products(*)')
          .eq('user_id', user.id);

      final List<Product> products = [];
      for (var item in (response as List)) {
        if (item['products'] != null) {
          products.add(
            Product.fromMap(Map<String, dynamic>.from(item['products'])),
          );
        }
      }

      if (mounted) {
        setState(() {
          _wishlistProducts = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load wishlist: $e')));
      }
    }
  }

  Future<void> _removeFromWishlist(int productId) async {
    try {
      await _wishlistService.toggle(productId);
      setState(() {
        _wishlistProducts.removeWhere((p) => p.id == productId);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to remove: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppThemeColors.textPrimary(context);
    final secondaryText = AppThemeColors.textSecondary(context);

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
          'My Wishlist',
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isSellerAccount
          ? _buildSellerBlockedState(secondaryText)
          : _wishlistProducts.isEmpty
          ? _buildEmptyState(secondaryText)
          : _buildProductList(textColor, secondaryText),
    );
  }

  Widget _buildSellerBlockedState(Color secondaryText) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.storefront_outlined,
              size: 80,
              color: secondaryText.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 20),
            Text(
              'Seller accounts cannot start shopping',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: secondaryText,
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, '/seller_home'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryRed,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: Text(
                'Open Seller Dashboard',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color secondaryText) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 80,
            color: secondaryText.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 20),
          Text(
            'Your wishlist is empty',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: secondaryText,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Save items you like for later!',
            style: GoogleFonts.inter(
              color: secondaryText.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryRed,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: Text(
              'Start Shopping',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList(Color textColor, Color secondaryText) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _wishlistProducts.length,
      itemBuilder: (context, index) {
        final product = _wishlistProducts[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 15),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppThemeColors.surface(context),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: product.image != null && product.image!.isNotEmpty
                    ? Image.network(
                        product.image!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey.withValues(alpha: 0.1),
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${product.currency} ${product.price.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                        color: primaryRed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.favorite, color: primaryRed),
                    onPressed: () => _removeFromWishlist(product.id),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: secondaryText,
                    ),
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/details',
                      arguments: product,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
