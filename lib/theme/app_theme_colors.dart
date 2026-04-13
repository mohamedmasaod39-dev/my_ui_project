import 'package:flutter/material.dart';

class AppThemeColors {
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color surface(BuildContext context) =>
      isDark(context) ? const Color(0xFF1B1D24) : const Color(0xFFF5F5F5);

  static Color elevatedSurface(BuildContext context) =>
      isDark(context) ? const Color(0xFF242730) : Colors.white;

  static Color secondarySurface(BuildContext context) =>
      isDark(context) ? const Color(0xFF15171D) : const Color(0xFFFAFAFA);

  static Color textPrimary(BuildContext context) =>
      isDark(context) ? Colors.white : Colors.black;

  static Color textSecondary(BuildContext context) =>
      isDark(context) ? Colors.white70 : Colors.black54;

  static Color textMuted(BuildContext context) =>
      isDark(context) ? Colors.white54 : Colors.black45;

  static Color border(BuildContext context) =>
      isDark(context) ? Colors.white12 : Colors.black12;

  static Color icon(BuildContext context) =>
      isDark(context) ? Colors.white : Colors.black;
}
