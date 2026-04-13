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
import 'pages/category_products_page.dart';
import 'pages/orders_page.dart';
import 'pages/notifications_page.dart';
import 'pages/offers_page.dart';
import 'pages/conversations_page.dart';
import 'pages/messages_page.dart';
import 'pages/checkout_success_page.dart';
import 'pages/my_products_page.dart';
import 'pages/add_edit_product_page.dart';
import 'pages/role_selection_page.dart';
import 'pages/seller_home_page.dart';
import 'pages/seller_orders_page.dart';
import 'pages/seller_offers_page.dart';
import 'pages/admin_page.dart';

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
        '/role_selection': (context) => const RoleSelectionPage(),
        '/admin': (context) => const AdminPage(),
        '/home': (context) => const IndexPage(),
        '/seller_home': (context) => const SellerHomePage(),
        '/details': (context) => const DetailsPage(),
        '/profile': (context) => const ProfilePage(),
        '/cart': (context) => const CartPage(),
        '/search': (context) => const SearchPage(),
        '/wishlist': (context) => const WishlistPage(),
        '/faq': (context) => const FAQPage(),
        '/about': (context) => AboutUsPage(),
        '/category_products_page': (context) => const CategoryProductsPage(),
        '/orders': (context) => const OrdersPage(),
        '/notifications': (context) => const NotificationsPage(),
        '/offers': (context) => const OffersPage(),
        '/conversations': (context) => const ConversationsPage(),
        '/messages': (context) => const MessagesPage(),
        '/checkout_success': (context) => const CheckoutSuccessPage(),
        '/my_products': (context) => const MyProductsPage(),
        '/add_product': (context) => const AddEditProductPage(),
        '/edit_product': (context) => const AddEditProductPage(),
        '/seller_orders': (context) => const SellerOrdersPage(),
        '/seller_offers': (context) => const SellerOffersPage(),
      },
    );
  }
}
