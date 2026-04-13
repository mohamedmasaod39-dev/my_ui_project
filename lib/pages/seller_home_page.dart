import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/app_mode_service.dart';

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
  int _pendingOffers = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
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

      final offersResponse = await supabase
          .from('offers')
          .select('id')
          .eq('seller_id', user.id)
          .eq('status', 'pending');

      final products = (productsResponse as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      if (!mounted) return;
      setState(() {
        _productCount = products.length;
        _activeCount = products.where((item) => item['status'] == 'active').length;
        _pendingOffers = (offersResponse as List).length;
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
          'Seller Dashboard',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              AppModeService.instance.setMode(AppMode.buyer);
              Navigator.pushReplacementNamed(context, '/home');
            },
            child: Text(
              'Buy Mode',
              style: GoogleFonts.inter(
                color: primaryRed,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.black,
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
                          'Add products, review received offers, and stay in touch with buyers.',
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
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Offers',
                          value: '$_pendingOffers',
                          highlight: true,
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
                    title: 'Received Offers',
                    subtitle: 'Accept or reject buyer offers on your products.',
                    icon: Icons.local_offer_outlined,
                    onTap: () => _openPage('/seller_offers'),
                  ),
                  _ActionTile(
                    title: 'Messages',
                    subtitle: 'Open your product conversations with buyers.',
                    icon: Icons.chat_bubble_outline,
                    onTap: () => _openPage('/conversations'),
                  ),
                  _ActionTile(
                    title: 'Profile',
                    subtitle: 'Update your profile information and account settings.',
                    icon: Icons.person_outline,
                    onTap: () => _openPage('/profile'),
                  ),
                ],
              ),
      ),
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFDB4444) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: highlight ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              color: highlight ? Colors.white70 : Colors.black54,
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
          child: Icon(icon, color: const Color(0xFFDB4444)),
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
