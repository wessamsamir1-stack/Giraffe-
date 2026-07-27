import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_init.dart';
import '../mock/mock_data.dart';
import '../models/models.dart';

/// نتيجة سحبة.
class SwipeResult {
  const SwipeResult({
    required this.ok,
    this.matched = false,
    this.matchId,
    this.error,
  });

  final bool ok;
  final bool matched;
  final String? matchId;
  final String? error;

  /// ترجمة أخطاء الخادم لمفاتيح نصوص التطبيق.
  String? get errorKey => switch (error) {
        'daily_limit_reached' => 'deck.limitReached.title',
        'dream_limit_reached' => 'deck.dream',
        'room_limit_reached' => 'matches.roomsCount',
        'blocked' => 'common.block',
        null => null,
        _ => 'common.error',
      };
}

/// محرك المطابقة من ناحية التطبيق.
///
/// الشغل الحقيقي كله في القاعدة: `get_deck` و`record_swipe`.
/// التطبيق **مابيحسبش توافق ولا بيقرر ماتش** — لو حسبه هنا، أي حد
/// يقدر يتحايل عليه.
class DeckRepository {
  const DeckRepository();

  bool get hasBackend => SupabaseInit.isReady;
  SupabaseClient get _client => SupabaseInit.client;

  static const String _itemColumns =
      '*, item_photos(storage_path,is_cover,position), '
      'item_wanted_categories(category_id,subcategory_id)';

  /// كروت الصفقات المرشحة.
  ///
  /// الدالة في القاعدة بترجّع مفاتيح فقط، فبنجيب المنتجات والملفات
  /// في استعلامين إضافيين بدل N+1.
  Future<List<TradeCandidate>> deck({int limit = 20}) async {
    if (!hasBackend) return Mock.deck;

    final rows = await _client.rpc(
      'get_deck',
      params: {'p_limit': limit},
    ) as List<dynamic>;

    if (rows.isEmpty) return const [];

    final cards = rows.cast<Map<String, dynamic>>();

    final itemIds = <String>{
      for (final row in cards) ...[
        row['their_item_id'] as String,
        row['my_item_id'] as String,
      ],
    }.toList();

    final ownerIds = <String>{
      for (final row in cards) row['their_owner_id'] as String,
    }.toList();

    final itemRows = await _client
        .from('items')
        .select(_itemColumns)
        .inFilter('id', itemIds);

    final ownerRows = await _client
        .from('profiles')
        .select('*, user_stats(*)')
        .inFilter('id', ownerIds);

    final items = {
      for (final row in itemRows) row['id'] as String: Item.fromMap(row),
    };
    final owners = {
      for (final row in ownerRows)
        row['id'] as String: UserProfile.fromMap(row),
    };

    final result = <TradeCandidate>[];
    for (final row in cards) {
      final theirItem = items[row['their_item_id']];
      final myItem = items[row['my_item_id']];
      final owner = owners[row['their_owner_id']];
      if (theirItem == null || myItem == null || owner == null) continue;

      result.add(TradeCandidate.fromMap(
        row,
        theirItem: theirItem,
        theirOwner: owner,
        myItem: myItem,
      ),);
    }
    return result;
  }

  Future<SwipeResult> swipe({
    required String targetItemId,
    required String offeredItemId,
    required SwipeIntent intent,
  }) async {
    if (!hasBackend) {
      return SwipeResult(
        ok: true,
        matched: targetItemId == Mock.iphone.id && intent != SwipeIntent.skip,
        matchId: 'm_1',
      );
    }

    try {
      final response = await _client.rpc('record_swipe', params: {
        'p_target_item': targetItemId,
        'p_offered_item': offeredItemId,
        'p_intent': intent.name,
      },) as Map<String, dynamic>;

      return SwipeResult(
        ok: response['ok'] == true,
        matched: response['matched'] == true,
        matchId: response['match_id'] as String?,
        error: response['error'] as String?,
      );
    } catch (_) {
      return const SwipeResult(ok: false, error: 'network');
    }
  }

  /// التراجع — مجاني وبلا حدود عن عمد.
  Future<bool> undo() async {
    if (!hasBackend) return true;
    try {
      final response =
          await _client.rpc('undo_last_swipe') as Map<String, dynamic>;
      return response['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  /// السحبات المتبقية النهارده.
  Future<({int swipes, int dreams})> remainingToday() async {
    if (!hasBackend) return (swipes: 50, dreams: 3);

    final id = _client.auth.currentUser?.id;
    if (id == null) return (swipes: 0, dreams: 0);

    final rows = await _client
        .from('daily_limits')
        .select('swipes_used,dreams_used')
        .eq('user_id', id)
        .eq('day', DateTime.now().toIso8601String().split('T').first);

    if (rows.isEmpty) return (swipes: 50, dreams: 3);

    final row = rows.first;
    return (
      swipes: (50 - (row['swipes_used'] as int? ?? 0)).clamp(0, 50),
      dreams: (3 - (row['dreams_used'] as int? ?? 0)).clamp(0, 3),
    );
  }
}
