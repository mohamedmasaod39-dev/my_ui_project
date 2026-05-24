import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'package:my_ui_project/pages/index_page.dart';
import 'package:my_ui_project/services/wishlist_service.dart';
import 'package:my_ui_project/theme/app_theme_colors.dart';

/// Returns the listing_details key to use as a sub-filter for a given category.
String _filterFieldFor(String categoryName) {
  final lower = categoryName.toLowerCase();
  if (lower.contains('gaming') || lower.contains('game')) return 'Platform';
  if (lower.contains('electronic')) return 'Brand';
  if (lower.contains('home') || lower.contains('furniture')) return 'Material';
  if (lower.contains('fashion') || lower.contains('clothing')) return 'Gender';
  if (lower.contains('sport')) return 'Sport';
  return 'Genre';
}

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
  bool _isRouteObserverSubscribed = false;

  String? categoryName;

  // Sub-filter state
  String? _activeFilterValue; // null = "All"
  List<String> _filterOptions = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isRouteObserverSubscribed) {
      final route = ModalRoute.of(context);
      if (route is PageRoute) {
        routeObserver.subscribe(this, route);
        _isRouteObserverSubscribed = true;
      }
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
    if (_isRouteObserverSubscribed) {
      routeObserver.unsubscribe(this);
      _isRouteObserverSubscribed = false;
    }
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
          .inFilter('status', ['active', 'sold'])
          .eq('validated', true);

      final data = (response as List).map((e) => Product.fromMap(e)).toList();

      // Build sub-filter options from listing_details
      final filterField = _filterFieldFor(categoryName ?? '');
      final seen = <String>{};
      final options = <String>[];
      for (final p in data) {
        final val = p.listingDetails[filterField]?.toString().trim() ?? '';
        if (val.isNotEmpty && seen.add(val)) {
          options.add(val);
        }
      }
      options.sort();

      if (!mounted) return;
      setState(() {
        _products = data;
        _filterOptions = options;
        // Reset filter if it no longer exists
        if (_activeFilterValue != null &&
            !options.contains(_activeFilterValue)) {
          _activeFilterValue = null;
        }
      });

      _applyFilters();
    } catch (e) {
      debugPrint('Failed to load category products: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    final filterField = _filterFieldFor(categoryName ?? '');

    final filtered = _products.where((product) {
      // Text search
      final matchesText =
          query.isEmpty ||
          product.title.toLowerCase().contains(query) ||
          product.description.toLowerCase().contains(query);

      // Sub-filter
      final matchesFilter =
          _activeFilterValue == null ||
          (product.listingDetails[filterField]?.toString().trim() ==
              _activeFilterValue);

      return matchesText && matchesFilter;
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

  String _formatPrice(Product product) =>
      '${product.currency} ${product.price.toStringAsFixed(0)}';

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
    final filterField = _filterFieldFor(categoryName ?? '');

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
          // ── Search bar ──
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

          // ── Sub-filter chips ──
          if (_filterOptions.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filterOptions.length + 1, // +1 for "All"
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // "All" chip
                    final isSelected = _activeFilterValue == null;
                    return _filterChip(
                      label: 'All $filterField',
                      selected: isSelected,
                      onTap: () {
                        setState(() => _activeFilterValue = null);
                        _applyFilters();
                      },
                    );
                  }
                  final val = _filterOptions[index - 1];
                  final isSelected = _activeFilterValue == val;
                  return _filterChip(
                    label: val,
                    selected: isSelected,
                    onTap: () {
                      setState(
                        () => _activeFilterValue = isSelected ? null : val,
                      );
                      _applyFilters();
                    },
                  );
                },
              ),
            ),

          if (_filterOptions.isNotEmpty) const SizedBox(height: 8),

          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? primaryRed : AppThemeColors.surface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? primaryRed : Colors.transparent),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: selected
                ? Colors.white
                : AppThemeColors.textPrimary(context),
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
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
        final isOutOfStock = product.isUnavailable;
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
                                product.image != null &&
                                    product.image!.isNotEmpty
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
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
                        _formatPrice(product),
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
