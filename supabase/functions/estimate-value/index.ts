// =============================================================================
// Giraffe — تقدير نطاق القيمة
//
// الترتيب مقصود ومهم:
//
//   1. **مقارناتنا أولاً.** لو عندنا بيانات كفاية، مابنناديش أي موديل.
//      أرخص وأدق، وبيتحسّن كل يوم مع كل صفقة مكتملة.
//
//   2. النموذج تاني، وبس لما مفيش مقارنات.
//
//   3. **لو الثقة أقل من 0.60 مابنرجّعش تقدير خالص.**
//      رقم غلط بيولّد خلافات بين المستخدمين ومسؤولية علينا —
//      والفراغ أشرف من التخمين.
//
// وقاعدة أخيرة: **ممنوع رقم واحد قاطع.** نطاق دايماً، ومعاه مصدره.
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

const MIN_CONFIDENCE = 0.60;

interface Estimate {
  value_min: number | null;
  value_max: number | null;
  confidence: number;
  sample_size: number;
  source: string;
  currency_code: string;
}

Deno.serve(async (req) => {
  const cors = preflight(req);
  if (cors) return cors;

  const started = Date.now();
  const auth = await requireUser(req);
  if (auth.error) return auth.error;
  const userId = auth.userId!;

  const db = serviceClient();

  let body: {
    item_id?: string;
    category_id?: string;
    subcategory_id?: string;
    brand?: string;
    model?: string;
    condition?: string;
    country_code?: string;
  };
  try {
    body = await req.json();
  } catch {
    return json({ ok: false, error: 'bad_request' }, 400);
  }

  // لو جالنا رقم منتج، بناخد بياناته منه — أدق من الاعتماد على العميل
  let input = body;
  if (body.item_id) {
    const { data: item } = await db
      .from('items')
      .select('owner_id, category_id, subcategory_id, brand, model, condition, country_code, is_service')
      .eq('id', body.item_id)
      .single();

    if (!item || item.owner_id !== userId) {
      return json({ ok: false, error: 'not_found' }, 404);
    }

    // الخدمات: المستخدم بيحدد قيمتها بنفسه — مفيش سوق مرجعي لها
    if (item.is_service) {
      return json({
        ok: true,
        estimate: null,
        reason: 'service_item_user_priced',
      });
    }

    input = { ...body, ...item };
  }

  const { data: country } = await db
    .from('countries')
    .select('currency_code')
    .eq('code', input.country_code ?? 'EG')
    .single();

  const currency = country?.currency_code ?? 'EGP';

  // ---------------------------------------------------------------------------
  // 1. مقارناتنا
  // ---------------------------------------------------------------------------
  const { data: fromComparables } = await db.rpc('estimate_from_comparables', {
    p_country: input.country_code ?? 'EG',
    p_category: input.category_id,
    p_subcategory: input.subcategory_id ?? null,
    p_brand: input.brand ?? null,
    p_model: input.model ?? null,
    p_condition: input.condition ?? 'good',
  });

  if (fromComparables) {
    const estimate: Estimate = {
      ...(fromComparables as Omit<Estimate, 'currency_code'>),
      currency_code: currency,
    };

    await logJob(db, {
      userId, itemId: body.item_id, kind: 'estimate_value', status: 'done',
      model: 'comparables', output: estimate, costCents: 0,
      durationMs: Date.now() - started,
    });

    return json({ ok: true, estimate });
  }

  // ---------------------------------------------------------------------------
  // 2. النموذج — بس لما مفيش مقارنات
  // ---------------------------------------------------------------------------
  const quota = await checkQuota(db, userId);
  if (!quota.allowed) {
    await logJob(db, {
      userId, itemId: body.item_id, kind: 'estimate_value',
      status: 'skipped', error: quota.reason,
    });
    return json({ ok: true, estimate: null, reason: quota.reason });
  }

  const system = [
    'أنت خبير أسعار السوق المستعمل في مصر والخليج.',
    '',
    'قواعد ملزمة:',
    '- رجّع **نطاق** سعر مش رقم واحد.',
    `- السعر بعملة ${currency} وبأسعار السوق المحلي، مش بأسعار عالمية محوّلة.`,
    '- خد بالك إن أسعار المستعمل المحلية بتختلف كتير عن الأسعار العالمية.',
    '- confidence من 0 لـ 1. **لو المنتج مش مميز أو مش متأكد، خليها أقل من 0.6**',
    '  وإحنا مش هنعرض التقدير أصلاً — وده أحسن من رقم غلط.',
    '',
    'رجّع JSON: value_min, value_max, confidence, reasoning',
  ].join('\n');

  const result = await callModel<{
    value_min: number;
    value_max: number;
    confidence: number;
    reasoning?: string;
  }>({
    system,
    user: {
      category: input.category_id,
      subcategory: input.subcategory_id,
      brand: input.brand,
      model: input.model,
      condition: input.condition,
      country: input.country_code,
      currency,
    },
    schemaName: 'value_estimate',
    maxTokens: 300,
  });

  if (!result.ok || !result.data) {
    await logJob(db, {
      userId, itemId: body.item_id, kind: 'estimate_value', status: 'failed',
      error: result.error, model: result.model,
      durationMs: Date.now() - started,
    });
    return json({ ok: true, estimate: null, reason: 'estimation_failed' });
  }

  const confidence = Math.max(0, Math.min(1, Number(result.data.confidence) || 0));

  await logJob(db, {
    userId, itemId: body.item_id, kind: 'estimate_value', status: 'done',
    model: result.model, output: result.data, costCents: result.costCents,
    durationMs: Date.now() - started,
  });

  // ---------------------------------------------------------------------------
  // 3. الحد الأدنى للثقة — الفراغ أشرف من التخمين
  // ---------------------------------------------------------------------------
  if (confidence < MIN_CONFIDENCE) {
    return json({ ok: true, estimate: null, reason: 'low_confidence' });
  }

  const min = Number(result.data.value_min);
  const max = Number(result.data.value_max);

  if (!Number.isFinite(min) || !Number.isFinite(max) || max < min || min <= 0) {
    return json({ ok: true, estimate: null, reason: 'invalid_range' });
  }

  const estimate: Estimate = {
    value_min: Math.round(min),
    value_max: Math.round(max),
    confidence,
    sample_size: 0,
    source: 'model',
    currency_code: currency,
  };

  return json({ ok: true, estimate });
});
