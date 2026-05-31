import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_ui_project/services/chat_identity_cache.dart';
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
  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _avatarUrlController = TextEditingController();

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
    _shopNameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    _avatarUrlController.dispose();

    super.dispose();
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(email);
  }

  String _profileDisplayName({
    required String fullName,
    required String email,
  }) {
    final trimmedFullName = fullName.trim();
    if (trimmedFullName.isNotEmpty) return trimmedFullName;

    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty) return '';

    final localPart = trimmedEmail.split('@').first.trim();
    return localPart.isNotEmpty ? localPart : trimmedEmail;
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
      _shopNameController.text = (data['shop_name'] ?? '').toString();
      _bioController.text = (data['bio'] ?? '').toString();
      _locationController.text = (data['location'] ?? '').toString();
      _phoneController.text = (data['phone'] ?? '').toString();
      _avatarUrlController.text = (data['avatar_url'] ?? '').toString();
      _role = (data['role'] ?? 'buyer').toString();
      if (_role == 'seller') {
        AppModeService.instance.setMode(AppMode.seller);
      } else if (_role == 'buyer') {
        AppModeService.instance.setMode(AppMode.buyer);
      }

      final displayName = _profileDisplayName(
        fullName: _nameController.text,
        email: _emailController.text,
      );
      if (displayName.isNotEmpty) {
        await ChatIdentityCache.instance.remember(
          userId: user.id,
          name: displayName,
        );
      }
    } catch (e) {
      _showMessage('Failed to load profile: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateProfile(String updatedRole) async {
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
        await supabase.auth.updateUser(UserAttributes(email: newEmail));
      }

      // Update password only if user typed one
      if (newPassword.isNotEmpty) {
        await supabase.auth.updateUser(UserAttributes(password: newPassword));
      }

      // Update profile table
      await supabase
          .from('profiles')
          .update({
            'full_name': fullName,
            'email': newEmail,
            'role': updatedRole,
            'shop_name': _shopNameController.text.trim(),
            'bio': _bioController.text.trim(),
            'location': _locationController.text.trim(),
            'phone': _phoneController.text.trim(),
            'avatar_url': _avatarUrlController.text.trim(),
          })
          .eq('id', user.id);

      final displayName = _profileDisplayName(
        fullName: fullName,
        email: newEmail,
      );
      if (displayName.isNotEmpty) {
        await ChatIdentityCache.instance.remember(
          userId: user.id,
          name: displayName,
        );
      }

      _role = updatedRole;
      if (updatedRole == 'seller') {
        AppModeService.instance.setMode(AppMode.seller);
      } else if (updatedRole == 'buyer') {
        AppModeService.instance.setMode(AppMode.buyer);
      }

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
                      decoration: const InputDecoration(labelText: 'Full Name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
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
                    if (_role == 'seller') ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(),
                      ),
                      Text(
                        'Shop Setup',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: primaryRed,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _shopNameController,
                        decoration: const InputDecoration(
                          labelText: 'Shop Name',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _bioController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Shop Bio',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          labelText: 'Shop Location',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Shop Phone',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _avatarUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Shop Avatar URL',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isSaving ? null : () => _updateProfile(_role),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
    final isSellerAccount = isSellerMode || _role == 'seller';
    final textColor = AppThemeColors.textPrimary(context);
    final displayedName = _nameController.text.isEmpty
        ? 'User'
        : _nameController.text;
    final displayedEmail = _emailController.text.isEmpty
        ? 'No email'
        : _emailController.text;

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
                  // Account Type Indicator (Read-only, matches website)
                  Container(
                    margin: const EdgeInsets.only(bottom: 15),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _role == 'admin'
                              ? Icons.admin_panel_settings_outlined
                              : _role == 'seller'
                              ? Icons.storefront_outlined
                              : Icons.person_outline,
                          color: textColor,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Account Type',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w500,
                            color: textColor,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _role.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: primaryRed,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (!isAdmin && isSellerAccount)
                    _buildProfileMenu(
                      context,
                      "Seller Dashboard",
                      Icons.dashboard_customize_outlined,
                      '/seller_home',
                    ),
                  if (!isAdmin && isSellerMode)
                    _buildProfileMenu(
                      context,
                      "My Products",
                      Icons.storefront_outlined,
                      '/my_products',
                    ),
                  if (!isAdmin && isSellerMode)
                    _buildProfileMenu(
                      context,
                      "Sell Product",
                      Icons.add_business_outlined,
                      '/add_product',
                    ),
                  if (!isAdmin && !isSellerAccount)
                    _buildProfileMenu(
                      context,
                      "My Orders",
                      Icons.shopping_bag_outlined,
                      '/orders',
                    ),
                  if (!isAdmin && !isSellerAccount)
                    _buildProfileMenu(
                      context,
                      "My Wishlist",
                      Icons.favorite_border,
                      '/wishlist',
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
                  if (!isAdmin)
                    _buildProfileMenu(
                      context,
                      "Contact Support",
                      Icons.contact_support_outlined,
                      '/contact',
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
