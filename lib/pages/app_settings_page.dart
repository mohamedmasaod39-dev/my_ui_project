import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_ui_project/services/theme_service.dart';

class AppSettingsPage extends StatelessWidget {
  const AppSettingsPage({super.key});

  static const Color primaryRed = Color(0xFFDB4444);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'App Settings',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Appearance',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ValueListenableBuilder<ThemeMode>(
              valueListenable: ThemeService.instance.themeMode,
              builder: (context, mode, _) {
                final darkModeEnabled = mode == ThemeMode.dark;
                return SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  title: Text(
                    'Night Mode',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    darkModeEnabled
                        ? 'Dark theme is enabled'
                        : 'Light theme is enabled',
                    style: GoogleFonts.inter(),
                  ),
                  secondary: Icon(
                    darkModeEnabled
                        ? Icons.dark_mode_outlined
                        : Icons.light_mode_outlined,
                    color: primaryRed,
                  ),
                  activeThumbColor: primaryRed,
                  value: darkModeEnabled,
                  onChanged: (value) {
                    ThemeService.instance.setThemeMode(
                      value ? ThemeMode.dark : ThemeMode.light,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
