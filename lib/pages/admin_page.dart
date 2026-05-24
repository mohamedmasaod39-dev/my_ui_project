import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_ui_project/theme/app_theme_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  static const Color primaryRed = Color(0xFFDB4444);

  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _errorMessage;
  int _usersCount = 0;
  int _buyersCount = 0;
  int _sellersCount = 0;
  int _productsCount = 0;
  int _ordersCount = 0;
  int _unreadNotifications = 0;
  RealtimeChannel? _notificationsChannel;

  @override
  void initState() {
    super.initState();
    _loadAdminStats();
    _setupNotifications();
  }

  @override
  void dispose() {
    _notificationsChannel?.unsubscribe();
    super.dispose();
  }

  void _setupNotifications() {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    _loadUnreadCount();
    _notificationsChannel = supabase
        .channel('public:notifications:admin')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          callback: (_) {
            if (mounted) _loadUnreadCount();
          },
        )
        .subscribe();
  }

  Future<void> _loadUnreadCount() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final res = await supabase
          .from('notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_read', false)
          .count(CountOption.exact);
      if (mounted) {
        setState(() {
          _unreadNotifications = res.count;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadAdminStats() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final user = supabase.auth.currentUser;
      if (user == null) {
        _redirectUnauthorized('/login');
        return;
      }

      final profile = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null || profile['role'] != 'admin') {
        _redirectUnauthorized('/home');
        return;
      }

      final results = await Future.wait([
        supabase.from('profiles').select('id').count(CountOption.exact),
        supabase
            .from('profiles')
            .select('id')
            .eq('role', 'buyer')
            .count(CountOption.exact),
        supabase
            .from('profiles')
            .select('id')
            .eq('role', 'seller')
            .count(CountOption.exact),
        supabase.from('products').select('id').count(CountOption.exact),
        supabase.from('orders').select('id').count(CountOption.exact),
        supabase
            .from('notifications')
            .select('id')
            .eq('user_id', user.id)
            .eq('is_read', false)
            .count(CountOption.exact),
      ]);

      if (!mounted) return;

      setState(() {
        _usersCount = results[0].count;
        _buyersCount = results[1].count;
        _sellersCount = results[2].count;
        _productsCount = results[3].count;
        _ordersCount = results[4].count;
        _unreadNotifications = results[5].count;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load dashboard statistics';
        _isLoading = false;
      });
    }
  }

  void _redirectUnauthorized(String routeName) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You are not allowed to open the admin dashboard.'),
      ),
    );
    Navigator.pushNamedAndRemoveUntil(context, routeName, (_) => false);
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppThemeColors.textPrimary(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          'Admin Dashboard',
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: Icon(Icons.logout, color: textColor),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErrorView()
          : RefreshIndicator(
              onRefresh: _loadAdminStats,
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                children: [
                  // Grid section for top 4 stats
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.3,
                    children: [
                      _buildStatCard(
                        title: 'Users',
                        value: '$_usersCount',
                        onTap: () =>
                            Navigator.pushNamed(context, '/admin_users'),
                      ),
                      _buildStatCard(
                        title: 'Buyers',
                        value: '$_buyersCount',
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/admin_users',
                          arguments: {'role': 'buyer'},
                        ),
                      ),
                      _buildStatCard(
                        title: 'Sellers',
                        value: '$_sellersCount',
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/admin_users',
                          arguments: {'role': 'seller'},
                        ),
                      ),
                      _buildStatCard(
                        title: 'Products',
                        value: '$_productsCount',
                        onTap: () =>
                            Navigator.pushNamed(context, '/admin_products'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Large card for Orders
                  _buildStatCard(
                    title: 'Orders',
                    value: '$_ordersCount',
                    isWide: true,
                    onTap: () => Navigator.pushNamed(context, '/admin_orders'),
                  ),
                  const SizedBox(height: 32),

                  // Bottom list section
                  _buildMenuTile(
                    title: 'All Orders',
                    subtitle: 'Review every order between buyers and sellers.',
                    icon: Icons.receipt_long_outlined,
                    onTap: () => Navigator.pushNamed(context, '/admin_orders'),
                  ),
                  _buildMenuTile(
                    title: 'Admin Profile',
                    subtitle:
                        'Open your profile without exposing seller-only actions.',
                    icon: Icons.person_outline,
                    onTap: () => Navigator.pushNamed(context, '/profile'),
                  ),
                  _buildMenuTile(
                    title: 'Notifications',
                    subtitle:
                        'Review user-facing notifications and announcements.',
                    icon: Icons.notifications_none,
                    badgeCount: _unreadNotifications,
                    onTap: () => Navigator.pushNamed(context, '/notifications'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildErrorView() {
    final secondaryText = AppThemeColors.textSecondary(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: secondaryText),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: secondaryText, height: 1.5),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _loadAdminStats,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryRed,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required VoidCallback onTap,
    bool isWide = false,
  }) {
    final isDark = AppThemeColors.isDark(context);
    final cardColor = isDark ? const Color(0xFF1B1D24) : Colors.black87;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isWide ? double.infinity : null,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    final textColor = AppThemeColors.textPrimary(context);
    final secondaryText = AppThemeColors.textSecondary(context);
    final isDark = AppThemeColors.isDark(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B1D24) : const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white10
                      : Colors.black.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Badge(
                  isLabelVisible: badgeCount > 0,
                  label: Text('$badgeCount'),
                  backgroundColor: primaryRed,
                  child: Icon(
                    icon,
                    color: isDark ? Colors.white70 : Colors.black87,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: secondaryText, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
