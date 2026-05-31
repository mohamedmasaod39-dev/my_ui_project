import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_ui_project/services/chat_identity_cache.dart';
import 'package:my_ui_project/services/wishlist_service.dart';
import 'package:my_ui_project/services/app_scaffold_messenger.dart';
import 'package:my_ui_project/services/app_mode_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  Product? _product;
  String _userRole = 'buyer';
  final _wishlistService = WishlistService.instance;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _wishlistService.favoriteIds.addListener(_onWishlistChanged);
  }

  Future<String> _loadCurrentUserRole(String userId) async {
    try {
      final profile = await supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      final role = (profile?['role'] ?? '').toString().trim().toLowerCase();
      return role.isEmpty ? 'buyer' : role;
    } catch (_) {
      return AppModeService.instance.isSeller ? 'seller' : 'buyer';
    }
  }

  Future<void> _loadUserRole() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final role = await _loadCurrentUserRole(user.id);
      if (role == 'seller') {
        AppModeService.instance.setMode(AppMode.seller);
      } else if (role == 'buyer') {
        AppModeService.instance.setMode(AppMode.buyer);
      }
      if (mounted) {
        setState(() {
          _userRole = role;
        });
      }
    } catch (_) {}
  }

  void _onWishlistChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _toggleWishlist() async {
    final product = _product;
    if (product == null) return;
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final role = await _loadCurrentUserRole(user.id);
        if (role == 'seller') {
          if (!mounted) return;
          setState(() => _userRole = role);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Seller accounts cannot save shopping items'),
            ),
          );
          return;
        }
      }
      await _wishlistService.toggle(product.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  void dispose() {
    _wishlistService.favoriteIds.removeListener(_onWishlistChanged);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final routeProduct = ModalRoute.of(context)?.settings.arguments as Product?;
    if (routeProduct == null) return;
    if (_product?.id == routeProduct.id) return;

    _product = routeProduct;
  }

  String _formatPrice(double price) {
    final product = _product;
    final currency = product?.currency ?? 'EGP';
    return '$currency ${price.toStringAsFixed(0)}';
  }

  bool _isGenericChatName(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.isEmpty ||
        normalized == 'chat' ||
        normalized == 'seller' ||
        normalized == 'buyer' ||
        normalized == 'admin' ||
        normalized == 'user' ||
        normalized == 'unknown seller' ||
        normalized == 'unknown buyer' ||
        normalized == 'unknown user';
  }

  String _profileDisplayName(Map<String, dynamic> profile) {
    final fullName = (profile['full_name'] ?? '').toString().trim();
    if (fullName.isNotEmpty) return fullName;

    final email = (profile['email'] ?? '').toString().trim();
    if (email.isEmpty) return '';

    final localPart = email.split('@').first.trim();
    return localPart.isNotEmpty ? localPart : email;
  }

  Future<void> _addToCart(Product product) async {
    final messenger = appScaffoldMessengerKey.currentState;

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        messenger?.showSnackBar(
          const SnackBar(content: Text('Please login first')),
        );
        return;
      }

      final role = await _loadCurrentUserRole(user.id);
      if (role == 'seller') {
        AppModeService.instance.setMode(AppMode.seller);
        if (mounted) {
          setState(() => _userRole = role);
        }
        messenger?.showSnackBar(
          const SnackBar(
            content: Text('Seller accounts cannot start shopping'),
          ),
        );
        return;
      }

      if (product.isOwnedBy(user.id)) {
        messenger?.showSnackBar(
          const SnackBar(content: Text('You cannot buy your own product')),
        );
        return;
      }

      final latestProductRow = await supabase
          .from('products')
          .select()
          .eq('id', product.id)
          .maybeSingle();
      if (latestProductRow == null) {
        messenger?.showSnackBar(
          const SnackBar(content: Text('This product is no longer available')),
        );
        return;
      }

      final latestProduct = Product.fromMap(
        Map<String, dynamic>.from(latestProductRow),
      );
      if (!latestProduct.isBuyable) {
        if (mounted) {
          setState(() {
            _product = latestProduct;
          });
        }
        messenger?.showSnackBar(
          const SnackBar(content: Text('This product is sold')),
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
          messenger?.showSnackBar(
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
        if (currentQty >= latestProduct.stockQty) {
          messenger?.showSnackBar(
            const SnackBar(content: Text('No more stock available')),
          );
          return;
        }

        await supabase
            .from('cart_items')
            .update({'quantity': currentQty + 1})
            .eq('id', existing['id']);

        if (!mounted) return;
        messenger?.showSnackBar(
          const SnackBar(content: Text('Cart quantity updated')),
        );
      } else {
        await supabase.from('cart_items').insert({
          'user_id': user.id,
          'product_id': product.id,
          'quantity': 1,
        });

        if (!mounted) return;
        messenger?.showSnackBar(const SnackBar(content: Text('Added to cart')));
      }
    } catch (e) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Add to cart failed')),
      );
    }
  }

  Future<void> _messageSeller(Product product) async {
    final messenger = appScaffoldMessengerKey.currentState;

    final user = supabase.auth.currentUser;
    if (user == null) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Please login first')),
      );
      return;
    }

    if (product.sellerId == null || product.sellerId!.isEmpty) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Seller not available for this product')),
      );
      return;
    }

    if (product.sellerId == user.id) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('You cannot message yourself')),
      );
      return;
    }

    try {
      String buyerName = 'Buyer';
      final buyerProfile = await supabase
          .from('profiles')
          .select('full_name, email')
          .eq('id', user.id)
          .maybeSingle();
      if (buyerProfile != null) {
        final displayName = _profileDisplayName(
          Map<String, dynamic>.from(buyerProfile),
        );
        if (displayName.isNotEmpty) {
          buyerName = displayName;
        }
      }

      final existingConversation = await supabase
          .from('conversations')
          .select('id, buyer_name, seller_name')
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
              'buyer_name': buyerName,
            })
            .select('id')
            .single();
        conversationId = insertedConversation['id'] as int;

        // Notify seller about new conversation
        try {
          await supabase.from('notifications').insert({
            'user_id': product.sellerId!,
            'sender_id': user.id,
            'title': 'New Message',
            'body':
                '$buyerName started a conversation with you regarding ${product.title}',
            'type': 'message',
          });
        } catch (_) {}
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
        final emailName = email.isEmpty ? '' : email.split('@').first.trim();
        sellerName = fullName.isNotEmpty
            ? fullName
            : (emailName.isNotEmpty ? emailName : sellerName);
      }
      if (!_isGenericChatName(sellerName)) {
        await ChatIdentityCache.instance.remember(
          userId: product.sellerId!,
          name: sellerName,
        );
      }
      if (!_isGenericChatName(buyerName)) {
        await ChatIdentityCache.instance.remember(
          userId: user.id,
          name: buyerName,
        );
      }

      if (existingConversation != null) {
        final updates = <String, String>{};
        final storedBuyerName = (existingConversation['buyer_name'] ?? '')
            .toString()
            .trim();
        final storedSellerName = (existingConversation['seller_name'] ?? '')
            .toString()
            .trim();

        if (!_isGenericChatName(buyerName) && buyerName != storedBuyerName) {
          updates['buyer_name'] = buyerName;
        }
        if (!_isGenericChatName(sellerName) && sellerName != storedSellerName) {
          updates['seller_name'] = sellerName;
        }

        if (updates.isNotEmpty) {
          await supabase
              .from('conversations')
              .update(updates)
              .eq('id', conversationId);
        }
      }

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
      messenger?.showSnackBar(
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
            style: GoogleFonts.inter(color: secondaryText),
          ),
        ),
      );
    }

    final isSold = !product.isBuyable;
    final isOwnProduct = product.isOwnedBy(supabase.auth.currentUser?.id);
    final isAdmin = _userRole == 'admin';
    final isSeller = _userRole == 'seller';
    final canUseBuyerActions = !isAdmin && !isSeller;

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
                          const Icon(
                            Icons.star_half,
                            color: Colors.amber,
                            size: 20,
                          ),
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
                            icon: Icons.sell_outlined,
                            label: product.isBuyable
                                ? product.status.toUpperCase()
                                : product.availabilityLabel.toUpperCase(),
                          ),
                          _infoChip(
                            icon: Icons.inventory_2_outlined,
                            label: product.stockQty > 0
                                ? 'STOCK ${product.stockQty}'
                                : 'SOLD',
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
                      if (product.listingDetails.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        Text(
                          "Product Details",
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: product.listingDetails.entries
                              .where(
                                (entry) =>
                                    entry.value.toString().trim().isNotEmpty,
                              )
                              .map(
                                (entry) => _detailChip(
                                  entry.key,
                                  entry.value.toString(),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      if (canUseBuyerActions) ...[
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed:
                                product.sellerId == null ||
                                    product.sellerId!.trim().isEmpty
                                ? null
                                : () => Navigator.pushNamed(
                                    context,
                                    '/public_seller_profile',
                                    arguments: product.sellerId,
                                  ),
                            icon: const Icon(Icons.storefront_outlined),
                            label: const Text('View Seller Profile'),
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
                            onPressed: isOwnProduct
                                ? null
                                : () => _messageSeller(product),
                            icon: const Icon(Icons.chat_bubble_outline),
                            label: Text(
                              isOwnProduct ? 'Your Product' : 'Message Seller',
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
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
                if (canUseBuyerActions)
                  _circularAction(
                    _wishlistService.isFavorite(product.id)
                        ? Icons.favorite
                        : Icons.favorite_border,
                    _toggleWishlist,
                    iconColor: _wishlistService.isFavorite(product.id)
                        ? primaryRed
                        : textColor,
                  ),
              ],
            ),
          ),
          if (canUseBuyerActions)
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
                      onPressed: isSold || isOwnProduct
                          ? null
                          : () => _addToCart(product),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSold || isOwnProduct
                            ? Colors.grey
                            : primaryRed,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: Text(
                        isOwnProduct
                            ? "Your Product"
                            : isSold
                            ? product.availabilityLabel
                            : "Add to Cart",
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
          color: AppThemeColors.elevatedSurface(
            context,
          ).withValues(alpha: 0.92),
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

  Widget _detailChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppThemeColors.surface(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '$label: $value',
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: AppThemeColors.textPrimary(context),
        ),
      ),
    );
  }
}
