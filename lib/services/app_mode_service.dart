import 'package:flutter/foundation.dart';

enum AppMode { buyer, seller }

class AppModeService {
  AppModeService._();

  static final AppModeService instance = AppModeService._();

  final ValueNotifier<AppMode> currentMode = ValueNotifier<AppMode>(
    AppMode.buyer,
  );

  void setMode(AppMode mode) {
    currentMode.value = mode;
  }

  bool get isSeller => currentMode.value == AppMode.seller;
  bool get isBuyer => currentMode.value == AppMode.buyer;
}
