// =============================================================================
// Giraffe — فحص المحتوى على طبقتين
//
// الطبقة الأولى: فحص نصي في القاعدة (`prescreen_item`) — رخيص وفوري.
//   • خطورة 3  → رفض فوري، **مفيش نداء لأي موديل**
//   • نضيف     → الصور بس هي اللي بتروح للموديل
//   • مشكوك    → الموديل بيحسم
//
// الفكرة كلها: **الموديل القوي مابيتنداش إلا على المشكوك فيه.**
// ده الفرق بين فاتورة معقولة وفاتورة بتتضاعف مع كل مستخدم جديد.
//
// ولو الموديل مش متاح أو فشل: المنتج بيتعلّم `flagged` ويستنى مراجعة
// بشرية — **مايتنشرش ومايترفضش**. الفشل الآمن هنا يعني عدم النشر.
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

type Decision = 'approved' | 'flagged' | 'rejected';

interface Verdict {
  decision: Decision;
  reason: string | null;
  categories: string[];
}

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

  const { data: item } = await db
    .from('items')
    .select('id, owner_id, title, description, category_id')
    .eq('id', itemId)
    .single();

  if (!item || item.owner_id !== userId) {
    return json({ ok: false, error: 'not_found' }, 404);
  }

  // ---------------------------------------------------------------------------
  // الطبقة الأولى — القاعدة
  // ---------------------------------------------------------------------------
  const { data: pre } = await db.rpc('prescreen_item', { p_item: itemId });
  const prescreen = pre as {
    decision: Decision;
    severity: number;
    matched_term: string | null;
    category: string | null;
    needs_vision: boolean;
  };

  if (prescreen.decision === 'rejected') {
    await db.rpc('apply_moderation', {
      p_item: itemId,
      p_result: 'rejected',
      p_note: prescreen.category ?? 'محتوى ممنوع',
    });

    await logJob(db, {
      userId, itemId, kind: 'moderate_item', status: 'done',
      model: 'prescreen', output: prescreen, costCents: 0,
      durationMs: Date.now() - started,
    });

    // مابنقولش للمستخدم المصطلح اللي اتمسك — ده بيعلّمه يلف حواليه
    return json({ ok: true, decision: 'rejected', reason: 'prohibited_content' });
  }

  // ---------------------------------------------------------------------------
  // الطبقة التانية — الصور
  // ---------------------------------------------------------------------------
  const { data: photos } = await db
    .from('item_photos')
    .select('storage_path')
    .eq('item_id', itemId)
    .order('position')
    .limit(2);   // صورتين كفاية للفحص

  const suspicious = prescreen.decision === 'flagged';
  const hasPhotos = (photos?.length ?? 0) > 0;

  if (!hasPhotos && !suspicious) {
    // نص نضيف ومفيش صور — مفيش حاجة تتفحص
    await db.rpc('apply_moderation', { p_item: itemId, p_result: 'approved' });
    await logJob(db, {
      userId, itemId, kind: 'moderate_item', status: 'done',
      model: 'prescreen', output: prescreen, costCents: 0,
      durationMs: Date.now() - started,
    });
    return json({ ok: true, decision: 'approved' });
  }

  const quota = await checkQuota(db, userId);
  if (!quota.allowed) {
    // السقف اتعدى → مراجعة بشرية. **مابننشرش من غير فحص.**
    await db.rpc('apply_moderation', {
      p_item: itemId, p_result: 'flagged', p_note: 'awaiting_review',
    });
    await logJob(db, {
      userId, itemId, kind: 'moderate_item', status: 'skipped',
      error: quota.reason,
    });
    return json({ ok: true, decision: 'flagged', reason: quota.reason });
  }

  const urls = (photos ?? []).map(
    (p: { storage_path: string }) =>
      db.storage.from('item-photos').getPublicUrl(p.storage_path).data.publicUrl,
  );

  const system = [
    'أنت مشرف محتوى لتطبيق مقايضة عربي.',
    'راجع نص المنتج وصوره وقرر إذا كان مسموح بالنشر.',
    '',
    'ممنوع نهائياً (rejected):',
    'سلاح · ذخيرة · أدوية · مخدرات · منتجات مقلدة · حيوانات حية · كحول · تبغ',
    'مستندات رسمية · بطاقات هوية · أجهزة مسروقة أو مقفولة · محتوى جنسي · عنف',
    '',
    'يحتاج مراجعة بشرية (flagged):',
    'صور مش واضحة · تناقض بين النص والصور · بيانات شخصية ظاهرة (أرقام، عناوين)',
    'ادعاءات مشكوك فيها · محتوى ممكن يكون مخالف بس مش مؤكد',
    '',
    'مسموح (approved): كل ما عدا ذلك.',
    '',
    'قاعدة حاكمة: **لو مش متأكد، اختر flagged مش rejected.**',
    'الرفض الخاطئ بيطرد مستخدم شرعي، والمراجعة البشرية بتصلّح الخطأ.',
    '',
    'رجّع JSON: decision (approved|flagged|rejected), reason, categories',
  ].join('\n');

  const result = await callModel<Verdict>({
    system,
    user: {
      title: item.title,
      description: item.description,
      category: item.category_id,
      prescreen_severity: prescreen.severity,
    },
    images: urls,
    schemaName: 'moderation_verdict',
    maxTokens: 250,
  });

  // ---------------------------------------------------------------------------
  // الفشل الآمن: مراجعة بشرية، مش نشر ومش رفض
  // ---------------------------------------------------------------------------
  if (!result.ok || !result.data) {
    await db.rpc('apply_moderation', {
      p_item: itemId, p_result: 'flagged', p_note: 'moderation_unavailable',
    });
    await logJob(db, {
      userId, itemId, kind: 'moderate_image', status: 'failed',
      error: result.error, model: result.model,
      durationMs: Date.now() - started,
    });
    return json({ ok: true, decision: 'flagged', reason: 'moderation_unavailable' });
  }

  const allowed: Decision[] = ['approved', 'flagged', 'rejected'];
  const decision: Decision = allowed.includes(result.data.decision)
    ? result.data.decision
    : 'flagged';

  await db.rpc('apply_moderation', {
    p_item: itemId,
    p_result: decision,
    p_note: result.data.reason ?? null,
  });

  await logJob(db, {
    userId, itemId, kind: 'moderate_image', status: 'done',
    model: result.model, output: result.data, costCents: result.costCents,
    durationMs: Date.now() - started,
  });

  return json({
    ok: true,
    decision,
    // سبب الرفض بيتقال للمستخدم؛ سبب التعليم لأ (عشان مايتحايلش)
    reason: decision === 'rejected' ? result.data.reason : null,
  });
});
