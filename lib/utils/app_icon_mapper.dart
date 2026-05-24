import 'package:flutter/material.dart';

IconData iconFromString(String? iconName) {
  switch (iconName) {
    case 'monitor':
    case 'desktop_windows':
    case 'desktop_windows_outlined':
    case 'devices':
      return Icons.desktop_windows_outlined;
    case 'gamepad':
    case 'sports_esports':
    case 'sports_esports_outlined':
      return Icons.sports_esports_outlined;
    case 'home':
    case 'home_outlined':
      return Icons.home_outlined;
    case 'shopping-bag':
    case 'shopping_bag':
    case 'shopping_bag_outlined':
      return Icons.shopping_bag_outlined;
    case 'globe':
    case 'public':
    case 'public_outlined':
    case 'sports':
      return Icons.public_outlined;
    case 'ellipsis-horizontal':
    case 'more_horiz':
      return Icons.more_horiz;
    case 'phone_iphone':
      return Icons.phone_iphone;
    case 'laptop_mac':
      return Icons.laptop_mac;
    case 'watch':
      return Icons.watch;
    case 'camera_alt':
      return Icons.camera_alt;
    case 'checkroom':
      return Icons.checkroom;
    case 'male':
      return Icons.male;
    case 'female':
      return Icons.female;
    case 'child_care':
      return Icons.child_care;
    case 'chair':
      return Icons.chair;
    case 'spa':
      return Icons.spa;
    case 'sports_soccer':
      return Icons.sports_soccer;
    case 'menu_book':
      return Icons.menu_book;
    case 'category':
      return Icons.category;
    default:
      return Icons.grid_view_rounded;
  }
}
