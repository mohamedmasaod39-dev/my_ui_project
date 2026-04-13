import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_ui_project/services/wishlist_service.dart';
import 'package:my_ui_project/utils/app_icon_mapper.dart';

class Product {
  final int id;
  final int? categoryId;
  final String? sellerId;
  final String title;
  final double price;
  final String? image;
  final String tag;
  final String description;
  final String condition;
  final String status;

  const Product({
    required this.id,
    required this.categoryId,
    required this.sellerId,
    required this.title,
    required this.price,
    required this.image,
    required this.tag,
    required this.description,
    required this.condition,
    required this.status,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    final rawId = map['id'];
    final rawPrice = map['price'];

    return Product(
      id: rawId is int ? rawId : int.tryParse('${rawId ?? 0}') ?? 0,
      categoryId: map['category_id'] as int?,
      sellerId: map['seller_id']?.toString(),
      title: (map['title'] ?? map['name'] ?? '').toString(),
      price: rawPrice is num
          ? rawPrice.toDouble()
          : double.tryParse('${rawPrice ?? 0}') ?? 0,
      image: (map['image'] ?? map['image_url'] ?? map['main_image_url'])
          ?.toString(),
      tag: (map['tag'] ?? 'product_${map['id'] ?? 0}').toString(),
      description: (map['description'] ?? '').toString(),
      condition: (map['condition'] ?? '').toString(),
      status: (map['status'] ?? '').toString(),
    );
  }
}

class IndexPage extends StatefulWidget {
  const IndexPage({super.key});

  @override
  State<IndexPage> createState() => _IndexPageState();
}

class _IndexPageState extends State<IndexPage> {
  static const Color primaryRed = Color(0xFFDB4444);
  static const Color offWhite = Color(0xFFF5F5F5);

  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _categories = [];

  int _selectedIndex = 0;
  bool _isLoading = true;
  List<Product> _products = [];
  final wishlistService = WishlistService.instance;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _loadCategories();
    wishlistService.load();
    wishlistService.favoriteIds.addListener(_onWishlistChanged);
  }

  @override
  void dispose() {
    wishlistService.favoriteIds.removeListener(_onWishlistChanged);
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final response = await supabase
          .from('products')
          .select()
          .eq('status', 'active')
          .order('created_at', ascending: false);

      final loadedProducts = (response as List)
          .map((item) => Product.fromMap(item as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _products = loadedProducts;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _products = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadCategories() async {
    try {
      final response = await supabase
          .from('categories')
          .select('name, icon')
          .order('created_at');

      if (!mounted) return;
      setState(() {
        _categories = (response as List)
            .map(
              (item) => {
                'label': (item['name'] ?? '').toString(),
                'icon': iconFromString(item['icon']?.toString()),
              },
            )
            .toList();
      });
    } catch (_) {}
  }

  void _onWishlistChanged() {
    if (mounted) {
      setState(() {});
    }
  }

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  String _formatPrice(double price) {
    return 'EGP ${price.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Listables',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 26,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () => Navigator.pushNamed(context, '/search'),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.favorite_border, color: Colors.black),
            onPressed: () => Navigator.pushNamed(context, '/wishlist'),
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined, color: Colors.black),
            onPressed: () => Navigator.pushNamed(context, '/cart'),
          ),
          const SizedBox(width: 10),
        ],
      ),
      extendBody: true,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroBanner(),
            _buildSectionHeader('Categories', 'Browse By Style'),
            _buildCategoryList(),
            _buildSectionHeader('Best Selling', "This Month's Top Picks"),
            _buildProductGrid(),
            const SizedBox(height: 120),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 25),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _navIcon(Icons.home_filled, 0),
          _navIcon(Icons.grid_view_rounded, 1),
          _navIcon(Icons.notifications_none, 2),
          _navIcon(Icons.person_outline, 3),
        ],
      ),
    );
  }

  Widget _navIcon(IconData icon, int index) {
    final isActive = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedIndex = index);
        if (index == 3) {
          Navigator.pushNamed(context, '/profile');
        } else if (index == 1) {
          Navigator.pushNamed(context, '/search');
        } else if (index == 2) {
          Navigator.pushNamed(context, '/notifications');
        }
      },
      child: Icon(
        icon,
        color: isActive ? primaryRed : Colors.white60,
        size: 28,
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      height: 180,
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'iPhone 17 Pro',
                    style: GoogleFonts.inter(color: Colors.white70),
                  ),
                  Text(
                    'The Future Is Here',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryRed,
                    ),
                    child: const Text(
                      'Pre-order Now',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Hero(
            tag: 'product_hero',
            child: Image.network(
              'https://images.unsplash.com/photo-1616348436168-de43ad0db179?w=300',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String tag, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 4, height: 16, color: primaryRed),
              const SizedBox(width: 8),
              Text(
                tag,
                style: GoogleFonts.inter(
                  color: primaryRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
    if (_categories.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 20),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          return _catItem(
            category['icon'] as IconData,
            category['label'] as String,
          );
        },
      ),
    );
  }

  Widget _catItem(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(
          context,
          '/category_products_page',
          arguments: label,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: offWhite,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: Colors.black),
            ),
            const SizedBox(height: 5),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildProductGrid() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_products.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: Text('No products available')),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 0.72,
      ),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];
        return _buildModernProductCard(product);
      },
    );
  }

  Widget _buildModernProductCard(Product product) {
    final isFavorite = wishlistService.isFavorite(product.id);

    return Container(
      decoration: BoxDecoration(
        color: offWhite,
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
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/details',
                      arguments: product,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
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
                      backgroundColor: Colors.white,
                      radius: 15,
                      child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                        color: isFavorite ? primaryRed : Colors.black,
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
              onTap: () => Navigator.pushNamed(
                context,
                '/details',
                arguments: product,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatPrice(product.price),
                    style: GoogleFonts.poppins(
                      color: primaryRed,
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
  }
}
