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
import 'pages/messages_page.dart';
import 'pages/offers_page.dart';
import 'pages/checkout_success_page.dart';
import 'pages/chat_page.dart';
import 'pages/my_products_page.dart';
import 'pages/add_edit_product_page.dart';
import 'pages/role_selection_page.dart';
import 'pages/seller_home_page.dart';
import 'pages/seller_orders_page.dart';
import 'pages/seller_offers_page.dart';
import 'pages/admin_page.dart';
import 'pages/admin_orders_page.dart';
import 'pages/app_settings_page.dart';
import 'pages/reset_password_page.dart';
import 'services/chat_identity_cache.dart';
import 'services/theme_service.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://bpmafrqnxisigfaxefiu.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJwbWFmcnFueGlzaWdmYXhlZml1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM2NTkxNTYsImV4cCI6MjA4OTIzNTE1Nn0.x2c1IwJwxkAKq90zrpxsDMX-5uW-FO3QOsc1vVIQfyA',
  );
  await ChatIdentityCache.instance.initialize();
  await ThemeService.instance.initialize();

  runApp(const ListablesApp());
}

class ListablesApp extends StatelessWidget {
  const ListablesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.instance.themeMode,
      builder: (context, themeMode, _) {
        const primaryRed = Color(0xFFDB4444);

        final lightTheme = ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          primaryColor: primaryRed,
          colorScheme: ColorScheme.fromSeed(
            seedColor: primaryRed,
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: Colors.white,
          cardColor: const Color(0xFFF5F5F5),
          dividerColor: Colors.black12,
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFFF5F5F5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
          snackBarTheme: const SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            surfaceTintColor: Colors.transparent,
          ),
        );

        final darkTheme = ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          primaryColor: primaryRed,
          colorScheme: ColorScheme.fromSeed(
            seedColor: primaryRed,
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF121212),
          cardColor: const Color(0xFF1E1E1E),
          dividerColor: Colors.white12,
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF1B1D24),
            hintStyle: const TextStyle(color: Colors.white54),
            labelStyle: const TextStyle(color: Colors.white70),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
          snackBarTheme: const SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF121212),
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
          ),
        );

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          navigatorObservers: [routeObserver],
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeMode,
          initialRoute: '/login',
          routes: {
            '/login': (context) => const LoginPage(),
            '/signup': (context) => const SignupPage(),
            '/role_selection': (context) => const RoleSelectionPage(),
            '/admin': (context) => const AdminPage(),
            '/admin_orders': (context) => const AdminOrdersPage(),
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
            '/messages': (context) => const MessagesPage(),
            '/offers': (context) => const OffersPage(),
            '/chat': (context) => const ChatPage(),
            '/checkout_success': (context) => const CheckoutSuccessPage(),
            '/my_products': (context) => const MyProductsPage(),
            '/add_product': (context) => const AddEditProductPage(),
            '/edit_product': (context) => const AddEditProductPage(),
            '/seller_orders': (context) => const SellerOrdersPage(),
            '/seller_offers': (context) => const SellerOffersPage(),
            '/app_settings': (context) => const AppSettingsPage(),
            '/reset_password': (context) => const ResetPasswordPage(),
          },
        );
      },
    );
  }
}
