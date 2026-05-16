import 'package:flutter/material.dart';

IconData iconFromString(String? iconName) {
  switch (iconName) {
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
    case 'devices':
      return Icons.devices;
    case 'male':
      return Icons.male;
    case 'female':
      return Icons.female;
    case 'child_care':
      return Icons.child_care;
    case 'watch':
      return Icons.watch;
    case 'more_horiz':
      return Icons.more_horiz;
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
