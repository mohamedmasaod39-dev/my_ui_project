import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WishlistService {
  WishlistService._();
  static final WishlistService instance = WishlistService._();

  final supabase = Supabase.instance.client;
  final ValueNotifier<Set<int>> favoriteIds = ValueNotifier({});

  Future<void> load() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      favoriteIds.value = {};
      return;
    }
    try {
      final res = await supabase.from('wishlist').select('product_id').eq('user_id', user.id);
      favoriteIds.value = (res as List).map((item) => item['product_id'] as int).toSet();
    } catch (_) {}
  }

  bool isFavorite(int productId) => favoriteIds.value.contains(productId);

  Future<bool> toggle(int productId) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Please login first');

    final isRemoving = isFavorite(productId);
    if (isRemoving) {
      await supabase.from('wishlist').delete().eq('user_id', user.id).eq('product_id', productId);
      final newSet = Set<int>.from(favoriteIds.value)..remove(productId);
      favoriteIds.value = newSet;
      return false;
    } else {
      await supabase.from('wishlist').insert({'user_id': user.id, 'product_id': productId});
      final newSet = Set<int>.from(favoriteIds.value)..add(productId);
      favoriteIds.value = newSet;
      return true;
    }
  }
}
