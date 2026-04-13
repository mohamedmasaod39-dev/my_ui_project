import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static const Color primaryRed = Color(0xFFDB4444);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "Profile",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // 1. PROFILE HEADER
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: primaryRed.withOpacity(0.1),
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
                      backgroundColor: Colors.black,
                      child: IconButton(
                        icon: const Icon(
                          Icons.edit,
                          size: 15,
                          color: Colors.white,
                        ),
                        onPressed: () {},
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            Text(
              "mai's Device", // Your device name from terminal logs
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "mai.student@aast.edu", // Based on your AAST project context
              style: GoogleFonts.inter(color: Colors.grey),
            ),
            const SizedBox(height: 40),

            // 2. ACCOUNT SETTINGS SECTION
            _buildProfileMenu("My Orders", Icons.shopping_bag_outlined),
            _buildProfileMenu("Wishlist", Icons.favorite_border),
            _buildProfileMenu("Payment Methods", Icons.credit_card),
            _buildProfileMenu("Delivery Address", Icons.location_on_outlined),
            const Divider(height: 40),

            // 3. APP SETTINGS
            _buildProfileMenu("Privacy Policy", Icons.privacy_tip_outlined),
            _buildProfileMenu("Settings", Icons.settings_outlined),

            // LOGOUT BUTTON
            const SizedBox(height: 20),
            ListTile(
              onTap: () => Navigator.pushReplacementNamed(context, '/login'),
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

  Widget _buildProfileMenu(String title, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.black),
        title: Text(
          title,
          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey,
        ),
        onTap: () {},
      ),
    );
  }
}
