import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_ui_project/theme/app_theme_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'index_page.dart';

class AdminProductsPage extends StatefulWidget {
  const AdminProductsPage({super.key});

  @override
  State<AdminProductsPage> createState() => _AdminProductsPageState();
}

class _AdminProductsPageState extends State<AdminProductsPage> {
  static const Color primaryRed = Color(0xFFDB4444);

  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Product> _products = [];
  int _selectedFilter = 0;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final response = await supabase
          .from('products')
          .select()
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _products = (response as List)
            .map(
              (item) => Product.fromMap(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateValidation(Product product, bool approved) async {
    try {
      await supabase.from('products').update({
        'validated': approved,
        'status': approved
            ? (product.status == 'hidden' ? 'active' : product.status)
            : (product.status == 'active' ? 'hidden' : product.status),
      }).eq('id', product.id);

      await _loadProducts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approved ? 'Listing approved' : 'Listing rejected'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    }
  }

  List<Product> get _filteredProducts {
    switch (_selectedFilter) {
      case 1:
        return _products.where((product) => !product.validated).toList();
      case 2:
        return _products.where((product) => product.validated).toList();
      case 3:
        return _products
            .where((product) => !product.validated && product.status == 'hidden')
            .toList();
      default:
        return _products;
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
        centerTitle: true,
        title: Text(
          'Products',
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryRed))
          : _products.isEmpty
              ? _buildEmpty(secondaryText)
              : RefreshIndicator(
                  color: primaryRed,
                  onRefresh: _loadProducts,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _filterChip('All', 0),
                            _filterChip('Pending', 1),
                            _filterChip('Approved', 2),
                            _filterChip('Rejected', 3),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._filteredProducts.map(
                        (product) => _buildProductCard(
                          product,
                          textColor,
                          secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmpty(Color secondaryText) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primaryRed.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: primaryRed.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No products found',
            style: GoogleFonts.poppins(
              color: secondaryText,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(
    Product product,
    Color textColor,
    Color secondaryText,
  ) {
    final status = product.status;
    final isActive = status == 'active';
    final imageUrl = product.image;
    final approvalText = product.validated ? 'APPROVED' : 'PENDING REVIEW';
    final approvalColor = product.validated ? Colors.green : Colors.orange;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/details', arguments: product),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppThemeColors.surface(context),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 64,
                    height: 64,
                    color: AppThemeColors.elevatedSurface(context),
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _productIconPlaceholder(),
                          )
                        : _productIconPlaceholder(),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.title,
                        style: GoogleFonts.poppins(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${product.currency} ${product.price.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          color: primaryRed,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Stock: ${product.stockQty}',
                        style: GoogleFonts.inter(
                          color: secondaryText,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isActive ? Colors.green : Colors.red,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: approvalColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              approvalText,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: approvalColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: product.validated
                        ? null
                        : () => _updateValidation(product, true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                    ),
                    child: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _updateValidation(product, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryRed,
                      side: const BorderSide(color: primaryRed),
                    ),
                    child: Text(product.validated ? 'Revoke' : 'Reject'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, int index) {
    final isSelected = _selectedFilter == index;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) {
          setState(() {
            _selectedFilter = index;
          });
        },
        selectedColor: primaryRed.withValues(alpha: 0.16),
        labelStyle: GoogleFonts.inter(
          color: isSelected ? primaryRed : AppThemeColors.textPrimary(context),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _productIconPlaceholder() {
    return Center(
      child: Icon(
        Icons.shopping_bag_outlined,
        color: primaryRed.withValues(alpha: 0.5),
        size: 28,
      ),
    );
  }
}
