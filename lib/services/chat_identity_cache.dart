import 'package:shared_preferences/shared_preferences.dart';

class ChatIdentityCache {
  ChatIdentityCache._();

  static final ChatIdentityCache instance = ChatIdentityCache._();
  static const _storageKey = 'chat_identity_names';

  final Map<String, String> _namesByUserId = <String, String>{};

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final storedNames = prefs.getStringList(_storageKey) ?? const <String>[];

    _namesByUserId.clear();
    for (final entry in storedNames) {
      final separatorIndex = entry.indexOf('|');
      if (separatorIndex <= 0 || separatorIndex >= entry.length - 1) {
        continue;
      }

      final userId = entry.substring(0, separatorIndex).trim();
      final name = entry.substring(separatorIndex + 1).trim();
      if (userId.isEmpty || name.isEmpty) continue;
      _namesByUserId[userId] = name;
    }
  }

  String? nameFor(String userId) {
    final value = _namesByUserId[userId]?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Future<void> remember({
    required String userId,
    required String name,
  }) async {
    final trimmedUserId = userId.trim();
    final trimmedName = name.trim();
    if (trimmedUserId.isEmpty || trimmedName.isEmpty) return;
    if (_namesByUserId[trimmedUserId] == trimmedName) return;

    _namesByUserId[trimmedUserId] = trimmedName;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _storageKey,
      _namesByUserId.entries
          .map((entry) => '${entry.key}|${entry.value}')
          .toList(),
    );
  }
}
