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

  @override
  void initState() {
    super.initState();
    _loadAdminStats();
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
          .select('role, full_name')
          .eq('id', user.id)
          .maybeSingle();

      final role = (profile?['role'] ?? '').toString();
      if (role != 'admin') {
        _redirectUnauthorized('/home');
        return;
      }

      final usersResponse = await supabase.from('profiles').select('id, role');
      final productsResponse = await supabase.from('products').select('id');
      final ordersResponse = await supabase.from('orders').select('id');
      final users = (usersResponse as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      if (!mounted) return;
      setState(() {
        _usersCount = users.length;
        _buyersCount = users.where((item) => item['role'] == 'buyer').length;
        _sellersCount = users.where((item) => item['role'] == 'seller').length;
        _productsCount = (productsResponse as List).length;
        _ordersCount = (ordersResponse as List).length;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load admin dashboard.\n$e';
        _isLoading = false;
      });
    }
  }

  void _redirectUnauthorized(String routeName) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You are not allowed to open the admin dashboard.')),
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
    final secondaryText = AppThemeColors.textSecondary(context);

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
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: secondaryText,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: secondaryText,
                            height: 1.5,
                          ),
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
                )
          : RefreshIndicator(
              onRefresh: _loadAdminStats,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _AdminStatCard(
                          title: 'Users',
                          value: '$_usersCount',
                          highlighted: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _AdminStatCard(
                          title: 'Buyers',
                          value: '$_buyersCount',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _AdminStatCard(
                          title: 'Sellers',
                          value: '$_sellersCount',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _AdminStatCard(
                          title: 'Products',
                          value: '$_productsCount',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _AdminStatCard(
                          title: 'Orders',
                          value: '$_ordersCount',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _AdminActionTile(
                    title: 'All Orders',
                    subtitle: 'Review every order between buyers and sellers.',
                    icon: Icons.receipt_long_outlined,
                    onTap: () => Navigator.pushNamed(context, '/admin_orders'),
                  ),
                  _AdminActionTile(
                    title: 'Admin Profile',
                    subtitle: 'Open your profile without exposing seller-only actions.',
                    icon: Icons.manage_accounts_outlined,
                    onTap: () => Navigator.pushNamed(context, '/profile'),
                  ),
                  _AdminActionTile(
                    title: 'Notifications',
                    subtitle: 'Review user-facing notifications and announcements.',
                    icon: Icons.notifications_none,
                    onTap: () => Navigator.pushNamed(context, '/notifications'),
                  ),
                  _AdminActionTile(
                    title: 'FAQ & Help',
                    subtitle: 'Check support content that buyers and sellers will read.',
                    icon: Icons.help_outline,
                    onTap: () => Navigator.pushNamed(context, '/faq'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _AdminStatCard extends StatelessWidget {
  const _AdminStatCard({
    required this.title,
    required this.value,
    this.highlighted = false,
  });

  final String title;
  final String value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = highlighted
        ? const Color(0xFFDB4444)
        : AppThemeColors.surface(context);
    final valueColor = highlighted ? Colors.white : AppThemeColors.textPrimary(context);
    final labelColor = highlighted ? Colors.white70 : AppThemeColors.textSecondary(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: GoogleFonts.inter(
              color: labelColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminActionTile extends StatelessWidget {
  const _AdminActionTile({
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
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppThemeColors.surface(context),
        borderRadius: BorderRadius.circular(24),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: AppThemeColors.elevatedSurface(context),
          child: Icon(icon, color: _AdminPageState.primaryRed),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: AppThemeColors.textPrimary(context),
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
