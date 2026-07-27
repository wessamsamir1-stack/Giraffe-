// =============================================================================
// Giraffe — عامل الإشعارات الفورية
//
// بياخد دفعة من صندوق الصادر، يبعتها لفايربيز، ويسجّل النتيجة.
//
// بيتنادى كل دقيقة من pg_cron. وبيتصمّم على إنه **يتنادى أكتر من مرة
// بالتوازي من غير ضرر**: القاعدة بتقفل الصفوف بـ skip locked، فمفيش
// رنة بتتبعت مرتين.
//
// -----------------------------------------------------------------------------
// ليه FCM HTTP v1 مش الـ legacy؟
//
// الواجهة القديمة اتقفلت. الجديدة بتطلب رمز OAuth2، يعني لازم نوقّع
// JWT بمفتاح حساب الخدمة — وده اللي بيتعمل تحت في getAccessToken.
//
// -----------------------------------------------------------------------------
// وأهم سطر في الملف: تنظيف الرموز الميتة.
//
// لما جوجل ترجّع UNREGISTERED، ده معناه إن التطبيق اتشال من الجهاز.
// لو مامسحناش الرمز، الجدول بيكبر للأبد وكل إرسال بيضيع نداءات على
// أجهزة مابقتش موجودة — وإحنا بنحسب إن الإشعار وصل وهو مأوصلش.
// =============================================================================

import { json, preflight, serviceClient } from '../_shared/core.ts';

interface TokenRef {
  token: string;
  platform: 'ios' | 'android' | 'web';
  /// لغة الجهاز — خاصية الجهاز مش المستخدم: ممكن يكون عنده موبايل
  /// بالعربي وتابلت بالإنجليزي.
  lang: 'ar' | 'en';
}

interface Job {
  job_id: string;
  user_id: string;
  kind: string;
  title_ar: string;
  title_en: string;
  body_ar: string | null;
  body_en: string | null;
  payload: Record<string, unknown>;
  tokens: TokenRef[];
}

// -----------------------------------------------------------------------------
// رمز الوصول — بيتخزّن في الذاكرة لحد ما يقرب ينتهي
//
// الرمز صالح ساعة. توليده في كل نداء معناه توقيع JWT وطلب شبكة زيادة
// كل دقيقة من غير أي داعي.
// -----------------------------------------------------------------------------
let cachedToken: { value: string; expiresAt: number } | null = null;

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '');
  const raw = atob(body);
  const buf = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) buf[i] = raw.charCodeAt(i);
  return buf.buffer;
}

function base64url(input: string | Uint8Array): string {
  const bytes = typeof input === 'string'
    ? new TextEncoder().encode(input)
    : input;
  let binary = '';
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function getAccessToken(
  clientEmail: string,
  privateKey: string,
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);

  // بنجدّد قبل الانتهاء بدقيقة عشان مانقعش في نص الإرسال
  if (cachedToken && cachedToken.expiresAt > now + 60) {
    return cachedToken.value;
  }

  const header = base64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claim = base64url(JSON.stringify({
    iss: clientEmail,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }));

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(privateKey.replace(/\\n/g, '\n')),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );

  const signature = new Uint8Array(await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(`${header}.${claim}`),
  ));

  const assertion = `${header}.${claim}.${base64url(signature)}`;

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });

  if (!response.ok) {
    throw new Error(`oauth_failed_${response.status}: ${(await response.text()).slice(0, 200)}`);
  }

  const data = await response.json();
  cachedToken = {
    value: data.access_token,
    expiresAt: now + (data.expires_in ?? 3600),
  };
  return cachedToken.value;
}

Deno.serve(async (req) => {
  const cors = preflight(req);
  if (cors) return cors;

  const projectId = Deno.env.get('FCM_PROJECT_ID');
  const clientEmail = Deno.env.get('FCM_CLIENT_EMAIL');
  const privateKey = Deno.env.get('FCM_PRIVATE_KEY');

  const db = serviceClient();

  // ---------------------------------------------------------------------------
  // من غير إعدادات فايربيز: مانفشلش، بنعلّم الصفوف skipped.
  //
  // ده مقصود — النظام كله لازم يشتغل قبل ما حد يفتح حساب فايربيز.
  // ولو سبناهم queued، الصندوق هيتكدّس وكل دقيقة هنحاول ونفشل تاني.
  // ---------------------------------------------------------------------------
  if (!projectId || !clientEmail || !privateKey) {
    const { data } = await db.rpc('push_claim_batch', { p_limit: 100 });
    for (const job of (data ?? []) as Job[]) {
      await db.rpc('push_mark', {
        p_job: job.job_id,
        p_status: 'skipped',
        p_error: 'fcm_not_configured',
      });
    }
    return json({
      ok: true,
      configured: false,
      skipped: (data ?? []).length,
    });
  }

  let accessToken: string;
  try {
    accessToken = await getAccessToken(clientEmail, privateKey);
  } catch (err) {
    // فشل المصادقة مش خطأ في صف معيّن — بنسيب الصفوف مكانها للمحاولة
    // الجاية بدل ما نحرق محاولاتها.
    return json({ ok: false, error: String(err).slice(0, 200) }, 500);
  }

  const { data: batch } = await db.rpc('push_claim_batch', { p_limit: 50 });
  const jobs = (batch ?? []) as Job[];

  let sent = 0;
  let dropped = 0;

  for (const job of jobs) {
    if (!job.tokens?.length) {
      await db.rpc('push_mark', {
        p_job: job.job_id, p_status: 'skipped', p_error: 'no_tokens',
      });
      continue;
    }

    let anySucceeded = false;
    let lastError: string | null = null;

    for (const ref of job.tokens) {
      // النص بلغة **الجهاز**. الافتراضي عربي — ده سوق مصر والخليج.
      const useEn = ref.lang === 'en';
      const title = useEn ? (job.title_en || job.title_ar) : job.title_ar;
      const body = useEn
        ? (job.body_en ?? job.body_ar ?? undefined)
        : (job.body_ar ?? undefined);

      const message = {
        message: {
          token: ref.token,
          notification: { title, body },
          data: Object.fromEntries(
            Object.entries({ ...job.payload, kind: job.kind })
              .map(([k, v]) => [k, String(v)]),
          ),
          android: {
            priority: 'HIGH',
            notification: {
              // الدمج على مستوى الجهاز كمان — لو وصلت رنتين قبل ما
              // المستخدم يفتح، بيشوف واحدة
              tag: `${job.kind}:${job.payload?.match_id ?? job.user_id}`,
              channel_id: 'giraffe_default',
            },
          },
          apns: {
            headers: {
              'apns-priority': '10',
              'apns-collapse-id':
                `${job.kind}:${job.payload?.match_id ?? job.user_id}`.slice(0, 64),
            },
            payload: { aps: { sound: 'default' } },
          },
        },
      };

      const response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(message),
        },
      );

      if (response.ok) {
        anySucceeded = true;
        continue;
      }

      const body = await response.text();
      lastError = `${response.status}: ${body.slice(0, 160)}`;

      // -----------------------------------------------------------------------
      // الرمز الميت بيتمسح — مش بيتساب يضيّع نداءات للأبد
      // -----------------------------------------------------------------------
      if (
        response.status === 404 ||
        body.includes('UNREGISTERED') ||
        body.includes('INVALID_ARGUMENT')
      ) {
        await db.rpc('push_drop_token', { p_token: ref.token });
        dropped++;
      }
    }

    if (anySucceeded) {
      sent++;
      await db.rpc('push_mark', { p_job: job.job_id, p_status: 'sent' });
    } else {
      // مابنعلّمهاش failed فوراً — push_claim_batch بتزوّد المحاولات
      // وبتوقف عند 3، فالصف بياخد فرصته وبيموت لوحده.
      await db.rpc('push_mark', {
        p_job: job.job_id, p_status: 'queued', p_error: lastError,
      });
    }
  }

  return json({
    ok: true,
    configured: true,
    claimed: jobs.length,
    sent,
    dropped_tokens: dropped,
  });
});
