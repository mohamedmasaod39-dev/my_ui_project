import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_ui_project/services/chat_identity_cache.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_ui_project/services/wishlist_service.dart';
import 'package:my_ui_project/theme/app_theme_colors.dart';
import 'index_page.dart';

class DetailsPage extends StatefulWidget {
  const DetailsPage({super.key});

  @override
  State<DetailsPage> createState() => _DetailsPageState();
}

class _DetailsPageState extends State<DetailsPage> {
  static const Color primaryRed = Color(0xFFDB4444);
  final supabase = Supabase.instance.client;
  final wishlistService = WishlistService.instance;
  bool _isFavorite = false;
  bool _isSubmittingOffer = false;
  int? _syncedFavoriteProductId;
  Product? _product;

  @override
  void initState() {
    super.initState();
    wishlistService.favoriteIds.addListener(_onWishlistChanged);
  }

  @override
  void dispose() {
    wishlistService.favoriteIds.removeListener(_onWishlistChanged);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final routeProduct = ModalRoute.of(context)?.settings.arguments as Product?;
    if (routeProduct == null) return;
    if (_product?.id == routeProduct.id) return;

    _product = routeProduct;
    _ensureFavoriteState(routeProduct);
  }

  String _formatPrice(double price) {
    return 'EGP ${price.toStringAsFixed(0)}';
  }

  Future<void> _syncFavoriteState(Product product) async {
    await wishlistService.load();
    if (!mounted) return;
    setState(() {
      _isFavorite = wishlistService.isFavorite(product.id);
    });
  }

  void _onWishlistChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _ensureFavoriteState(Product product) {
    if (_syncedFavoriteProductId == product.id) return;
    _syncedFavoriteProductId = product.id;
    _syncFavoriteState(product);
  }

  String? _normalizeUserId(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  Future<void> _toggleFavorite(Product product) async {
    try {
      final isAdding = await wishlistService.toggle(product.id);

      if (!mounted) return;
      setState(() {
        _isFavorite = wishlistService.isFavorite(product.id);
      });

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

  Future<void> _addToCart(Product product) async {
    if (product.status.toLowerCase() == 'sold') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This product is out of stock')),
      );
      return;
    }

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login first')),
        );
        return;
      }

      final cartSellerRows = await supabase
          .from('cart_items')
          .select('products!inner(seller_id)')
          .eq('user_id', user.id)
          .limit(1);

      if (cartSellerRows.isNotEmpty) {
        final existingSellerId =
            ((cartSellerRows.first['products'] as Map?)?['seller_id'])
                ?.toString();
        final newSellerId = product.sellerId?.toString();

        if (existingSellerId != null &&
            existingSellerId.isNotEmpty &&
            newSellerId != null &&
            newSellerId.isNotEmpty &&
            existingSellerId != newSellerId) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'You can only buy from one seller at a time. Finish or clear the current cart first.',
              ),
            ),
          );
          return;
        }
      }

      final existing = await supabase
          .from('cart_items')
          .select('id, quantity')
          .eq('user_id', user.id)
          .eq('product_id', product.id)
          .maybeSingle();

      if (existing != null) {
        final currentQty = existing['quantity'] as int? ?? 1;

        await supabase
            .from('cart_items')
            .update({'quantity': currentQty + 1})
            .eq('id', existing['id']);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cart quantity updated')),
        );
      } else {
        await supabase.from('cart_items').insert({
          'user_id': user.id,
          'product_id': product.id,
          'quantity': 1,
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to cart')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add to cart failed')),
      );
    }
  }

  Future<void> _makeOffer(Product product) async {
    if (_isSubmittingOffer) return;

    if (product.status.toLowerCase() == 'sold') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This product is already sold')),
      );
      return;
    }

    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first')),
      );
      return;
    }

    final sellerId = _normalizeUserId(product.sellerId);
    final buyerId = _normalizeUserId(user.id);

    if (sellerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seller not available for this product')),
      );
      return;
    }

    if (buyerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login again and try once more')),
      );
      return;
    }

    if (sellerId == buyerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot make an offer on your own product')),
      );
      return;
    }

    final priceController = TextEditingController(
      text: product.price.toStringAsFixed(0),
    );

    final offerPrice = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Make Offer'),
          content: TextField(
            controller: priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Offer Price',
              hintText: 'Enter your offer',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final parsed = double.tryParse(priceController.text.trim());
                Navigator.pop(dialogContext, parsed);
              },
              child: const Text('Send Offer'),
            ),
          ],
        );
      },
    );

    priceController.dispose();

    if (!mounted) return;

    if (offerPrice == null || offerPrice <= 0) {
      return;
    }

    try {
      setState(() {
        _isSubmittingOffer = true;
      });

      final existingOffer = await supabase
          .from('offers')
          .select('id, status')
          .eq('product_id', product.id)
          .eq('buyer_id', buyerId)
          .eq('seller_id', sellerId)
          .eq('status', 'pending')
          .limit(1)
          .maybeSingle();

      if (existingOffer != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You already sent an offer for this product'),
          ),
        );
        return;
      }

      await supabase.from('offers').insert({
        'product_id': product.id,
        'buyer_id': buyerId,
        'seller_id': sellerId,
        'offer_price': offerPrice,
        'status': 'pending',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offer sent successfully')),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      final message = e.message.isNotEmpty ? e.message : 'Database rejected the offer';
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send offer: $message')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send offer: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingOffer = false;
        });
      }
    }
  }

  Future<void> _messageSeller(Product product) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first')),
      );
      return;
    }

    if (product.sellerId == null || product.sellerId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seller not available for this product')),
      );
      return;
    }

    if (product.sellerId == user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot message yourself')),
      );
      return;
    }

    try {
      final existingConversation = await supabase
          .from('conversations')
          .select('id')
          .eq('buyer_id', user.id)
          .eq('seller_id', product.sellerId!)
          .maybeSingle();

      int conversationId;
      if (existingConversation != null) {
        conversationId = existingConversation['id'] as int;
      } else {
        final insertedConversation = await supabase
            .from('conversations')
            .insert({
              'buyer_id': user.id,
              'seller_id': product.sellerId,
            })
            .select('id')
            .single();
        conversationId = insertedConversation['id'] as int;
      }

      String sellerName = 'Seller';
      final sellerProfile = await supabase
          .from('profiles')
          .select('full_name, email')
          .eq('id', product.sellerId!)
          .maybeSingle();
      if (sellerProfile != null) {
        final fullName = (sellerProfile['full_name'] ?? '').toString().trim();
        final email = (sellerProfile['email'] ?? '').toString().trim();
        sellerName = fullName.isNotEmpty ? fullName : (email.isNotEmpty ? email : sellerName);
      }
      ChatIdentityCache.instance.remember(
        userId: product.sellerId!,
        name: sellerName,
      );

      if (!mounted) return;
      await Navigator.pushNamed(
        context,
        '/chat',
        arguments: {
          'conversationId': conversationId,
          'otherUserId': product.sellerId,
          'otherUserName': sellerName,
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open chat: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;
    final textColor = AppThemeColors.textPrimary(context);
    final secondaryText = AppThemeColors.textSecondary(context);
    final isDark = AppThemeColors.isDark(context);

    if (product == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Text(
            'Product not available',
            style: GoogleFonts.inter(
              color: secondaryText,
            ),
          ),
        ),
      );
    }

    final isSold = product.status.toLowerCase() == 'sold';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 420,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppThemeColors.surface(context),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(60),
                      bottomRight: Radius.circular(60),
                    ),
                  ),
                  child: Hero(
                    tag: product.tag,
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: product.image != null && product.image!.isNotEmpty
                          ? Image.network(
                              product.image!,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Icon(
                                    Icons.image_not_supported,
                                    size: 70,
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            )
                          : const Center(
                              child: Icon(
                                Icons.image,
                                size: 70,
                                color: Colors.grey,
                              ),
                            ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 25,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              product.title,
                              style: GoogleFonts.poppins(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _formatPrice(product.price),
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              color: primaryRed,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 20),
                          const Icon(Icons.star, color: Colors.amber, size: 20),
                          const Icon(Icons.star, color: Colors.amber, size: 20),
                          const Icon(Icons.star, color: Colors.amber, size: 20),
                          const Icon(Icons.star_half, color: Colors.amber, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "(150 Reviews)",
                            style: GoogleFonts.inter(color: secondaryText),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _infoChip(
                            icon: Icons.verified_outlined,
                            label: product.condition.toUpperCase(),
                          ),
                          _infoChip(
                            icon: Icons.sell_outlined,
                            label: product.status.toUpperCase(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),
                      Text(
                        "Description",
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        product.description.isNotEmpty
                            ? product.description
                            : "No description available.",
                        style: GoogleFonts.inter(
                          color: secondaryText,
                          height: 1.6,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _messageSeller(product),
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Message Seller'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: isSold || _isSubmittingOffer
                              ? null
                              : () => _makeOffer(product),
                          icon: const Icon(Icons.local_offer_outlined),
                          label: Text(
                            isSold
                                ? 'Out of Stock'
                                : (_isSubmittingOffer
                                      ? 'Sending Offer...'
                                      : 'Make Offer'),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _circularAction(Icons.arrow_back, () => Navigator.pop(context)),
                _circularAction(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  () => _toggleFavorite(product),
                  iconColor: _isFavorite ? primaryRed : textColor,
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              height: 80,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1B1D24) : Colors.black,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Estimated Delivery",
                        style: GoogleFonts.inter(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      const Text(
                        "24-48 Hours",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: isSold ? null : () => _addToCart(product),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSold ? Colors.grey : primaryRed,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: Text(
                      isSold ? "Out of Stock" : "Add to Cart",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
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

  Widget _circularAction(
    IconData icon,
    VoidCallback onTap, {
    Color iconColor = Colors.black,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppThemeColors.elevatedSurface(context).withValues(alpha: 0.92),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
    );
  }

  Widget _infoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppThemeColors.surface(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: primaryRed),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppThemeColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}
