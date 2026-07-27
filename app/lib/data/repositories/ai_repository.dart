import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_init.dart';
import '../models/models.dart';

/// اقتراحات تحليل المنتج.
///
/// كلها قابلة للتعديل — **الذكاء الاصطناعي بيقترح والمستخدم بيقرر**.
class ItemSuggestion {
  const ItemSuggestion({
    this.categoryId,
    this.subCategoryId,
    this.brand,
    this.model,
    this.condition,
    this.title,
    this.description,
    this.confidence = 0,
  });

  final String? categoryId;
  final String? subCategoryId;
  final String? brand;
  final String? model;
  final ItemCondition? condition;
  final String? title;
  final String? description;
  final double confidence;

  bool get isEmpty => title == null && categoryId == null;

  factory ItemSuggestion.fromMap(Map<String, dynamic> row) {
    final raw = row['condition'] as String?;
    return ItemSuggestion(
      categoryId: row['category_id'] as String?,
      subCategoryId: row['subcategory_id'] as String?,
      brand: row['brand'] as String?,
      model: row['model'] as String?,
      condition: raw == null ? null : ItemConditionX.parse(raw),
      title: row['title'] as String?,
      description: row['description'] as String?,
      confidence: (row['confidence'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// نطاق القيمة التقديري.
///
/// `null` معناه **مانعرضش تقدير** — مش معناه صفر.
class ValueEstimate {
  const ValueEstimate({
    required this.min,
    required this.max,
    required this.confidence,
    required this.sampleSize,
    required this.source,
    required this.currencyCode,
  });

  final double min;
  final double max;
  final double confidence;
  final int sampleSize;
  final String source;
  final String currencyCode;

  /// هل التقدير من بياناتنا ولا من النموذج؟
  bool get fromOurData => source.startsWith('comparables');

  factory ValueEstimate.fromMap(Map<String, dynamic> row) => ValueEstimate(
        min: (row['value_min'] as num).toDouble(),
        max: (row['value_max'] as num).toDouble(),
        confidence: (row['confidence'] as num?)?.toDouble() ?? 0,
        sampleSize: (row['sample_size'] as num?)?.toInt() ?? 0,
        source: row['source'] as String? ?? 'model',
        currencyCode: row['currency_code'] as String? ?? 'EGP',
      );
}

enum ModerationDecision { approved, flagged, rejected, unknown }

/// نداءات الذكاء الاصطناعي.
///
/// كلها بتمر بدوال الحافة — **مفيش أي مفتاح موديل في التطبيق**.
///
/// وكلها بترجع قيمة فاضية بدل ما ترمي استثناء: فشل التحليل مش خطأ
/// للمستخدم، هو بيكمل يدوي وخلاص.
class AiRepository {
  const AiRepository();

  bool get hasBackend => SupabaseInit.isReady;
  SupabaseClient get _client => SupabaseInit.client;

  Future<ItemSuggestion> analyzeItem(String itemId) async {
    if (!hasBackend) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      return const ItemSuggestion(
        categoryId: 'mobiles',
        subCategoryId: 'mobiles.phones',
        brand: 'Apple',
        model: 'iPhone 15 Pro',
        condition: ItemCondition.likeNew,
        title: 'آيفون 15 برو 256 جيجا',
        description: 'بطارية 94%. بالعلبة والشاحن. مفيش أي خدوش.',
        confidence: 0.88,
      );
    }

    try {
      final response = await _client.functions.invoke(
        'analyze-item',
        body: {'item_id': itemId},
      );
      final data = response.data as Map<String, dynamic>?;
      final suggestion = data?['suggestion'] as Map<String, dynamic>?;
      if (suggestion == null) return const ItemSuggestion();
      return ItemSuggestion.fromMap(suggestion);
    } catch (_) {
      return const ItemSuggestion();
    }
  }

  Future<ValueEstimate?> estimateValue({
    String? itemId,
    String? categoryId,
    String? subCategoryId,
    String? brand,
    String? model,
    ItemCondition? condition,
    String countryCode = 'EG',
  }) async {
    if (!hasBackend) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      return const ValueEstimate(
        min: 38000,
        max: 44000,
        confidence: 0.9,
        sampleSize: 31,
        source: 'comparables_model',
        currencyCode: 'EGP',
      );
    }

    try {
      final response = await _client.functions.invoke(
        'estimate-value',
        body: {
          if (itemId != null) 'item_id': itemId,
          if (categoryId != null) 'category_id': categoryId,
          if (subCategoryId != null) 'subcategory_id': subCategoryId,
          if (brand != null && brand.isNotEmpty) 'brand': brand,
          if (model != null && model.isNotEmpty) 'model': model,
          if (condition != null) 'condition': condition.wire,
          'country_code': countryCode,
        },
      );

      final data = response.data as Map<String, dynamic>?;
      final estimate = data?['estimate'] as Map<String, dynamic>?;
      if (estimate == null) return null;   // ثقة منخفضة = مانعرضش
      return ValueEstimate.fromMap(estimate);
    } catch (_) {
      return null;
    }
  }

  /// فحص المحتوى.
  ///
  /// بيتنادى بعد النشر. لو رجّع `flagged` المنتج بيستنى مراجعة بشرية
  /// ومابيظهرش في السوق — وده مقصود: الفشل الآمن يعني عدم النشر.
  Future<ModerationDecision> moderateItem(String itemId) async {
    if (!hasBackend) return ModerationDecision.approved;

    try {
      final response = await _client.functions.invoke(
        'moderate-item',
        body: {'item_id': itemId},
      );
      final data = response.data as Map<String, dynamic>?;
      return switch (data?['decision']) {
        'approved' => ModerationDecision.approved,
        'flagged' => ModerationDecision.flagged,
        'rejected' => ModerationDecision.rejected,
        _ => ModerationDecision.unknown,
      };
    } catch (_) {
      return ModerationDecision.unknown;
    }
  }
}
