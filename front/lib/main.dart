import 'package:flutter/material.dart';
import 'pages/index_page.dart';
import 'pages/login_page.dart';
import 'pages/details_page.dart'; // Ensure this import is here
import 'pages/profile_page.dart'; // Ensure this import is here

void main() {
  runApp(const ListablesApp());
}

class ListablesApp extends StatelessWidget {
  const ListablesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      // Set the starting page
      initialRoute: '/home',
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const IndexPage(),
        '/details': (context) =>
            const DetailsPage(), // Register the beast mode details page
        '/profile': (context) => const ProfilePage(),
      },
    );
  }
}
