import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_ui_project/services/wishlist_service.dart';
import 'package:my_ui_project/theme/app_theme_colors.dart';
import 'package:my_ui_project/utils/app_icon_mapper.dart';
import 'main.dart';

class Product {
  final int id;
  final int? categoryId;
  final String? sellerId;
  final String title;
  final double price;
  final String? image;
  final String tag;
  final String description;
  final String status;
  final String currency;
  final int stockQty;
  final String? slug;
  final bool validated;
  final Map<String, dynamic> listingDetails;

  const Product({
    required this.id,
    required this.categoryId,
    required this.sellerId,
    required this.title,
    required this.price,
    required this.image,
    required this.tag,
    required this.description,
    required this.status,
    required this.currency,
    required this.stockQty,
    required this.slug,
    required this.validated,
    required this.listingDetails,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    int? parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse('${value ?? ''}');
    }

    final rawId = map['id'];
    final rawPrice = map['price'];
    final rawPriceMinor = map['price_minor'];
    final rawStockQty = map['stock_qty'];
    final rawListingDetails = map['listing_details'] ?? map['details'];
    final isActive = map['active'];

    final listingDetails = rawListingDetails is Map
        ? Map<String, dynamic>.from(rawListingDetails)
        : <String, dynamic>{};

    String description = (map['description'] ?? '').toString();
    const detailSeparators = [
      '— Additional details —',
      '\u00e2\u20ac\u201d Additional details \u00e2\u20ac\u201d',
      '-- Additional details --',
    ];
    final detailSeparator = detailSeparators
        .where((separator) => description.contains(separator))
        .firstOrNull;
    if (detailSeparator != null) {
      final parts = description.split(detailSeparator);
      description = parts[0].trim();
      final extrasRaw = parts.length > 1 ? parts[1].trim() : '';
      for (final line in extrasRaw.split('\n')) {
        if (line.contains(':')) {
          final kv = line.split(':');
          final key = kv[0].trim();
          final value = kv.sublist(1).join(':').trim();
          if (key.isNotEmpty) {
            listingDetails[key] = value;
          }
        }
      }
    }

    // Determine effective price
    double price = 0.0;
    if (rawPrice != null && rawPrice is num) {
      price = rawPrice.toDouble();
    } else if (rawPriceMinor != null && rawPriceMinor is num) {
      price = rawPriceMinor.toDouble() / 100.0;
    }

    // Determine status from active bool if status is missing
    String status = (map['status'] ?? '').toString();
    if (status.isEmpty && isActive != null && isActive is bool) {
      status = isActive ? 'active' : 'hidden';
    }

    return Product(
      id: parseInt(rawId) ?? 0,
      categoryId: parseInt(map['category_id']),
      sellerId: map['seller_id']?.toString(),
      title: (map['title'] ?? map['name'] ?? '').toString(),
      price: price,
      image: (map['image'] ?? map['image_url'] ?? map['main_image_url'])
          ?.toString(),
      tag: (map['tag'] ?? 'product_${map['id'] ?? 0}').toString(),
      description: description,
      status: status,
      currency: (map['currency'] ?? 'EGP').toString(),
      stockQty: parseInt(rawStockQty) ?? 1,
      slug: map['slug']?.toString(),
      validated: map['validated'] is bool ? map['validated'] as bool : true,
      listingDetails: listingDetails,
    );
  }

  bool isOwnedBy(String? userId) {
    final ownerId = sellerId?.trim();
    final currentUserId = userId?.trim();
    return ownerId != null &&
        ownerId.isNotEmpty &&
        currentUserId != null &&
        currentUserId.isNotEmpty &&
        ownerId == currentUserId;
  }

  bool get isBuyable => status.toLowerCase() == 'active' && stockQty > 0;

  bool get isUnavailable => !isBuyable;

  String get availabilityLabel {
    if (stockQty <= 0) return 'Sold';
    if (status.toLowerCase() == 'sold') return 'Sold';
    return status.isEmpty ? 'Available' : status;
  }
}

class IndexPage extends StatefulWidget {
  const IndexPage({super.key});

  @override
  State<IndexPage> createState() => _IndexPageState();
}

class _IndexPageState extends State<IndexPage> with RouteAware {
  static const Color primaryRed = Color(0xFFDB4444);

  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _categories = [];
  int? _selectedCategoryId;
  String? _selectedSubcategory;

  int _selectedIndex = 0;
  bool _isLoading = true;
  bool _isRouteObserverSubscribed = false;
  List<Product> _products = [];
  int _unreadNotifications = 0;
  int _unreadMessages = 0;
  RealtimeChannel? _notificationsChannel;
  RealtimeChannel? _messagesChannel;
  final _wishlistService = WishlistService.instance;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _loadCategories();
    _setupNotifications();
    _wishlistService.load();
    _wishlistService.favoriteIds.addListener(_onWishlistChanged);
  }

  void _setupNotifications() {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    _loadUnreadCount();
    _loadUnreadMessagesCount();

    _notificationsChannel = supabase
        .channel('public:notifications:index')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          callback: (_) {
            if (mounted) _loadUnreadCount();
          },
        )
        .subscribe();

    _messagesChannel = supabase
        .channel('public:messages:index')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (_) {
            if (mounted) _loadUnreadMessagesCount();
          },
        )
        .subscribe();
  }

  Future<void> _loadUnreadMessagesCount() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final res = await supabase
          .from('messages')
          .select('id')
          .eq('receiver_id', user.id)
          .isFilter('read_at', null);
      if (!mounted) return;
      setState(() {
        _unreadMessages = (res as List).length;
      });
    } catch (_) {}
  }

  Future<void> _loadUnreadCount() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final res = await supabase
          .from('notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_read', false);
      if (!mounted) return;
      setState(() {
        _unreadNotifications = (res as List).length;
      });
    } catch (_) {}
  }

  Future<void> _toggleWishlist(int productId) async {
    try {
      await _wishlistService.toggle(productId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isRouteObserverSubscribed) return;
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
      _isRouteObserverSubscribed = true;
    }
  }

  void _onWishlistChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _wishlistService.favoriteIds.removeListener(_onWishlistChanged);
    if (_isRouteObserverSubscribed) {
      routeObserver.unsubscribe(this);
      _isRouteObserverSubscribed = false;
    }
    _notificationsChannel?.unsubscribe();
    _messagesChannel?.unsubscribe();
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadProducts();
    _loadUnreadCount();
    _loadUnreadMessagesCount();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // Include both 'active' AND 'sold' products so sold items remain visible
      // with a 'Sold' badge instead of disappearing from the homepage.
      var query = supabase
          .from('products')
          .select()
          .inFilter('status', ['active', 'sold'])
          .eq('validated', true);

      if (_selectedCategoryId != null) {
        query = query.eq('category_id', _selectedCategoryId!);
      }

      final response = await query.order('created_at', ascending: false);

      var loadedProducts = (response as List)
          .map((item) => Product.fromMap(item as Map<String, dynamic>))
          .toList();

      if (_selectedSubcategory != null) {
        loadedProducts = loadedProducts.where((p) {
          final subcat = p.listingDetails['subcategory']?.toString();
          return subcat != null &&
              subcat.toLowerCase() == _selectedSubcategory!.toLowerCase();
        }).toList();
      }

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
    // Hardcoded to match website categories
    final baselineCategories = [
      {'id': 1, 'name': 'Electronics', 'icon': 'devices'},
      {'id': 2, 'name': 'Gaming', 'icon': 'sports_esports'},
      {'id': 3, 'name': 'Home', 'icon': 'home'},
      {'id': 4, 'name': 'Fashion', 'icon': 'shopping_bag'},
      {'id': 5, 'name': 'Sports', 'icon': 'sports'},
      {'id': 6, 'name': 'Other', 'icon': 'more_horiz'},
    ];

    if (!mounted) return;
    setState(() {
      _categories = baselineCategories
          .map(
            (item) => {
              'id': item['id'],
              'label': item['name'].toString(),
              'icon': iconFromString(item['icon'].toString()),
            },
          )
          .toList();
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
        centerTitle: false,
        title: Text(
          'Listables',
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 26,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.favorite_border, color: textColor),
            onPressed: () => Navigator.pushNamed(context, '/wishlist'),
          ),
          IconButton(
            icon: Icon(Icons.search, color: textColor),
            onPressed: () => Navigator.pushNamed(context, '/search'),
          ),
          IconButton(
            icon: Icon(Icons.shopping_cart_outlined, color: textColor),
            onPressed: () => Navigator.pushNamed(context, '/cart'),
          ),
          const SizedBox(width: 10),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
              decoration: const BoxDecoration(color: primaryRed),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Explore',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Find what you love',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 10),
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.grid_view_rounded,
                      color: primaryRed,
                    ),
                    title: Text(
                      'All Categories',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    onTap: () {
                      setState(() {
                        _selectedCategoryId = null;
                        _selectedSubcategory = null;
                      });
                      _loadProducts();
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.favorite_outline,
                      color: primaryRed,
                    ),
                    title: Text(
                      'My Wishlist',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/wishlist');
                    },
                  ),
                  const Divider(indent: 20, endIndent: 20),
                  ..._categories.map((cat) {
                    final id = cat['id'] as int?;
                    final label = cat['label'] as String;
                    final icon = cat['icon'] as IconData;
                    // Fashion is shown as a plain item – no Men/Women/Kids subcategories

                    return ListTile(
                      leading: Icon(icon, color: primaryRed),
                      title: Text(
                        label,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedCategoryId = id;
                          _selectedSubcategory = null;
                        });
                        _loadProducts();
                        Navigator.pop(context);
                      },
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
      extendBody: true,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroBanner(),
            _buildSectionHeader('Categories', 'Browse by Category'),
            _buildCategoryList(),
            if (_selectedCategoryId != null) _buildSubcategoryFilters(),
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
    final isDark = AppThemeColors.isDark(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 25),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1D24) : Colors.black,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _navIcon(Icons.home_filled, 0),
          _navIconWithBadge(Icons.notifications_none, 2, _unreadNotifications),
          _navIconWithBadge(Icons.chat_bubble_outline, 3, _unreadMessages),
          _navIcon(Icons.person_outline, 4),
        ],
      ),
    );
  }

  Widget _navIcon(IconData icon, int index) {
    final isActive = _selectedIndex == index;
    return GestureDetector(
      onTap: () async {
        setState(() => _selectedIndex = index);
        if (index == 4) {
          Navigator.pushNamed(context, '/profile');
        } else if (index == 2) {
          // Clear locally first for instant feedback
          setState(() => _unreadNotifications = 0);
          await Navigator.pushNamed(context, '/notifications');
          // Mark all as read in DB
          try {
            final user = supabase.auth.currentUser;
            if (user != null) {
              await supabase
                  .from('notifications')
                  .update({'is_read': true})
                  .eq('user_id', user.id)
                  .eq('is_read', false);
            }
          } catch (_) {}
          _loadUnreadCount();
        } else if (index == 3) {
          // Clear locally for instant feedback
          setState(() => _unreadMessages = 0);
          await Navigator.pushNamed(context, '/messages');
          _loadUnreadMessagesCount();
        }
      },
      child: Icon(
        icon,
        color: isActive ? primaryRed : Colors.white60,
        size: 28,
      ),
    );
  }

  Widget _appBarCatItem(String label, int? categoryId) {
    final isSelected = _selectedCategoryId == categoryId;
    final textColor = AppThemeColors.textPrimary(context);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategoryId = categoryId;
          _selectedSubcategory = null;
        });
        _loadProducts();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? primaryRed : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryRed : textColor.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isSelected ? Colors.white : textColor,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _navIconWithBadge(IconData icon, int index, int count) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      backgroundColor: primaryRed,
      child: _navIcon(icon, index),
    );
  }

  Widget _buildHeroBanner() {
    final isDark = AppThemeColors.isDark(context);

    return Container(
      height: 180,
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1D24) : Colors.black,
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
    final textColor = AppThemeColors.textPrimary(context);

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
              color: textColor,
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
        itemCount: _categories.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _catItem(Icons.all_inclusive, 'All', null);
          }
          final category = _categories[index - 1];
          return _catItem(
            category['icon'] as IconData,
            category['label'] as String,
            category['id'] as int?,
          );
        },
      ),
    );
  }

  Widget _catItem(IconData icon, String label, int? categoryId) {
    final textColor = AppThemeColors.textPrimary(context);
    final isSelected = _selectedCategoryId == categoryId;

    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedCategoryId = categoryId;
            _selectedSubcategory = null;
          });
          _loadProducts();
        },
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryRed
                    : AppThemeColors.surface(context),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: isSelected ? Colors.white : textColor),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? primaryRed
                    : textColor.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Subcategory filters removed – Fashion shows all items together.
  Widget _buildSubcategoryFilters() => const SizedBox.shrink();

  Widget _subcatChip(String label, String? subcatValue) {
    final isSelected = _selectedSubcategory == subcatValue;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSubcategory = subcatValue;
        });
        _loadProducts();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryRed : AppThemeColors.surface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryRed : AppThemeColors.border(context),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isSelected
                ? Colors.white
                : AppThemeColors.textPrimary(context),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
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
                            ? Image.network(product.image!, fit: BoxFit.contain)
                            : const Icon(
                                Icons.image_not_supported,
                                color: Colors.grey,
                                size: 48,
                              ),
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
                Positioned(
                  top: 5,
                  right: 5,
                  child: IconButton(
                    icon: Icon(
                      _wishlistService.isFavorite(product.id)
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: _wishlistService.isFavorite(product.id)
                          ? primaryRed
                          : textColor.withValues(alpha: 0.5),
                      size: 20,
                    ),
                    onPressed: () => _toggleWishlist(product.id),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: GestureDetector(
              onTap: () =>
                  Navigator.pushNamed(context, '/details', arguments: product),
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
  }
}
