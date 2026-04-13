import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_ui_project/pages/index_page.dart';
import 'package:my_ui_project/services/wishlist_service.dart';

class CategoryProductsPage extends StatefulWidget {
  const CategoryProductsPage({super.key});

  @override
  State<CategoryProductsPage> createState() => _CategoryProductsPageState();
}

class _CategoryProductsPageState extends State<CategoryProductsPage> {
  final supabase = Supabase.instance.client;
  final wishlistService = WishlistService.instance;

  static const Color primaryRed = Color(0xFFDB4444);
  static const Color offWhite = Color(0xFFF5F5F5);

  List<Product> _products = [];
  bool _isLoading = true;

  String? categoryName;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    
    categoryName =
        ModalRoute.of(context)!.settings.arguments as String?;

    _loadProducts();
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
      final category = await supabase
          .from('categories')
          .select('id')
          .eq('name', categoryName!)
          .single();

      final response = await supabase
          .from('products')
          .select()
          .eq('category_id', category['id'])
          .eq('status', 'active');

      final data = (response as List)
          .map((e) => Product.fromMap(e))
          .toList();

      setState(() {
        _products = data;
      });
    } catch (e) {
      debugPrint('Failed to load category products: $e');
    } finally {
      setState(() => _isLoading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(categoryName ?? ''),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? const Center(child: Text("No products"))
              : GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    final isFav = wishlistService.isFavorite(product.id);

                    return Container(
                      decoration: BoxDecoration(
                        color: offWhite,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: Stack(
                              children: [
                                InkWell(
                                  onTap: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/details',
                                      arguments: product,
                                    );
                                  },
                                  child: Center(
                                    child: Padding(
                                      padding:
                                          const EdgeInsets.all(15),
                                      child: Image.network(
                                        product.image ?? '',
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
                                      child: Icon(
                                        isFav
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        color: isFav
                                            ? primaryRed
                                            : Colors.black,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              children: [
                                Text(product.title),
                                Text(
                                  "EGP ${product.price}",
                                  style: const TextStyle(
                                      color: primaryRed),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
