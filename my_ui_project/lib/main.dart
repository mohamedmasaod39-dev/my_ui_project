import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/index_page.dart';
import 'pages/login_page.dart';
import 'pages/details_page.dart';
import 'pages/profile_page.dart';
import 'pages/cart_page.dart';
import 'pages/search_page.dart';
import 'pages/signup_page.dart';
import 'pages/wishlist_page.dart';
import 'pages/faq_page.dart';
import 'pages/about_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://bpmafrqnxisigfaxefiu.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJwbWFmcnFueGlzaWdmYXhlZml1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM2NTkxNTYsImV4cCI6MjA4OTIzNTE1Nn0.x2c1IwJwxkAKq90zrpxsDMX-5uW-FO3QOsc1vVIQfyA',
  );

  runApp(const ListablesApp());
}

class ListablesApp extends StatelessWidget {
  const ListablesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFFDB4444),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignupPage(),
        '/home': (context) => const IndexPage(),
        '/details': (context) => const DetailsPage(),
        '/profile': (context) => const ProfilePage(),
        '/cart': (context) => const CartPage(),
        '/search': (context) => const SearchPage(),
        '/wishlist': (context) => const WishlistPage(),
        '/faq': (context) => const FAQPage(),
        '/about': (context) => AboutUsPage(),
      },
    );
  }
}