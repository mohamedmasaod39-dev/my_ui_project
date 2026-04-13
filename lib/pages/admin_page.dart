import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  int _usersCount = 0;
  int _productsCount = 0;
  int _ordersCount = 0;
  @override
  void initState() {
    super.initState();
    _loadAdminStats();
  }

  Future<void> _loadAdminStats() async {
    try {
      final usersResponse = await supabase.from('profiles').select('id');
      final productsResponse = await supabase.from('products').select('id');
      final ordersResponse = await supabase.from('orders').select('id');
      if (!mounted) return;
      setState(() {
        _usersCount = (usersResponse as List).length;
        _productsCount = (productsResponse as List).length;
        _ordersCount = (ordersResponse as List).length;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          'Admin Dashboard',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.black),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAdminStats,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Control Panel',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Monitor users, products, orders, and support activity for your graduation project demo.',
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
                        child: _AdminStatCard(
                          title: 'Users',
                          value: '$_usersCount',
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
                          highlighted: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _AdminActionTile(
                    title: 'Open Buyer App',
                    subtitle: 'Review the shopping experience from the buyer side.',
                    icon: Icons.shopping_bag_outlined,
                    onTap: () => Navigator.pushNamed(context, '/home'),
                  ),
                  _AdminActionTile(
                    title: 'Open Seller Dashboard',
                    subtitle: 'Review products, offers, and seller orders.',
                    icon: Icons.storefront_outlined,
                    onTap: () => Navigator.pushNamed(context, '/seller_home'),
                  ),
                  _AdminActionTile(
                    title: 'View Notifications',
                    subtitle: 'Inspect user-facing notification screens.',
                    icon: Icons.notifications_none,
                    onTap: () => Navigator.pushNamed(context, '/notifications'),
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFDB4444) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: highlighted ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: GoogleFonts.inter(
              color: highlighted ? Colors.white70 : Colors.black54,
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
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.white,
          child: Icon(icon, color: _AdminPageState.primaryRed),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            subtitle,
            style: GoogleFonts.inter(color: Colors.black54, height: 1.4),
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
