import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WishlistService {
  WishlistService._();

  static final WishlistService instance = WishlistService._();

  final SupabaseClient _supabase = Supabase.instance.client;
  final ValueNotifier<Set<int>> favoriteIds = ValueNotifier(<int>{});

  Future<void> load() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      favoriteIds.value = <int>{};
      return;
    }

    final response = await _supabase
        .from('wishlist')
        .select('product_id')
        .eq('user_id', user.id);

    favoriteIds.value = {
      ...(response as List).map((item) => item['product_id'] as int),
    };
  }

  bool isFavorite(int productId) {
    return favoriteIds.value.contains(productId);
  }

  Future<bool> toggle(int productId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Please login first');
    }

    final current = {...favoriteIds.value};
    final isAdding = !current.contains(productId);

    if (isAdding) {
      await _supabase.from('wishlist').insert({
        'user_id': user.id,
        'product_id': productId,
      });
      current.add(productId);
    } else {
      await _supabase
          .from('wishlist')
          .delete()
          .eq('user_id', user.id)
          .eq('product_id', productId);
      current.remove(productId);
    }

    favoriteIds.value = current;
    return isAdding;
  }

  Future<void> remove(int productId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Please login first');
    }

    await _supabase
        .from('wishlist')
        .delete()
        .eq('user_id', user.id)
        .eq('product_id', productId);

    final current = {...favoriteIds.value};
    current.remove(productId);
    favoriteIds.value = current;
  }
}
