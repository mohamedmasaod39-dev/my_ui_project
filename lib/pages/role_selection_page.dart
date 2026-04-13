import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/app_mode_service.dart';

class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({super.key});

  static const Color primaryRed = Color(0xFFDB4444);

  void _selectMode(BuildContext context, AppMode mode) {
    AppModeService.instance.setMode(mode);
    Navigator.pushReplacementNamed(
      context,
      mode == AppMode.buyer ? '/home' : '/seller_home',
    );
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
          'Choose Your Mode',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Text(
              'How would you like to use Listables today?',
              style: GoogleFonts.inter(
                fontSize: 17,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            _RoleCard(
              title: 'Buy Products',
              subtitle: 'Browse items, add to cart, checkout, and manage orders.',
              icon: Icons.shopping_bag_outlined,
              accentColor: primaryRed,
              onTap: () => _selectMode(context, AppMode.buyer),
            ),
            const SizedBox(height: 18),
            _RoleCard(
              title: 'Sell Products',
              subtitle: 'Add products, manage listings, review offers, and chat.',
              icon: Icons.storefront_outlined,
              accentColor: Colors.black,
              onTap: () => _selectMode(context, AppMode.seller),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: accentColor.withValues(alpha: 0.12),
                child: Icon(icon, color: accentColor, size: 30),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: Colors.black54,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text(
                    'Continue',
                    style: GoogleFonts.inter(
                      color: accentColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward, color: accentColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
