import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_ui_project/theme/app_theme_colors.dart';
import 'index_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const Color primaryRed = Color(0xFFDB4444);

  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  int selectedCategory = 0;
  bool _isLoading = true;
  String? _errorMessage;
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  List<Map<String, dynamic>> _categories = [
    {'id': 0, 'name': 'All'},
  ];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadProducts();
    _searchController.addListener(_applyFilters);
  }

  Future<void> _loadCategories() async {
    // Hardcoded to match website baseline
    final baseline = [
      {'id': 0, 'name': 'All'},
      {'id': 1, 'name': 'Electronics'},
      {'id': 2, 'name': 'Gaming'},
      {'id': 3, 'name': 'Home'},
      {'id': 4, 'name': 'Fashion'},
      {'id': 5, 'name': 'Sports'},
      {'id': 6, 'name': 'Other'},
    ];

    if (!mounted) return;
    setState(() {
      _categories = baseline;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final response = await supabase
          .from('products')
          .select()
          .inFilter('status', ['active', 'sold'])
          .eq('validated', true)
          .order('created_at', ascending: false);

      final loadedProducts = (response as List)
          .map((item) => Product.fromMap(item as Map<String, dynamic>))
          .toList();

      setState(() {
        _allProducts = loadedProducts;
      });

      _applyFilters();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load search results';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();

    List<Product> result = List.from(_allProducts);

    if (selectedCategory != 0) {
      final categoryId = _categories[selectedCategory]['id'];
      result = result
          .where((product) => product.categoryId == categoryId)
          .toList();
    }

    if (query.isNotEmpty) {
      result = result.where((product) {
        return product.title.toLowerCase().contains(query) ||
            product.description.toLowerCase().contains(query);
      }).toList();
    }

    setState(() {
      _filteredProducts = result;
    });
  }

  String _formatPrice(Product product) {
    return '${product.currency} ${product.price.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppThemeColors.textPrimary(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          height: 45,
          decoration: BoxDecoration(
            color: AppThemeColors.surface(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _searchController,
            style: GoogleFonts.inter(color: textColor),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              hintText: "Search Listables...",
              hintStyle: GoogleFonts.inter(
                color: AppThemeColors.textSecondary(context),
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: AppThemeColors.textSecondary(context),
                size: 20,
              ),
              border: InputBorder.none,
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 20),
              itemCount: _categories.length,
              itemBuilder: (context, index) => _buildFilterChip(index),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              "Found ${_filteredProducts.length} Results",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: textColor,
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

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadProducts,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_filteredProducts.isEmpty) {
      return const Center(
        child: Text(
          'No matching products found',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 0.75,
      ),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) =>
          _buildSearchCard(_filteredProducts[index]),
    );
  }

  Widget _buildFilterChip(int index) {
    final bool isSelected = selectedCategory == index;
    final textColor = AppThemeColors.textPrimary(context);

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedCategory = index;
        });
        _applyFilters();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryRed
              : AppThemeColors.elevatedSurface(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? primaryRed : AppThemeColors.border(context),
          ),
        ),
        child: Center(
          child: Text(
            _categories[index]['name'],
            style: GoogleFonts.inter(
              color: isSelected ? Colors.white : textColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchCard(Product product) {
    final textColor = AppThemeColors.textPrimary(context);
    final isOutOfStock = product.isUnavailable;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/details', arguments: product),
      child: Container(
        decoration: BoxDecoration(
          color: AppThemeColors.surface(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Center(
                    child: Hero(
                      tag: product.tag,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child:
                            product.image != null && product.image!.isNotEmpty
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
              padding: const EdgeInsets.all(12.0),
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
                  const SizedBox(height: 4),
                  Text(
                    _formatPrice(product),
                    style: TextStyle(
                      color: isOutOfStock ? Colors.grey : primaryRed,
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
  }
}
