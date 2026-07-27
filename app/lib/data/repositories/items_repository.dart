import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_init.dart';
import '../mock/mock_data.dart';
import '../models/models.dart';

/// ترتيب نتائج السوق.
enum MarketSort { bestMatch, newest, nearest, valueDesc, valueAsc }

/// المنتجات: منتجاتي والسوق المفتوح والنشر.
class ItemsRepository {
  const ItemsRepository();

  bool get hasBackend => SupabaseInit.isReady;
  SupabaseClient get _client => SupabaseInit.client;

  static const String _columns =
      '*, item_photos(storage_path,is_cover,position), '
      'item_wanted_categories(category_id,subcategory_id)';

  // ---------------------------------------------------------------------------
  Future<List<Item>> myItems() async {
    if (!hasBackend) return Mock.myItems;

    final id = _client.auth.currentUser?.id;
    if (id == null) return const [];

    final rows = await _client
        .from('items')
        .select(_columns)
        .eq('owner_id', id)
        .order('created_at', ascending: false);

    return rows.map(Item.fromMap).toList();
  }

  /// منتجات مستخدم تاني — للملف العام.
  Future<List<Item>> byOwner(String ownerId) async {
    if (!hasBackend) {
      return Mock.marketItems.where((i) => i.ownerId == ownerId).toList();
    }

    final rows = await _client
        .from('items')
        .select(_columns)
        .eq('owner_id', ownerId)
        .eq('status', 'available')
        .eq('moderation', 'approved')
        .order('published_at', ascending: false)
        .limit(30);

    return rows.map(Item.fromMap).toList();
  }

  Future<Item?> byId(String itemId) async {
    if (!hasBackend) return Mock.item(itemId);

    final rows = await _client.from('items').select(_columns).eq('id', itemId);
    if (rows.isEmpty) return null;
    return Item.fromMap(rows.first);
  }

  /// السوق المفتوح.
  ///
  /// مقيّد بمجموعة السوق (المدينة ومجاوراتها) — المقايضة عملية فيزيائية
  /// فمالهاش معنى نعرض منتج في سوق تاني.
  ///
  /// الاستثناء الوحيد: **الخدمات**، لأنها بتتسلّم عن بعد.
  Future<List<Item>> market({
    String? categoryId,
    String? subCategoryId,
    String? marketGroup,
    MarketSort sort = MarketSort.newest,
    int limit = 40,
    int offset = 0,
  }) async {
    if (!hasBackend) {
      const all = Mock.marketItems;
      if (categoryId == null) return all;
      return all.where((i) => i.categoryId == categoryId).toList();
    }

    var query = _client
        .from('items')
        .select(_columns)
        .eq('status', 'available')
        .eq('moderation', 'approved');

    if (categoryId != null) query = query.eq('category_id', categoryId);
    if (subCategoryId != null) query = query.eq('subcategory_id', subCategoryId);

    if (marketGroup != null) {
      // المدن اللي في نفس مجموعة السوق
      final cities = await _client
          .from('cities')
          .select('id')
          .eq('market_group', marketGroup);
      final ids = cities.map((c) => c['id'] as String).toList();
      if (ids.isNotEmpty) {
        query = query.inFilter('city_id', ids);
      }
    }

    final rows = await switch (sort) {
      MarketSort.newest => query
          .order('published_at', ascending: false)
          .range(offset, offset + limit - 1),
      MarketSort.valueDesc => query
          .order('value_max', ascending: false)
          .range(offset, offset + limit - 1),
      MarketSort.valueAsc => query
          .order('value_min', ascending: true)
          .range(offset, offset + limit - 1),
      // الأقرب والأنسب محتاجين ترتيب على الخادم — مؤجلين للمرحلة التانية
      _ => query
          .order('published_at', ascending: false)
          .range(offset, offset + limit - 1),
    };

    return rows.map(Item.fromMap).toList();
  }

  /// بحث نصي.
  ///
  /// بيستخدم التطبيع العربي في القاعدة عبر `title_norm`، فـ "آيفون"
  /// و"ايفون" بيرجّعوا نفس النتيجة.
  Future<List<Item>> search(String term, {String? marketGroup}) async {
    if (!hasBackend) return Mock.marketItems;
    if (term.trim().isEmpty) return const [];

    final rows = await _client
        .from('items')
        .select(_columns)
        .eq('status', 'available')
        .eq('moderation', 'approved')
        .ilike('title_norm', '%${normalizeAr(term)}%')
        .limit(40);

    return rows.map(Item.fromMap).toList();
  }

  /// نفس منطق `public.normalize_ar` في القاعدة — لازم يفضلوا متطابقين.
  ///
  /// عامة عن قصد: الدالة دي مكتوبة تلات مرات — هنا وفي القاعدة وفي
  /// دوال الحافة — وأي اختلاف بينهم بيخلي البحث يرجّع نتايج غلط في صمت.
  /// فلازم تكون قابلة للاختبار.
  static String normalizeAr(String input) {
    var out = input.toLowerCase().trim();
    const map = {
      'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ٱ': 'ا',
      'ى': 'ي', 'ئ': 'ي',
      'ؤ': 'و',
      'ة': 'ه',
    };
    map.forEach((from, to) => out = out.replaceAll(from, to));
    out = out.replaceAll(RegExp('[ً-ْـ]'), '');
    return out.replaceAll(RegExp(r'\s+'), ' ');
  }

  // ---------------------------------------------------------------------------
  /// نشر منتج جديد.
  ///
  /// بيرجع رقم المنتج، أو `null` لو فشل.
  Future<String?> create({
    required String title,
    required String description,
    required String categoryId,
    String? subCategoryId,
    required ItemCondition condition,
    required String countryCode,
    required String cityId,
    String? areaId,
    double? lat,
    double? lng,
    double? valueMin,
    double? valueMax,
    required String currencyCode,
    double aiConfidence = 0,
    int comparableCount = 0,
    String brand = '',
    String model = '',
    bool isService = false,
    double willPayUpTo = 0,
    bool acceptsCashDiff = true,
    List<String> wantedCategoryIds = const [],
  }) async {
    if (!hasBackend) return 'mock-item';

    final owner = _client.auth.currentUser?.id;
    if (owner == null) return null;

    try {
      final inserted = await _client
          .from('items')
          .insert({
            'owner_id': owner,
            'title': title.trim(),
            'description': description.trim(),
            'category_id': categoryId,
            if (subCategoryId != null) 'subcategory_id': subCategoryId,
            'condition': condition.wire,
            'country_code': countryCode,
            'city_id': cityId,
            if (areaId != null) 'area_id': areaId,
            if (lat != null) 'lat': lat,
            if (lng != null) 'lng': lng,
            if (valueMin != null) 'value_min': valueMin,
            if (valueMax != null) 'value_max': valueMax,
            'currency_code': currencyCode,
            'ai_confidence': aiConfidence,
            'comparable_count': comparableCount,
            'brand': brand,
            'model': model,
            'is_service': isService,
            'will_pay_up_to': willPayUpTo,
            'accepts_cash_diff': acceptsCashDiff,
            // بيفضل pending لحد ما فحص المحتوى يعتمده
            'status': 'pending',
          })
          .select('id')
          .single();

      final itemId = inserted['id'] as String;

      if (wantedCategoryIds.isNotEmpty) {
        await _client.from('item_wanted_categories').insert([
          for (final categoryId in wantedCategoryIds)
            {'item_id': itemId, 'category_id': categoryId},
        ]);
      }

      return itemId;
    } catch (_) {
      return null;
    }
  }

  Future<void> attachPhoto({
    required String itemId,
    required String storagePath,
    required int position,
  }) async {
    if (!hasBackend) return;
    await _client.from('item_photos').insert({
      'item_id': itemId,
      'storage_path': storagePath,
      'position': position,
      'is_cover': position == 0,
    });
  }

  /// تحديث بيانات المنتج بعد ما المستخدم يراجع اقتراحات الذكاء الاصطناعي.
  Future<String?> update({
    required String itemId,
    String? title,
    String? description,
    String? categoryId,
    String? subCategoryId,
    ItemCondition? condition,
    String? brand,
    String? model,
    double? valueMin,
    double? valueMax,
    double? aiConfidence,
    int? comparableCount,
    double? willPayUpTo,
    bool? acceptsCashDiff,
    ItemStatus? status,
    List<String>? wantedCategoryIds,
  }) async {
    if (!hasBackend) return null;

    try {
      await _client.from('items').update({
        if (title != null) 'title': title.trim(),
        if (description != null) 'description': description.trim(),
        if (categoryId != null) 'category_id': categoryId,
        if (subCategoryId != null) 'subcategory_id': subCategoryId,
        if (condition != null) 'condition': condition.wire,
        if (brand != null) 'brand': brand,
        if (model != null) 'model': model,
        if (valueMin != null) 'value_min': valueMin,
        if (valueMax != null) 'value_max': valueMax,
        if (aiConfidence != null) 'ai_confidence': aiConfidence,
        if (comparableCount != null) 'comparable_count': comparableCount,
        if (willPayUpTo != null) 'will_pay_up_to': willPayUpTo,
        if (acceptsCashDiff != null) 'accepts_cash_diff': acceptsCashDiff,
        if (status != null) 'status': status.wire,
      }).eq('id', itemId);

      if (wantedCategoryIds != null) {
        await _client
            .from('item_wanted_categories')
            .delete()
            .eq('item_id', itemId);

        if (wantedCategoryIds.isNotEmpty) {
          await _client.from('item_wanted_categories').insert([
            for (final categoryId in wantedCategoryIds)
              {'item_id': itemId, 'category_id': categoryId},
          ]);
        }
      }
      return null;
    } catch (_) {
      return 'common.error';
    }
  }

  Future<void> updateStatus(String itemId, ItemStatus status) async {
    if (!hasBackend) return;
    await _client
        .from('items')
        .update({'status': status.wire}).eq('id', itemId);
  }

  Future<void> delete(String itemId) async {
    if (!hasBackend) return;
    await _client.from('items').delete().eq('id', itemId);
  }
}
