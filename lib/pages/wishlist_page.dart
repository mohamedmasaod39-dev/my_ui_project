import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  final wishlistService = WishlistService.instance;
  bool _isLoading = true;
  String? _errorMessage;
  List<Product> _wishlistProducts = [];

  @override
  void initState() {
    super.initState();
    _loadWishlist();
    wishlistService.favoriteIds.addListener(_onWishlistChanged);
  }

  @override
  void dispose() {
    wishlistService.favoriteIds.removeListener(_onWishlistChanged);
    super.dispose();
  }

  void _onWishlistChanged() {
    _loadWishlist();
  }

  Future<void> _loadWishlist() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _wishlistProducts = [];
          _isLoading = false;
        });
        return;
      }

      final response = await supabase
          .from('wishlist')
          .select('product_id, products(*)')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final items = response as List;

      final loadedProducts = items
          .map((item) => item['products'])
          .where((product) => product != null)
          .map((product) => Product.fromMap(Map<String, dynamic>.from(product)))
          .toList();

      setState(() {
        _wishlistProducts = loadedProducts;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load wishlist';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _removeFromWishlist(int productId) async {
    try {
      setState(() {
        _wishlistProducts =
            _wishlistProducts.where((product) => product.id != productId).toList();
      });

      await wishlistService.remove(productId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed from wishlist')),
      );
    } catch (e) {
      if (!mounted) return;
      await _loadWishlist();
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to remove item')),
      );
    }
  }

  String _formatPrice(double price) {
    return 'EGP ${price.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppThemeColors.textPrimary(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          "Wishlist",
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadWishlist,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: 600,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_errorMessage != null) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: 600,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_errorMessage!, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loadWishlist,
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_wishlistProducts.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: 600,
          child: _buildEmptyState(),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 0.7,
      ),
      itemCount: _wishlistProducts.length,
      itemBuilder: (context, index) =>
          _buildWishlistCard(_wishlistProducts[index]),
    );
  }

  Widget _buildWishlistCard(Product product) {
    final textColor = AppThemeColors.textPrimary(context);

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/details', arguments: product),
        child: Container(
          decoration: BoxDecoration(
          color: AppThemeColors.surface(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: product.image != null && product.image!.isNotEmpty
                        ? Image.network(
                            product.image!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.image_not_supported,
                                size: 50,
                                color: Colors.grey,
                              );
                            },
                          )
                        : const Icon(
                            Icons.image,
                            size: 50,
                            color: Colors.grey,
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(
                        product.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _formatPrice(product.price),
                        style: const TextStyle(
                          color: primaryRed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: AppThemeColors.elevatedSurface(context),
                child: IconButton(
                  icon: const Icon(Icons.delete_outline, color: primaryRed),
                  onPressed: () => _removeFromWishlist(product.id),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text(
            "Your wishlist is empty",
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: AppThemeColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}
