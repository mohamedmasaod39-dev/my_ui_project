import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_ui_project/theme/app_theme_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SellerHomePage extends StatefulWidget {
  const SellerHomePage({super.key});

  @override
  State<SellerHomePage> createState() => _SellerHomePageState();
}

class _SellerHomePageState extends State<SellerHomePage> {
  static const Color primaryRed = Color(0xFFDB4444);

  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  int _productCount = 0;
  int _activeCount = 0;
  int _unreadNotifications = 0;
  int _unreadMessages = 0;
  RealtimeChannel? _notificationsChannel;
  RealtimeChannel? _messagesChannel;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _setupNotifications();
  }

  @override
  void dispose() {
    _notificationsChannel?.unsubscribe();
    _messagesChannel?.unsubscribe();
    super.dispose();
  }

  void _setupNotifications() {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    _loadUnreadCount();
    _loadUnreadMessagesCount();

    _notificationsChannel = supabase
        .channel('public:notifications:seller')
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
        .channel('public:messages:seller')
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
      if (mounted) {
        setState(() {
          _unreadMessages = (res as List).length;
        });
      }
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
      if (mounted) {
        setState(() {
          _unreadNotifications = (res as List).length;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadStats() async {
    // ... (rest of the method remains the same)
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final productsResponse = await supabase
          .from('products')
          .select('id, status')
          .eq('seller_id', user.id);

      final products = (productsResponse as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      if (!mounted) return;
      setState(() {
        _productCount = products.length;
        _activeCount = products
            .where((item) => item['status'] == 'active')
            .length;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _openPage(String routeName) async {
    await Navigator.pushNamed(context, routeName);
    await _loadStats();
    await _loadUnreadCount();
    await _loadUnreadMessagesCount();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppThemeColors.textPrimary(context);
    final isDark = AppThemeColors.isDark(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          'Seller Dashboard',
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _unreadNotifications > 0,
              label: Text('$_unreadNotifications'),
              backgroundColor: primaryRed,
              child: Icon(Icons.notifications_outlined, color: textColor),
            ),
            onPressed: () => _openPage('/notifications'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      extendBody: true,
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1B1D24) : Colors.black,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manage your store',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add products and stay in touch with buyers.',
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Products',
                          value: '$_productCount',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Active',
                          value: '$_activeCount',
                          highlight: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _ActionTile(
                    title: 'Add Product',
                    subtitle: 'Create a new listing and save it to your store.',
                    icon: Icons.add_business_outlined,
                    onTap: () => _openPage('/add_product'),
                  ),
                  _ActionTile(
                    title: 'My Products',
                    subtitle: 'Edit, hide, show, or delete your listings.',
                    icon: Icons.store_mall_directory_outlined,
                    onTap: () => _openPage('/my_products'),
                  ),
                  _ActionTile(
                    title: 'Seller Orders',
                    subtitle: 'See purchases that include your products.',
                    icon: Icons.receipt_long_outlined,
                    onTap: () => _openPage('/seller_orders'),
                  ),
                  _ActionTile(
                    title: 'Profile',
                    subtitle:
                        'Update your profile information and account settings.',
                    icon: Icons.person_outline,
                    onTap: () => _openPage('/profile'),
                  ),
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
          _navIcon(Icons.dashboard_outlined, true),
          _navIconWithBadge(
            Icons.notifications_none,
            false,
            _unreadNotifications,
            () => _openPage('/notifications'),
          ),
          _navIconWithBadge(
            Icons.chat_bubble_outline,
            false,
            _unreadMessages,
            () => _openPage('/messages'),
          ),
          _navIcon(
            Icons.person_outline,
            false,
            onTap: () => _openPage('/profile'),
          ),
        ],
      ),
    );
  }

  Widget _navIcon(IconData icon, bool isActive, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        icon,
        color: isActive ? primaryRed : Colors.white60,
        size: 28,
      ),
    );
  }

  Widget _navIconWithBadge(
    IconData icon,
    bool isActive,
    int count,
    VoidCallback onTap,
  ) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      backgroundColor: primaryRed,
      child: _navIcon(icon, isActive, onTap: onTap),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final textColor = AppThemeColors.textPrimary(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: highlight
            ? const Color(0xFFDB4444)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: highlight ? Colors.white : textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              color: highlight
                  ? Colors.white70
                  : AppThemeColors.textSecondary(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = AppThemeColors.textPrimary(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: AppThemeColors.elevatedSurface(context),
          child: Icon(icon, color: const Color(0xFFDB4444)),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            subtitle,
            style: GoogleFonts.inter(
              color: AppThemeColors.textSecondary(context),
              height: 1.4,
            ),
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: AppThemeColors.textMuted(context),
        ),
        onTap: onTap,
      ),
    );
  }
}
