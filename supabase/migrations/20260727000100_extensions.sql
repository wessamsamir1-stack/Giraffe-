-- =============================================================================
-- Giraffe — 01. الإضافات والدوال المساعدة
-- =============================================================================

create extension if not exists pgcrypto;   -- gen_random_uuid, digest
create extension if not exists citext;     -- بريد واسم مستخدم غير حساسين لحالة الأحرف
create extension if not exists pg_trgm;    -- مطابقة تقريبية لكلمات قائمة الرغبات
create extension if not exists unaccent;   -- تطبيع النص

-- -----------------------------------------------------------------------------
-- ملاحظة معمارية: ليه مفيش PostGIS
--
-- الخطة الأصلية كانت PostGIS. اتغيّرت للأسباب دي:
--
-- 1. إحنا **مش بناخد موقع دقيق** أصلاً (قرار خصوصية) — بنخزن نقطة تقريبية
--    مزحزحة عشوائياً في حدود كيلومتر.
-- 2. المطابقة مقيّدة بالمدينة أولاً، والمسافة بتيجي كترتيب ثانوي.
-- 3. على المستوى ده، مؤشر على (city_id, lat, lng) + هافرساين بيدّي نفس
--    النتيجة بجزء من التعقيد.
--
-- PostGIS بيبقى مبرر لما تنزل **الخريطة** في المرحلة التانية — عندها
-- بنضيف عمود geography ومؤشر GiST جنب الأعمدة الحالية بدون كسر أي حاجة.
-- -----------------------------------------------------------------------------

create or replace function public.haversine_km(
  lat1 double precision,
  lng1 double precision,
  lat2 double precision,
  lng2 double precision
)
returns double precision
language sql
immutable
parallel safe
as $$
  select case
    when lat1 is null or lng1 is null or lat2 is null or lng2 is null then null
    else 6371.0 * 2 * asin(
      sqrt(
        power(sin(radians(lat2 - lat1) / 2), 2)
        + cos(radians(lat1)) * cos(radians(lat2))
          * power(sin(radians(lng2 - lng1) / 2), 2)
      )
    )
  end
$$;

comment on function public.haversine_km is
  'المسافة بالكيلومتر بين نقطتين. تقريبية عمداً — الإحداثيات نفسها مزحزحة للخصوصية.';

-- -----------------------------------------------------------------------------
-- تزحزح الإحداثيات — لا نخزّن الموقع الحقيقي أبداً
--
-- بنزحزح النقطة عشوائياً في حدود ~1 كم قبل التخزين. المستخدم بيشوف
-- "3.4 كم" وهي دقيقة كفاية للقرار، ومفيش أي طريقة لاستنتاج عنوانه.
-- -----------------------------------------------------------------------------

create or replace function public.jitter_point(
  lat double precision,
  lng double precision,
  max_km double precision default 1.0
)
returns table (jlat double precision, jlng double precision)
language plpgsql
volatile
as $$
declare
  angle double precision := random() * 2 * pi();
  dist  double precision := sqrt(random()) * max_km;
  dlat  double precision := (dist / 110.574) * cos(angle);
  dlng  double precision;
begin
  if lat is null or lng is null then
    jlat := null; jlng := null; return next; return;
  end if;

  dlng := (dist / (111.320 * cos(radians(lat)))) * sin(angle);
  jlat := round((lat + dlat)::numeric, 4)::double precision;
  jlng := round((lng + dlng)::numeric, 4)::double precision;
  return next;
end;
$$;

-- -----------------------------------------------------------------------------
-- تطبيع النص العربي للبحث والمطابقة
--
-- بيوحّد الألف بأشكالها والتاء المربوطة والياء، وبيشيل التشكيل والتطويل.
-- من غير ده، "آيفون" و"ايفون" و"إيفون" بيبقوا ٣ كلمات مختلفة تماماً.
-- -----------------------------------------------------------------------------

create or replace function public.normalize_ar(input text)
returns text
language sql
immutable
parallel safe
as $$
  select nullif(
    trim(
      regexp_replace(
        translate(
          lower(coalesce(input, '')),
          -- أول 8 حروف بتتبدل، والباقي (التشكيل والتطويل) بيتشال
          'أإآٱىئؤةًٌٍَُِّْـ',
          'ااااييوه'
        ),
        '\s+', ' ', 'g'
      )
    ),
    ''
  )
$$;

comment on function public.normalize_ar is
  'توحيد الألف والياء والتاء المربوطة وإزالة التشكيل — ضروري لمطابقة قائمة الرغبات.';

-- -----------------------------------------------------------------------------
-- تحديث updated_at تلقائياً
-- -----------------------------------------------------------------------------

create or replace function public.tg_touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
