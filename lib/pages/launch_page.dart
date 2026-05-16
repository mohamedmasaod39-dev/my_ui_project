import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/app_mode_service.dart';

class LaunchPage extends StatefulWidget {
  const LaunchPage({super.key});

  @override
  State<LaunchPage> createState() => _LaunchPageState();
}

class _LaunchPageState extends State<LaunchPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isRedirecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _redirect();
    });
  }

  Future<void> _redirect() async {
    if (_isRedirecting) return;
    _isRedirecting = true;

    // Force logout once to clear all stored "passwords"/sessions as requested
    // This ensures everyone starts fresh with website accounts
    await _supabase.auth.signOut();

    String targetRoute = '/login';

    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        targetRoute = '/login';
      } else {
        final profile = await _supabase
            .from('profiles')
            .select('role, email')
            .eq('id', user.id)
            .maybeSingle();

        var role = (profile?['role'] ?? '').toString();
        if (role.isEmpty) {
          role = 'buyer';
          await _supabase.from('profiles').upsert({
            'id': user.id,
            'email': user.email,
            'role': role,
          });
        }

        if (role == 'admin') {
          targetRoute = '/admin';
        } else if (role == 'seller') {
          AppModeService.instance.setMode(AppMode.seller);
          targetRoute = '/seller_home';
        } else {
          AppModeService.instance.setMode(AppMode.buyer);
          targetRoute = '/home';
        }
      }
    } catch (_) {
      targetRoute = '/login';
    }

    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(targetRoute);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
