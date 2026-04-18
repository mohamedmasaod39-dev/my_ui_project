import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_ui_project/main.dart';
import 'package:my_ui_project/pages/index_page.dart';
import 'package:my_ui_project/services/wishlist_service.dart';
import 'package:my_ui_project/theme/app_theme_colors.dart';

class CategoryProductsPage extends StatefulWidget {
  const CategoryProductsPage({super.key});

  @override
  State<CategoryProductsPage> createState() => _CategoryProductsPageState();
}

class _CategoryProductsPageState extends State<CategoryProductsPage>
    with RouteAware {
  final supabase = Supabase.instance.client;
  final wishlistService = WishlistService.instance;
  final TextEditingController _searchController = TextEditingController();

  static const Color primaryRed = Color(0xFFDB4444);

  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = true;
  bool _didSetupDependencies = false;

  String? categoryName;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.unsubscribe(this);
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }

    if (_didSetupDependencies) return;
    _didSetupDependencies = true;

    categoryName = ModalRoute.of(context)!.settings.arguments as String?;
    _searchController.addListener(_applyFilters);
    _loadProducts();
    wishlistService.load();
    wishlistService.favoriteIds.addListener(_onWishlistChanged);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _searchController.dispose();
    wishlistService.favoriteIds.removeListener(_onWishlistChanged);
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final category = await supabase
          .from('categories')
          .select('id')
          .eq('name', categoryName!)
          .single();

      final response = await supabase
          .from('products')
          .select()
          .eq('category_id', category['id'])
          .neq('status', 'hidden');

      final data = (response as List).map((e) => Product.fromMap(e)).toList();

      setState(() {
        _products = data;
        _filteredProducts = data;
      });

      _applyFilters();
    } catch (e) {
      debugPrint('Failed to load category products: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();

    final filtered = _products.where((product) {
      if (query.isEmpty) {
        return true;
      }

      return product.title.toLowerCase().contains(query) ||
          product.description.toLowerCase().contains(query);
    }).toList();

    if (!mounted) return;
    setState(() {
      _filteredProducts = filtered;
    });
  }

  void _onWishlistChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  String _formatPrice(double price) => 'EGP ${price.toStringAsFixed(0)}';

  Future<void> _toggleFavorite(Product product) async {
    try {
      final isAdding = await wishlistService.toggle(product.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAdding ? 'Added to wishlist' : 'Removed from wishlist',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppThemeColors.textPrimary(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          categoryName ?? '',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search in ${categoryName ?? 'category'}',
                hintStyle: GoogleFonts.inter(
                  color: AppThemeColors.textSecondary(context),
                ),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppThemeColors.surface(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_products.isEmpty) {
      return const Center(child: Text('No products'));
    }

    if (_filteredProducts.isEmpty) {
      return const Center(child: Text('No matching products found'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 0.72,
      ),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        final isFav = wishlistService.isFavorite(product.id);
        final isOutOfStock = product.status.toLowerCase() == 'sold';
        final textColor = AppThemeColors.textPrimary(context);

        return Container(
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
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/details',
                            arguments: product,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(15),
                          child: Hero(
                            tag: product.tag,
                            child:
                                product.image != null && product.image!.isNotEmpty
                                    ? Image.network(
                                        product.image!,
                                        fit: BoxFit.contain,
                                      )
                                    : const Icon(
                                        Icons.image_not_supported,
                                        color: Colors.grey,
                                        size: 48,
                                      ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: () => _toggleFavorite(product),
                        child: CircleAvatar(
                          backgroundColor: AppThemeColors.elevatedSurface(
                            context,
                          ),
                          radius: 15,
                          child: Icon(
                            isFav ? Icons.favorite : Icons.favorite_border,
                            size: 18,
                            color: isFav ? primaryRed : textColor,
                          ),
                        ),
                      ),
                    ),
                    if (isOutOfStock)
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
                            'Out of stock',
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/details',
                      arguments: product,
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatPrice(product.price),
                      style: GoogleFonts.poppins(
                        color: isOutOfStock ? Colors.grey : primaryRed,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
