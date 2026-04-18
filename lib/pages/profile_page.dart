import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_ui_project/theme/app_theme_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/app_mode_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const Color primaryRed = Color(0xFFDB4444);

  final SupabaseClient supabase = Supabase.instance.client;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _obscurePassword = true;
  String _role = 'buyer';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(email);
  }

  Future<void> _loadUser() async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        if (!mounted) return;
        _showMessage('No logged in user found.');
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final data = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      _nameController.text = (data['full_name'] ?? '').toString();
      _emailController.text = (data['email'] ?? user.email ?? '').toString();
      _role = (data['role'] ?? 'buyer').toString();
    } catch (e) {
      _showMessage('Failed to load profile: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateProfile() async {
    if (_isSaving) return;

    final user = supabase.auth.currentUser;
    if (user == null) {
      _showMessage('You must be logged in first.');
      return;
    }

    final fullName = _nameController.text.trim();
    final newEmail = _emailController.text.trim().toLowerCase();
    final newPassword = _passwordController.text.trim();
    final currentEmail = (user.email ?? '').trim().toLowerCase();

    if (fullName.isEmpty || newEmail.isEmpty) {
      _showMessage('Name and email cannot be empty.');
      return;
    }

    if (!_isValidEmail(newEmail)) {
      _showMessage('Please enter a valid email.');
      return;
    }

    if (newPassword.isNotEmpty && newPassword.length < 6) {
      _showMessage('Password must be at least 6 characters.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Update email in auth only if it actually changed
      if (newEmail != currentEmail) {
        await supabase.auth.updateUser(
          UserAttributes(email: newEmail),
        );
      }

      // Update password only if user typed one
      if (newPassword.isNotEmpty) {
        await supabase.auth.updateUser(
          UserAttributes(password: newPassword),
        );
      }

      // Update profile table
      await supabase.from('profiles').update({
        'full_name': fullName,
        'email': newEmail,
      }).eq('id', user.id);

      _passwordController.clear();

      if (!mounted) return;
      Navigator.pop(context);
      _showMessage('Profile updated successfully.');

      await _loadUser();
    } on AuthException catch (e) {
      _showMessage(e.message);
    } catch (e) {
      _showMessage('Update failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _logout() async {
    try {
      await supabase.auth.signOut();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      _showMessage('Logout failed: $e');
    }
  }

  void _showEditDialog() {
    _passwordController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Profile'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        hintText: 'Leave empty if unchanged',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isSaving ? null : _updateProfile,
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildProfileMenu(
    BuildContext context,
    String title,
    IconData icon,
    String? routeName,
  ) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.onSurface),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        onTap: () {
          if (routeName != null) {
            Navigator.pushNamed(context, routeName);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modeService = AppModeService.instance;
    final isSellerMode = modeService.isSeller;
    final isAdmin = _role == 'admin';
    final textColor = AppThemeColors.textPrimary(context);
    final displayedName =
        _nameController.text.isEmpty ? 'User' : _nameController.text;
    final displayedEmail =
        _emailController.text.isEmpty ? 'No email' : _emailController.text;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "My Profile",
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: primaryRed.withValues(alpha: 0.1),
                          child: const Icon(
                            Icons.person,
                            size: 80,
                            color: primaryRed,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: AppThemeColors.isDark(context)
                                ? const Color(0xFF1B1D24)
                                : Colors.black,
                            child: IconButton(
                              icon: const Icon(
                                Icons.edit,
                                size: 15,
                                color: Colors.white,
                              ),
                              onPressed: _showEditDialog,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    displayedName,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  Text(
                    displayedEmail,
                    style: GoogleFonts.inter(
                      color: AppThemeColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 40),

                  if (isAdmin)
                    _buildProfileMenu(
                      context,
                      "Admin Dashboard",
                      Icons.admin_panel_settings_outlined,
                      '/admin',
                    ),
                  if (!isAdmin && !isSellerMode)
                    Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: ListTile(
                        leading: Icon(
                          Icons.arrow_circle_right_outlined,
                          color: textColor,
                        ),
                        title: Text(
                          'Open Seller Mode',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w500,
                            color: textColor,
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: AppThemeColors.textSecondary(context),
                        ),
                        onTap: () {
                          modeService.setMode(AppMode.seller);
                          Navigator.pushReplacementNamed(context, '/seller_home');
                        },
                      ),
                    ),
                  if (!isAdmin && isSellerMode)
                    _buildProfileMenu(
                      context,
                      "Seller Dashboard",
                      Icons.storefront_outlined,
                      '/seller_home',
                    ),
                  if (!isAdmin && isSellerMode)
                    Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: ListTile(
                        leading: Icon(
                          Icons.shopping_bag_outlined,
                          color: textColor,
                        ),
                        title: Text(
                          'Switch To Buyer',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w500,
                            color: textColor,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey,
                        ),
                        onTap: () {
                          modeService.setMode(AppMode.buyer);
                          Navigator.pushReplacementNamed(context, '/home');
                        },
                      ),
                    ),
                  if (!isAdmin)
                    _buildProfileMenu(
                      context,
                      "My Products",
                      Icons.storefront_outlined,
                      '/my_products',
                    ),
                  if (!isAdmin)
                    _buildProfileMenu(
                      context,
                      "Sell Product",
                      Icons.add_business_outlined,
                      '/add_product',
                    ),
                  if (!isAdmin)
                    _buildProfileMenu(
                      context,
                      "My Orders",
                      Icons.shopping_bag_outlined,
                      '/orders',
                    ),
                  if (!isAdmin)
                    _buildProfileMenu(
                      context,
                      "Offers",
                      Icons.local_offer_outlined,
                      isSellerMode ? '/seller_offers' : '/offers',
                    ),
                  if (!isAdmin && isSellerMode)
                    _buildProfileMenu(
                      context,
                      "Seller Orders",
                      Icons.receipt_long_outlined,
                      '/seller_orders',
                    ),
                  if (!isAdmin)
                    _buildProfileMenu(
                      context,
                      "Wishlist",
                      Icons.favorite_border,
                      '/wishlist',
                    ),
                  if (!isAdmin)
                    _buildProfileMenu(
                      context,
                      "Messages",
                      Icons.chat_bubble_outline,
                      '/messages',
                    ),
                  _buildProfileMenu(
                    context,
                    "Notifications",
                    Icons.notifications_none,
                    '/notifications',
                  ),

                  const Divider(height: 40),

                  _buildProfileMenu(
                    context,
                    "FAQ & Help",
                    Icons.help_outline,
                    '/faq',
                  ),
                  _buildProfileMenu(
                    context,
                    "About Listables",
                    Icons.info_outline,
                    '/about',
                  ),
                  _buildProfileMenu(
                    context,
                    "App Settings",
                    Icons.settings_outlined,
                    '/app_settings',
                  ),

                  const SizedBox(height: 20),
                  ListTile(
                    onTap: _logout,
                    leading: const Icon(Icons.logout, color: primaryRed),
                    title: Text(
                      "Logout",
                      style: GoogleFonts.inter(
                        color: primaryRed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
