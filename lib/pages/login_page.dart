import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_ui_project/services/chat_identity_cache.dart';
import 'package:my_ui_project/theme/app_theme_colors.dart';

import '../services/app_mode_service.dart';
import 'dart:async';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const Color primaryRed = Color(0xFFDB4444);

  bool _isPasswordVisible = false;
  bool _isEmailLoading = false;
  bool _isSocialLoading = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  SupabaseClient get _supabase => Supabase.instance.client;
  late final StreamSubscription<AuthState> _authStateSubscription;

  @override
  void initState() {
    super.initState();
    _authStateSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn && data.session != null) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          _navigateForUser(data.session!.user);
        }
      } else if (data.event == AuthChangeEvent.passwordRecovery) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          Navigator.pushReplacementNamed(context, '/reset_password');
        }
      }
    });
  }

  @override
  void dispose() {
    _authStateSubscription.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _profileDisplayName(Map<String, dynamic> profile) {
    final fullName = (profile['full_name'] ?? '').toString().trim();
    if (fullName.isNotEmpty) return fullName;

    final email = (profile['email'] ?? '').toString().trim();
    if (email.isEmpty) return '';

    final localPart = email.split('@').first.trim();
    return localPart.isNotEmpty ? localPart : email;
  }

  bool _isNavigating = false;

  Future<void> _navigateForUser(User user) async {
    if (_isNavigating) return;
    setState(() {
      _isNavigating = true;
      _isEmailLoading = true;
    });

    String? targetRoute;
    try {
      final profile = await _supabase
          .from('profiles')
          .select('role, full_name, email')
          .eq('id', user.id)
          .maybeSingle();

      var role = (profile?['role'] ?? '').toString();
      var fullName = (profile?['full_name'] ?? '').toString();

      // Retrieve missing role or name from metadata
      final metaData = user.userMetadata ?? {};
      final metaFullName = (metaData['full_name'] ?? '').toString();
      final metaRole = (metaData['role'] ?? '').toString();

      if (role.isEmpty && metaRole.isNotEmpty) {
        role = metaRole;
      }
      if (role.isEmpty) {
        role = 'buyer';
      }

      if (fullName.isEmpty && metaFullName.isNotEmpty) {
        fullName = metaFullName;
      }

      // Upsert if profile is missing, or role or full_name is empty
      if (profile == null ||
          (profile['role'] ?? '').toString().isEmpty ||
          (profile['full_name'] ?? '').toString().isEmpty) {
        await _supabase.from('profiles').upsert({
          'id': user.id,
          'email': user.email,
          'role': role,
          'full_name': fullName,
        });
      }

      // Remember in chat cache
      final displayName = fullName.isNotEmpty ? fullName : _profileDisplayName(
        Map<String, dynamic>.from(profile ?? {
          'full_name': fullName,
          'email': user.email,
        }),
      );
      if (displayName.isNotEmpty) {
        await ChatIdentityCache.instance.remember(
          userId: user.id,
          name: displayName,
        );
      }

      if (role == 'admin') {
        targetRoute = '/admin';
        AppModeService.instance.setMode(
          AppMode.buyer,
        ); // Admin stays in buyer mode for now
      } else if (role == 'seller') {
        AppModeService.instance.setMode(AppMode.seller);
        targetRoute = '/seller_home';
      } else {
        AppModeService.instance.setMode(AppMode.buyer);
        targetRoute = '/home';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      return;
    }

    if (!mounted) return;

    if (targetRoute != null) {
      final route = targetRoute; // Capture non-null value
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(route);
      });
    }

    if (mounted) {
      setState(() {
        _isNavigating = false;
        _isEmailLoading = false;
        _isSocialLoading = false;
      });
    }
  }

  Future<void> _login() async {
    if (_isEmailLoading) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password.')),
      );
      return;
    }

    setState(() => _isEmailLoading = true);

    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (response.user != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Login successful.')));
        // Navigation is now handled by onAuthStateChange listener
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $error')));
    } finally {
      if (mounted) {
        setState(() => _isEmailLoading = false);
      }
    }
  }

  Future<void> _signInWithProvider(OAuthProvider provider) async {
    if (_isSocialLoading) return;

    setState(() => _isSocialLoading = true);

    try {
      await _supabase.auth.signInWithOAuth(
        provider,
        redirectTo: 'io.supabase.flutter://login-callback',
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Social sign in failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _isSocialLoading = false);
      }
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    var resetEmail = _emailController.text.trim();

    final email = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Forgot Password'),
          content: TextFormField(
            initialValue: resetEmail,
            keyboardType: TextInputType.emailAddress,
            onChanged: (value) => resetEmail = value.trim(),
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'example@gmail.com',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, resetEmail),
              child: const Text('Send Reset Link'),
            ),
          ],
        );
      },
    );

    if (email == null || email.isEmpty) return;

    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.flutter://login-callback',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset link sent.')),
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send reset link: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  height: 300,
                  decoration: const BoxDecoration(
                    color: primaryRed,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(100),
                    ),
                  ),
                ),
                Positioned(
                  top: 100,
                  left: 40,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Welcome",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Listables E-commerce App",
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildCustomInput(
                    label: "Email",
                    hint: "example@gmail.com",
                    icon: Icons.email_outlined,
                    controller: _emailController,
                  ),
                  const SizedBox(height: 25),
                  _buildCustomInput(
                    label: "Password",
                    hint: "Password",
                    icon: Icons.lock_outline,
                    isPassword: true,
                    controller: _passwordController,
                  ),
                  const SizedBox(height: 15),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _showForgotPasswordDialog,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        "Forgot Password?",
                        style: GoogleFonts.inter(
                          color: primaryRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: primaryRed.withValues(alpha: 0.3),
                          spreadRadius: 1,
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isEmailLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryRed,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: _isEmailLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              "Login",
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _googleButton(),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "No account? ",
                        style: GoogleFonts.inter(
                          color: AppThemeColors.textSecondary(context),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/signup');
                        },
                        child: Text(
                          "Create one",
                          style: GoogleFonts.inter(
                            color: primaryRed,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomInput({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    bool isPassword = false,
  }) {
    final textColor = AppThemeColors.textPrimary(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: textColor.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppThemeColors.surface(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword && !_isPasswordVisible,
            keyboardType: isPassword
                ? TextInputType.text
                : TextInputType.emailAddress,
            style: GoogleFonts.inter(color: textColor),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(
                color: AppThemeColors.textSecondary(context),
              ),
              prefixIcon: Icon(
                icon,
                color: AppThemeColors.textSecondary(context),
              ),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: AppThemeColors.textSecondary(context),
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _googleButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: AppThemeColors.isDark(context)
            ? const Color(0xFF1B1D24)
            : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppThemeColors.isDark(context) ? 0.3 : 0.05,
            ),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppThemeColors.isDark(context)
              ? Colors.white12
              : Colors.grey.shade200,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: _isSocialLoading
              ? null
              : () => _signInWithProvider(OAuthProvider.google),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isSocialLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              else ...[
                Image.network(
                  'https://img.icons8.com/color/48/google-logo.png',
                  width: 24,
                  height: 24,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.g_mobiledata,
                      size: 30,
                      color: Colors.blue,
                    );
                  },
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Continue with Google',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppThemeColors.textPrimary(context),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
