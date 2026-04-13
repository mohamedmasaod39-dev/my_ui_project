import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_ui_project/theme/app_theme_colors.dart';

import '../services/app_mode_service.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  static const Color primaryRed = Color(0xFFDB4444);

  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final supabase = Supabase.instance.client;

  bool _isSaving = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _navigateForCurrentUser() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      return;
    }

    final profile = await supabase
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();
    final role = (profile?['role'] ?? 'buyer').toString();

    if (!mounted) return;
    if (role == 'admin') {
      Navigator.pushNamedAndRemoveUntil(context, '/admin', (_) => false);
    } else if (role == 'seller') {
      AppModeService.instance.setMode(AppMode.seller);
      Navigator.pushNamedAndRemoveUntil(context, '/seller_home', (_) => false);
    } else {
      AppModeService.instance.setMode(AppMode.buyer);
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    }
  }

  Future<void> _updatePassword() async {
    if (_isSaving) return;

    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters.'),
        ),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await supabase.auth.updateUser(UserAttributes(password: password));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully.')),
      );
      await _navigateForCurrentUser();
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update password: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Reset Password',
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your new password to continue.',
              style: GoogleFonts.inter(
                color: AppThemeColors.textSecondary(context),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 28),
            _buildPasswordField(
              controller: _passwordController,
              label: 'New Password',
              isVisible: _showPassword,
              onToggle: () {
                setState(() {
                  _showPassword = !_showPassword;
                });
              },
            ),
            const SizedBox(height: 18),
            _buildPasswordField(
              controller: _confirmPasswordController,
              label: 'Confirm Password',
              isVisible: _showConfirmPassword,
              onToggle: () {
                setState(() {
                  _showConfirmPassword = !_showConfirmPassword;
                });
              },
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _updatePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'SAVE NEW PASSWORD',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isVisible,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: !isVisible,
      style: GoogleFonts.inter(color: AppThemeColors.textPrimary(context)),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppThemeColors.surface(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            isVisible ? Icons.visibility : Icons.visibility_off,
            color: AppThemeColors.textSecondary(context),
          ),
        ),
      ),
    );
  }
}
