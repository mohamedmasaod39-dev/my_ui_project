import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/index_page.dart';
import 'pages/login_page.dart';
import 'pages/launch_page.dart';
import 'pages/details_page.dart';
import 'pages/profile_page.dart';
import 'pages/cart_page.dart';
import 'pages/search_page.dart';
import 'pages/signup_page.dart';
import 'pages/signup_page.dart';
import 'pages/faq_page.dart';
import 'pages/about_page.dart';
import 'pages/category_products_page.dart';
import 'pages/orders_page.dart';
import 'pages/notifications_page.dart';
import 'pages/messages_page.dart';
import 'pages/checkout_success_page.dart';
import 'pages/chat_page.dart';
import 'pages/my_products_page.dart';
import 'pages/add_edit_product_page.dart';
import 'pages/seller_home_page.dart';
import 'pages/seller_orders_page.dart';
import 'pages/seller_profile_page.dart';
import 'pages/admin_page.dart';
import 'pages/admin_orders_page.dart';
import 'pages/admin_users_page.dart';
import 'pages/admin_products_moderation_page.dart';
import 'pages/app_settings_page.dart';
import 'pages/reset_password_page.dart';
import 'pages/escrow_page.dart';
import 'pages/public_seller_profile_page.dart';
import 'pages/contact_page.dart';
import 'pages/wishlist_page.dart';
import 'services/app_scaffold_messenger.dart';
import 'services/chat_identity_cache.dart';
import 'services/theme_service.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const useLocalSupabase = false;
  const localSupabaseUrl = 'http://10.0.2.2:54321';
  const localSupabaseAnonKey = 'YOUR_LOCAL_ANON_KEY_HERE';
  const remoteSupabaseUrl = 'https://bpmafrqnxisigfaxefiu.supabase.co';
  const remoteSupabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJwbWFmcnFueGlzaWdmYXhlZml1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM2NTkxNTYsImV4cCI6MjA4OTIzNTE1Nn0.x2c1IwJwxkAKq90zrpxsDMX-5uW-FO3QOsc1vVIQfyA';

  await Supabase.initialize(
    url: useLocalSupabase ? localSupabaseUrl : remoteSupabaseUrl,
    anonKey: useLocalSupabase ? localSupabaseAnonKey : remoteSupabaseAnonKey,
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
          scaffoldMessengerKey: appScaffoldMessengerKey,
          navigatorObservers: [routeObserver],
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeMode,
          initialRoute: '/launch',
          routes: {
            '/launch': (context) => const LaunchPage(),
            '/login': (context) => const LoginPage(),
            '/signup': (context) => const SignupPage(),
            '/admin': (context) => const AdminPage(),
            '/admin_orders': (context) => const AdminOrdersPage(),
            '/admin_users': (context) => const AdminUsersPage(),
            '/admin_products': (context) => const AdminProductsPage(),
            '/home': (context) => const IndexPage(),
            '/seller_home': (context) => const SellerHomePage(),
            '/details': (context) => const DetailsPage(),
            '/profile': (context) => const ProfilePage(),
            '/cart': (context) => const CartPage(),
            '/search': (context) => const SearchPage(),
            '/faq': (context) => const FAQPage(),
            '/about': (context) => AboutUsPage(),
            '/category_products_page': (context) => const CategoryProductsPage(),
            '/orders': (context) => const OrdersPage(),
            '/notifications': (context) => const NotificationsPage(),
            '/messages': (context) => const MessagesPage(),
            '/chat': (context) => const ChatPage(),
            '/checkout_success': (context) => const CheckoutSuccessPage(),
            '/my_products': (context) => const MyProductsPage(),
            '/add_product': (context) => const AddEditProductPage(),
            '/edit_product': (context) => const AddEditProductPage(),
            '/seller_orders': (context) => const SellerOrdersPage(),
            '/seller_profile': (context) => const SellerProfilePage(),
            '/app_settings': (context) => const AppSettingsPage(),
            '/reset_password': (context) => const ResetPasswordPage(),
            '/escrow': (context) {
              final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
              return EscrowPage(
                orderId: args['orderId'] as int,
                role: args['role'] as String,
              );
            },
            '/public_seller_profile': (context) => const PublicSellerProfilePage(),
            '/contact': (context) => const ContactPage(),
            '/wishlist': (context) => const WishlistPage(),
          },
        );
      },
    );
  }
}
