import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_ui_project/theme/app_theme_colors.dart';

import '../services/app_mode_service.dart';

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key});

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  static const Color primaryRed = Color(0xFFDB4444);

  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isSavingRole = false;

  Future<void> _selectMode(BuildContext context, AppMode mode) async {
    if (_isSavingRole) return;

    if (mode == AppMode.seller) {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in first.')),
        );
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      setState(() {
        _isSavingRole = true;
      });

      try {
        await _supabase.from('profiles').update({'role': 'seller'}).eq('id', user.id);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to switch to seller mode: $e')),
        );
        setState(() {
          _isSavingRole = false;
        });
        return;
      }
    }

    AppModeService.instance.setMode(mode);
    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      mode == AppMode.buyer ? '/home' : '/seller_home',
    );
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
          'Choose Your Mode',
          style: GoogleFonts.poppins(
            color: textColor,
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
                color: textColor.withValues(alpha: 0.9),
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
              subtitle: 'Add products, manage listings, and review offers.',
              icon: Icons.storefront_outlined,
              accentColor: Colors.black,
              onTap: () => _selectMode(context, AppMode.seller),
            ),
            if (_isSavingRole) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
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
    final textColor = AppThemeColors.textPrimary(context);

    return Material(
      color: Theme.of(context).cardColor,
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
                  color: textColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: AppThemeColors.textSecondary(context),
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
