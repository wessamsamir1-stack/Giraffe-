// =============================================================================
// Giraffe — أدوات مشتركة لدوال الحافة
//
// كل مفاتيح الخدمات موجودة هنا **بس**. التطبيق مايشوفش ولا واحد منها.
// =============================================================================

import { createClient, SupabaseClient } from 'jsr:@supabase/supabase-js@2';

export const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}

export function preflight(req: Request): Response | null {
  return req.method === 'OPTIONS' ? new Response('ok', { headers: CORS }) : null;
}

// -----------------------------------------------------------------------------
// عميل بصلاحيات الخدمة — للكتابة اللي المستخدم مايقدرش يعملها
// -----------------------------------------------------------------------------
export function serviceClient(): SupabaseClient {
  return createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } },
  );
}

/**
 * التحقق من هوية المستخدم من رأس الطلب.
 *
 * **ممنوع** الاعتماد على أي user_id جاي في جسم الطلب — لازم من الرمز،
 * وإلا أي حد يقدر ينتحل صفة أي حد.
 */
export async function requireUser(req: Request): Promise<
  { userId: string; error: null } | { userId: null; error: Response }
> {
  const header = req.headers.get('Authorization') ?? '';
  const token = header.replace(/^Bearer\s+/i, '');

  if (!token) {
    return { userId: null, error: json({ ok: false, error: 'auth_required' }, 401) };
  }

  const client = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: header } }, auth: { persistSession: false } },
  );

  const { data, error } = await client.auth.getUser(token);
  if (error || !data.user) {
    return { userId: null, error: json({ ok: false, error: 'auth_required' }, 401) };
  }

  return { userId: data.user.id, error: null };
}

// -----------------------------------------------------------------------------
// سقف التكلفة
// -----------------------------------------------------------------------------
export async function checkQuota(
  db: SupabaseClient,
  userId: string,
): Promise<{ allowed: boolean; reason?: string }> {
  const { data, error } = await db.rpc('ai_quota_check', { p_user: userId });
  if (error) return { allowed: false, reason: 'quota_check_failed' };
  return data as { allowed: boolean; reason?: string };
}

// -----------------------------------------------------------------------------
// تسجيل المهمة
// -----------------------------------------------------------------------------
export interface JobLog {
  userId: string;
  itemId?: string;
  kind: 'analyze_item' | 'estimate_value' | 'moderate_item' | 'moderate_image';
  status: 'done' | 'failed' | 'skipped';
  model?: string;
  input?: unknown;
  output?: unknown;
  error?: string;
  costCents?: number;
  durationMs?: number;
}

export async function logJob(db: SupabaseClient, job: JobLog): Promise<void> {
  await db.from('ai_jobs').insert({
    user_id: job.userId,
    item_id: job.itemId ?? null,
    kind: job.kind,
    status: job.status,
    model: job.model ?? null,
    input: job.input ?? {},
    output: job.output ?? null,
    error: job.error ?? null,
    cost_cents: job.costCents ?? 0,
    duration_ms: job.durationMs ?? null,
    finished_at: new Date().toISOString(),
  });
}

// -----------------------------------------------------------------------------
// نداء الموديل
//
// ملاحظة تكلفة: الأسعار دي تقديرية وبتتغير — بتتحدث من متغيرات البيئة
// عشان مانضطرش ننشر نسخة جديدة كل ما السعر يتغيّر.
// -----------------------------------------------------------------------------
const PRICE_IN_PER_1M = Number(Deno.env.get('AI_PRICE_IN_PER_1M') ?? '100');
const PRICE_OUT_PER_1M = Number(Deno.env.get('AI_PRICE_OUT_PER_1M') ?? '500');

export interface ModelResult<T> {
  ok: boolean;
  data?: T;
  error?: string;
  costCents: number;
  model: string;
}

export async function callModel<T>(opts: {
  system: string;
  user: unknown;
  images?: string[];
  schemaName: string;
  maxTokens?: number;
}): Promise<ModelResult<T>> {
  const apiKey = Deno.env.get('OPENAI_API_KEY');
  const model = Deno.env.get('AI_MODEL') ?? 'gpt-4o-mini';

  if (!apiKey) {
    return { ok: false, error: 'model_not_configured', costCents: 0, model };
  }

  const content: unknown[] = [
    { type: 'text', text: typeof opts.user === 'string' ? opts.user : JSON.stringify(opts.user) },
  ];

  for (const url of opts.images ?? []) {
    content.push({ type: 'image_url', image_url: { url, detail: 'low' } });
  }

  try {
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model,
        max_tokens: opts.maxTokens ?? 700,
        temperature: 0.2,
        response_format: { type: 'json_object' },
        messages: [
          { role: 'system', content: opts.system },
          { role: 'user', content },
        ],
      }),
    });

    if (!response.ok) {
      const body = await response.text();
      return {
        ok: false,
        error: `model_http_${response.status}: ${body.slice(0, 200)}`,
        costCents: 0,
        model,
      };
    }

    const payload = await response.json();
    const text = payload?.choices?.[0]?.message?.content ?? '{}';

    const inTokens = payload?.usage?.prompt_tokens ?? 0;
    const outTokens = payload?.usage?.completion_tokens ?? 0;
    const costCents =
      (inTokens / 1_000_000) * PRICE_IN_PER_1M +
      (outTokens / 1_000_000) * PRICE_OUT_PER_1M;

    return { ok: true, data: JSON.parse(text) as T, costCents, model };
  } catch (err) {
    return { ok: false, error: String(err).slice(0, 200), costCents: 0, model };
  }
}

// -----------------------------------------------------------------------------
// تطبيع النص العربي — **نسخة مطابقة** لدالة normalize_ar في القاعدة
//
// أي اختلاف بين النسختين بيولّد نتائج مطابقة مختلفة بين التطبيق والخادم.
// -----------------------------------------------------------------------------
const AR_MAP: Record<string, string> = {
  'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ٱ': 'ا',
  'ى': 'ي', 'ئ': 'ي',
  'ؤ': 'و',
  'ة': 'ه',
};

export function normalizeAr(input: string): string {
  let out = input.toLowerCase().trim();
  for (const [from, to] of Object.entries(AR_MAP)) {
    out = out.replaceAll(from, to);
  }
  out = out.replace(/[ً-ْـ]/g, '');
  return out.replace(/\s+/g, ' ');
}
