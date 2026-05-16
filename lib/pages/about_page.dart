import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_ui_project/theme/app_theme_colors.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  static const Color primaryRed = Color(0xFFDB4444);

  @override
  Widget build(BuildContext context) {
    final textColor = AppThemeColors.textPrimary(context);
    final secondaryTextColor = AppThemeColors.textSecondary(context);
    final isDark = AppThemeColors.isDark(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // 1. ARTISTIC BACKGROUND GRADIENTS
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryRed.withValues(alpha: 0.15),
              ),
            ),
          ),

          // 2. SCROLLABLE CONTENT
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 80),

                // BRAND LOGO ICON
                Center(
                  child: TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(seconds: 1),
                    builder: (context, double value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.scale(
                          scale: value,
                          child: Container(
                            padding: const EdgeInsets.all(25),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isDark ? Colors.white12 : Colors.black12,
                                width: 2,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.shopping_bag_outlined,
                              color: textColor,
                              size: 60,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 25),
                Text(
                  "LISTABLES",
                  style: GoogleFonts.poppins(
                    color: textColor,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                ),
                const SizedBox(height: 10),
                Container(width: 50, height: 3, color: primaryRed),

                // BRAND STORY TEXT
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
                  child: Text(
                    "Listables is more than an app; it's a premium e-commerce ecosystem designed for.... . We bridge the gap between luxury design and high-performance mobile engineering.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: secondaryTextColor,
                      height: 1.8,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                // 3. MISSION & VISION (Glassmorphic Cards)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _buildInfoCard(
                        context,
                        "Our Mission",
                        "Redefining the digital marketplace for online users.",
                        Icons.auto_awesome,
                      ),
                      const SizedBox(width: 15),
                      _buildInfoCard(
                        context,
                        "Our Vision",
                        "Becoming the #1 hub for ecommerce  in Egypt.",
                        Icons.visibility,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),


                const SizedBox(height: 60),

                // AAST GRADUATION TAG
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppThemeColors.elevatedSurface(context),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.school_outlined,
                        color: secondaryTextColor,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "AAST Graduation Project 2026",
                        style: GoogleFonts.inter(
                          color: secondaryTextColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 50),
              ],
            ),
          ),

          // 5. BACK BUTTON
          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              icon: Icon(Icons.arrow_back_ios, color: textColor),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, String title, String desc, IconData icon) {
    final textColor = AppThemeColors.textPrimary(context);
    final secondaryTextColor = AppThemeColors.textSecondary(context);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        height: 180,
        decoration: BoxDecoration(
          color: AppThemeColors.surface(context),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: AppThemeColors.border(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: primaryRed, size: 30),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              desc,
              style: TextStyle(
                color: secondaryTextColor,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

