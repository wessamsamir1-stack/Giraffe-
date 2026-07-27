// =============================================================================
// Giraffe — تحليل صور المنتج
//
// بياخد رقم المنتج، يقرا صوره، ويرجّع اقتراحات: القسم والماركة والموديل
// والحالة وعنوان ووصف.
//
// ثلاث قواعد حاكمة:
//
//   1. **بيقترح مش بيقرر.** المستخدم بيراجع كل حقل ويعدّله.
//   2. **مايوقفش المستخدم أبداً.** أي فشل بيرجّع اقتراحات فاضية
//      والتطبيق بيروح على الإدخال اليدوي.
//   3. **مايكتبش في المنتج.** بيرجّع اقتراحات بس — الكتابة بتتم لما
//      المستخدم يوافق.
// =============================================================================

import {
  callModel,
  checkQuota,
  json,
  logJob,
  preflight,
  requireUser,
  serviceClient,
} from '../_shared/core.ts';

interface Suggestion {
  category_id: string | null;
  subcategory_id: string | null;
  brand: string | null;
  model: string | null;
  condition: 'brand_new' | 'like_new' | 'good' | 'fair' | 'for_parts' | null;
  title: string | null;
  description: string | null;
  confidence: number;
  detected_objects: string[];
}

const EMPTY: Suggestion = {
  category_id: null,
  subcategory_id: null,
  brand: null,
  model: null,
  condition: null,
  title: null,
  description: null,
  confidence: 0,
  detected_objects: [],
};

Deno.serve(async (req) => {
  const cors = preflight(req);
  if (cors) return cors;

  const started = Date.now();
  const auth = await requireUser(req);
  if (auth.error) return auth.error;
  const userId = auth.userId!;

  const db = serviceClient();

  let itemId: string | undefined;
  try {
    ({ item_id: itemId } = await req.json());
  } catch {
    return json({ ok: false, error: 'bad_request' }, 400);
  }
  if (!itemId) return json({ ok: false, error: 'item_id_required' }, 400);

  // ---------------------------------------------------------------------------
  // ملكية المنتج — ممنوع حد يحلل منتج مش بتاعه
  // ---------------------------------------------------------------------------
  const { data: item } = await db
    .from('items')
    .select('id, owner_id, country_code, is_service')
    .eq('id', itemId)
    .single();

  if (!item || item.owner_id !== userId) {
    return json({ ok: false, error: 'not_found' }, 404);
  }

  // الخدمات مالهاش تحليل بصري — المستخدم بيوصفها بنفسه
  if (item.is_service) {
    return json({ ok: true, suggestion: EMPTY, reason: 'service_item' });
  }

  // ---------------------------------------------------------------------------
  // السقف
  // ---------------------------------------------------------------------------
  const quota = await checkQuota(db, userId);
  if (!quota.allowed) {
    await logJob(db, {
      userId, itemId, kind: 'analyze_item', status: 'skipped',
      error: quota.reason,
    });
    // بنرجّع نجاح باقتراح فاضي — المستخدم بيكمل يدوي من غير رسالة خطأ
    return json({ ok: true, suggestion: EMPTY, reason: quota.reason });
  }

  // ---------------------------------------------------------------------------
  // الصور
  // ---------------------------------------------------------------------------
  const { data: photos } = await db
    .from('item_photos')
    .select('storage_path')
    .eq('item_id', itemId)
    .order('position')
    .limit(3);   // 3 صور كفاية — الرابعة مابتضيفش دقة وبتضيف تكلفة

  if (!photos?.length) {
    return json({ ok: true, suggestion: EMPTY, reason: 'no_photos' });
  }

  const urls = photos.map(
    (p: { storage_path: string }) =>
      db.storage.from('item-photos').getPublicUrl(p.storage_path).data.publicUrl,
  );

  // ---------------------------------------------------------------------------
  // كتالوج الأقسام — بنبعته للموديل عشان يختار من عندنا مش يخترع
  // ---------------------------------------------------------------------------
  const { data: categories } = await db
    .from('categories')
    .select('id, name_ar, name_en, subcategories(id, name_ar)')
    .eq('is_active', true);

  const system = [
    'أنت مساعد لتطبيق مقايضة عربي اسمه Giraffe.',
    'مهمتك تحليل صور منتج مستعمل وإرجاع بيانات منظمة بالعربي.',
    '',
    'قواعد ملزمة:',
    '- اختر category_id و subcategory_id من الكتالوج المرفق فقط. ممنوع تخترع قيم.',
    '- العنوان بالعربي، من 3 لـ 8 كلمات، وواقعي مش تسويقي.',
    '- الوصف بالعربي، سطرين على الأكثر، يذكر الحالة الظاهرة والملحقات.',
    '- الحالة من: brand_new | like_new | good | fair | for_parts',
    '- confidence من 0 لـ 1. لو الصور مش واضحة أو المنتج مش مميز، خليها منخفضة.',
    '- لو مش متأكد من حقل، رجّعه null. **التخمين أسوأ من الفراغ.**',
    '',
    'رجّع JSON بالمفاتيح دي فقط:',
    'category_id, subcategory_id, brand, model, condition, title, description, confidence, detected_objects',
  ].join('\n');

  const result = await callModel<Suggestion>({
    system,
    user: { catalogue: categories, instruction: 'حلّل الصور المرفقة' },
    images: urls,
    schemaName: 'item_suggestion',
    maxTokens: 600,
  });

  if (!result.ok || !result.data) {
    await logJob(db, {
      userId, itemId, kind: 'analyze_item', status: 'failed',
      error: result.error, model: result.model,
      durationMs: Date.now() - started,
    });
    // فشل التحليل **مش خطأ للمستخدم** — بيكمل يدوي
    return json({ ok: true, suggestion: EMPTY, reason: 'analysis_failed' });
  }

  // ---------------------------------------------------------------------------
  // تنظيف المخرجات — الموديل ممكن يرجّع قسم مش موجود عندنا
  // ---------------------------------------------------------------------------
  const known = new Set((categories ?? []).map((c: { id: string }) => c.id));
  const suggestion: Suggestion = {
    ...EMPTY,
    ...result.data,
    category_id: known.has(result.data.category_id ?? '')
      ? result.data.category_id
      : null,
    confidence: Math.max(0, Math.min(1, Number(result.data.confidence) || 0)),
  };

  await logJob(db, {
    userId, itemId, kind: 'analyze_item', status: 'done',
    model: result.model, output: suggestion,
    costCents: result.costCents,
    durationMs: Date.now() - started,
  });

  return json({ ok: true, suggestion });
});
