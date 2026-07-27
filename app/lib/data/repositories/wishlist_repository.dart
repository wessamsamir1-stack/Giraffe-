import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_init.dart';
import '../mock/mock_data.dart';
import '../models/models.dart';

/// قائمة الرغبات — مدخل محرك المطابقة.
///
/// الحدود (3 كحد أدنى · 10 كحد أقصى) مفروضة في **القاعدة** كمان،
/// فالتحقق هنا للتجربة بس.
class WishlistRepository {
  const WishlistRepository();

  bool get hasBackend => SupabaseInit.isReady;
  SupabaseClient get _client => SupabaseInit.client;

  Future<List<WishItem>> mine() async {
    if (!hasBackend) return Mock.wishlist;

    final id = _client.auth.currentUser?.id;
    if (id == null) return const [];

    final rows = await _client
        .from('wishlist_items')
        .select()
        .eq('user_id', id)
        .order('created_at');

    return rows.map(WishItem.fromMap).toList();
  }

  /// إضافة رغبة واحدة.
  ///
  /// بترجع مفتاح خطأ أو `null` لو نجحت.
  Future<String?> add(WishItem wish) async {
    if (!hasBackend) return null;

    final id = _client.auth.currentUser?.id;
    if (id == null) return 'auth.err.generic';

    try {
      await _client.from('wishlist_items').insert(wish.toInsert(id));
      return null;
    } on PostgrestException catch (error) {
      if (error.message.contains('wishlist_limit_reached')) {
        return 'wish.limit';
      }
      if (error.code == '23505') return null; // موجودة أصلاً — مش خطأ
      return 'common.error';
    } catch (_) {
      return 'common.error';
    }
  }

  /// حفظ اختيارات الإعداد الأولي دفعة واحدة.
  Future<String?> setCategories(List<String> categoryIds) async {
    if (!hasBackend) return null;

    final id = _client.auth.currentUser?.id;
    if (id == null) return 'auth.err.generic';
    if (categoryIds.length < 3) return 'setup.wishlist.counter';

    try {
      await _client.from('wishlist_items').insert([
        for (final categoryId in categoryIds.take(10))
          {'user_id': id, 'category_id': categoryId, 'notify': true},
      ]);
      return null;
    } on PostgrestException catch (error) {
      if (error.code == '23505') return null;
      return 'common.error';
    } catch (_) {
      return 'common.error';
    }
  }

  Future<void> remove(String wishId) async {
    if (!hasBackend) return;
    await _client.from('wishlist_items').delete().eq('id', wishId);
  }

  Future<void> setNotify(String wishId, bool notify) async {
    if (!hasBackend) return;
    await _client
        .from('wishlist_items')
        .update({'notify': notify}).eq('id', wishId);
  }

  /// هل المستخدم خلّص الإعداد الأولي؟
  ///
  /// نفس الشرط اللي بيفرضه الـ deck في القاعدة: 3 رغبات + منتج متاح.
  Future<bool> isSetupComplete() async {
    if (!hasBackend) return true;

    final id = _client.auth.currentUser?.id;
    if (id == null) return false;

    final result = await _client.rpc('is_setup_complete', params: {
      'p_user': id,
    });
    return result == true;
  }
}
