-- =============================================================================
-- Giraffe — 23. الإشعارات الفورية
--
-- الإشعار مش ميزة تجميلية هنا. المطابقة بتحصل والطرف التاني مش عارف،
-- فالغرفة بتفضل مقفولة والصفقة بتموت — وده بيضرب المؤشر الرئيسي نفسه:
-- **عدد الصفقات المكتملة**.
--
-- بس الإشعار كمان أسرع طريقة تخسر بيها مستخدم. تطبيق بيرن كتير أو
-- بالليل بيتشال. فالملف ده مبني على أربع قواعد:
--
--   1. **صندوق صادر، مش نداء من محفّز.** المحفّز بيكتب صف والعامل
--      بيبعت. لو نادينا HTTP من جوه المحفّز، معاملة قاعدة البيانات
--      تبقى معلّقة على خدمة برّه — وأول ما جوجل تتأخر، النشر كله
--      بيقف.
--
--   2. **مش كل إشعار يستاهل رنة.**
--
--   3. **ساعات الهدوء.** الرنة الساعة 3 الفجر بتتشال التطبيق.
--      بنأجّل، مانلغيش.
--
--   4. **الدمج.** 20 رسالة في غرفة = رنة واحدة، مش 20.
-- =============================================================================

create type public.push_status as enum ('queued', 'sent', 'failed', 'skipped');

create table public.push_outbox (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  notification_id uuid references public.notifications(id) on delete cascade,

  kind            public.notification_kind not null,
  title_ar        text not null,
  title_en        text not null,
  body_ar         text,
  body_en         text,
  payload         jsonb not null default '{}'::jsonb,

  -- مفتاح الدمج: نفس المفتاح = رنة واحدة بتتحدّث، مش رنّات متتالية
  collapse_key    text,

  status          public.push_status not null default 'queued',
  attempts        smallint not null default 0,

  -- ساعات الهدوء: بنأجّل لبدري الصبح بدل ما نلغي
  not_before      timestamptz not null default now(),

  created_at      timestamptz not null default now(),
  sent_at         timestamptz,
  error           text
);

create index push_outbox_due_idx on public.push_outbox (not_before)
  where status = 'queued';

create unique index push_outbox_collapse_idx
  on public.push_outbox (user_id, collapse_key)
  where status = 'queued' and collapse_key is not null;


-- -----------------------------------------------------------------------------
-- يستاهل رنة؟
--
-- القاعدة: الرنة لما **الطرف التاني مستني رد مني**. غير كده، الإشعار
-- بيستنى في التطبيق لحد ما المستخدم يفتحه.
--
--   match   → دي اللحظة كلها. من غيرها الغرفة بتفضل مقفولة.
--   message → الطرف التاني بيستنى رد
--   offer   → عرض رسمي، وله مهلة
--   meeting → لقاء متفق عليه — التأخير بيضيّع وقت الطرفين
--
-- والباقي **لأ**:
--   wishlist → مفيد بس مش عاجل، وبيرن كتير. يستنى في التطبيق.
--   nearby   → مطفي أصلاً بشكل افتراضي
--   review   → مش عاجل
--   system   → غالباً رفض منتج. مؤلم، وماينفعش يوصل كرنة مفاجئة
-- -----------------------------------------------------------------------------
create or replace function public.push_worthy(p_kind public.notification_kind)
returns boolean
language sql
immutable
as $$
  select p_kind in ('match', 'message', 'offer', 'meeting');
$$;


-- -----------------------------------------------------------------------------
-- المنطقة الزمنية من الدولة
--
-- مافيش عمود منطقة زمنية على الملف الشخصي، وإضافته معناها سؤال
-- المستخدم عن حاجة هو مش مهتم بيها. الدولة كافية.
--
-- ملاحظة صريحة: مصر رجّعت التوقيت الصيفي، يعني الإزاحة بتتغير ساعة
-- في الصيف. غلطة ساعة على حدود ساعات الهدوء مقبولة — أحسن بكتير
-- من إننا مانعملش ساعات هدوء أصلاً.
-- -----------------------------------------------------------------------------
create or replace function public.country_utc_offset(p_country char(2))
returns int
language sql
immutable
as $$
  select case p_country
    when 'EG' then 2
    when 'SA' then 3
    when 'KW' then 3
    when 'QA' then 3
    when 'BH' then 3
    when 'AE' then 4
    when 'OM' then 4
    else 3
  end;
$$;


-- -----------------------------------------------------------------------------
-- ساعات الهدوء: من 11 بالليل لـ 8 الصبح بالتوقيت المحلي
-- -----------------------------------------------------------------------------
create or replace function public.push_not_before(p_user uuid)
returns timestamptz
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  offset_h int;
  local_ts timestamptz;
  local_h  int;
begin
  select public.country_utc_offset(country_code) into offset_h
    from public.profiles where id = p_user;

  offset_h := coalesce(offset_h, 3);
  local_ts := now() + make_interval(hours => offset_h);
  local_h  := extract(hour from local_ts)::int;

  -- 08:00 لـ 22:59 محلي → دلوقتي
  if local_h >= 8 and local_h < 23 then
    return now();
  end if;

  -- غير كده → 8 الصبح المحلي الجاي، وبنرجّعها لتوقيت UTC
  return date_trunc('day', local_ts)
         + interval '8 hours'
         + case when local_h >= 23 then interval '1 day' else interval '0' end
         - make_interval(hours => offset_h);
end;
$$;


-- -----------------------------------------------------------------------------
-- الإدخال في الصندوق
--
-- الدمج بيشتغل بـ on conflict: لو فيه رنة مستنية بنفس المفتاح،
-- بنحدّث نصها بدل ما نضيف واحدة جديدة. يعني 20 رسالة في غرفة
-- بتوصل كرنة واحدة بآخر رسالة.
-- -----------------------------------------------------------------------------
create or replace function public.tg_enqueue_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  key text;
begin
  if not public.push_worthy(new.kind) then
    return new;
  end if;

  -- مفيش أجهزة مسجّلة → مفيش لازمة للصف
  if not exists (select 1 from public.push_tokens where user_id = new.user_id) then
    return new;
  end if;

  -- الدمج على مستوى الغرفة للرسايل، وعلى مستوى النوع لغير كده
  key := case
    when new.kind = 'message' and new.payload ? 'match_id'
      then 'message:' || (new.payload->>'match_id')
    else new.kind::text
  end;

  insert into public.push_outbox
    (user_id, notification_id, kind, title_ar, title_en,
     body_ar, body_en, payload, collapse_key, not_before)
  values
    (new.user_id, new.id, new.kind, new.title_ar, new.title_en,
     new.body_ar, new.body_en, new.payload, key,
     public.push_not_before(new.user_id))
  on conflict (user_id, collapse_key) where (status = 'queued' and collapse_key is not null)
  do update set
    title_ar = excluded.title_ar,
    title_en = excluded.title_en,
    body_ar  = excluded.body_ar,
    body_en  = excluded.body_en,
    payload  = excluded.payload,
    notification_id = excluded.notification_id,
    created_at = now();

  return new;
end;
$$;

create trigger notifications_enqueue_push
  after insert on public.notifications
  for each row execute function public.tg_enqueue_push();


-- =============================================================================
-- واجهة العامل
--
-- دالة الحافة بتنادي دي، بتبعت، وبترجّع النتيجة.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- الدفعة المستحقة
--
-- بتقفل الصفوف بـ skip locked عشان أكتر من عامل يشتغلوا مع بعض
-- من غير ما يبعتوا نفس الرنة مرتين.
-- -----------------------------------------------------------------------------
create or replace function public.push_claim_batch(p_limit int default 50)
returns table (
  job_id    uuid,
  user_id   uuid,
  kind      text,
  title_ar  text,
  title_en  text,
  body_ar   text,
  body_en   text,
  payload   jsonb,
  tokens    jsonb
)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  with claimed as (
    select o.id
      from public.push_outbox o
     where o.status = 'queued'
       and o.not_before <= now()
       and o.attempts < 3
     order by o.not_before
     limit greatest(1, least(p_limit, 200))
     for update skip locked
  ),
  bumped as (
    update public.push_outbox o
       set attempts = o.attempts + 1
      from claimed
     where o.id = claimed.id
    returning o.*
  )
  select b.id, b.user_id, b.kind::text,
         b.title_ar, b.title_en, b.body_ar, b.body_en, b.payload,
         coalesce(
           (select jsonb_agg(jsonb_build_object('token', t.token,
                                                'platform', t.platform))
              from public.push_tokens t where t.user_id = b.user_id),
           '[]'::jsonb)
    from bumped b;
end;
$$;


create or replace function public.push_mark(
  p_job    uuid,
  p_status public.push_status,
  p_error  text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.push_outbox
     set status  = p_status,
         error   = p_error,
         sent_at = case when p_status = 'sent' then now() else sent_at end
   where id = p_job;
end;
$$;


-- -----------------------------------------------------------------------------
-- تنظيف الرموز الميتة
--
-- جوجل بترجّع UNREGISTERED للرمز اللي التطبيق اتشال من عليه. من غير
-- المسح ده، الجدول بيكبر للأبد وكل إرسال بيضيع نداءات على أجهزة
-- مابقتش موجودة — وبنحسب إن الإشعار وصل وهو مأوصلش.
-- -----------------------------------------------------------------------------
create or replace function public.push_drop_token(p_token text)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.push_tokens where token = p_token;
$$;


-- -----------------------------------------------------------------------------
-- تسجيل جهاز
--
-- بيتنادى من التطبيق. الرمز بيتجدّد من فايربيز كل فترة، فالتسجيل
-- بيحصل كل مرة التطبيق بيفتح.
-- -----------------------------------------------------------------------------
create or replace function public.register_push_token(
  p_token    text,
  p_platform text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'auth_required' using errcode = '28000';
  end if;

  if p_platform not in ('ios', 'android', 'web') then
    raise exception 'bad_platform' using errcode = '22023';
  end if;

  -- الرمز الواحد لمستخدم واحد. لو حد تاني سجّل دخول على نفس الجهاز،
  -- الرمز لازم ينتقل ليه — وإلا إشعارات الأول بتوصل للتاني.
  delete from public.push_tokens where token = p_token and user_id <> me;

  insert into public.push_tokens (user_id, token, platform)
  values (me, p_token, p_platform)
  on conflict (user_id, token)
  do update set last_seen_at = now(), platform = excluded.platform;
end;
$$;


create or replace function public.unregister_push_token(p_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.push_tokens
   where token = p_token and user_id = auth.uid();
end;
$$;


-- =============================================================================
-- الحماية
-- =============================================================================
alter table public.push_outbox enable row level security;

-- الصندوق شغل خادم بحت — مفيش سياسة ولا صلاحية للعميل
revoke all on public.push_outbox from anon, authenticated;

revoke execute on function public.push_claim_batch(int) from public, anon, authenticated;
revoke execute on function public.push_mark(uuid, public.push_status, text) from public, anon, authenticated;
revoke execute on function public.push_drop_token(text) from public, anon, authenticated;

-- دي بس هي المتاحة للتطبيق
grant execute on function public.register_push_token(text, text) to authenticated;
grant execute on function public.unregister_push_token(text) to authenticated;


-- =============================================================================
-- التنظيف الدوري
-- =============================================================================
create or replace function public.purge_push_outbox()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  affected int;
begin
  with deleted as (
    delete from public.push_outbox
     where (status in ('sent', 'skipped') and created_at < now() - interval '7 days')
        or (status = 'failed' and created_at < now() - interval '30 days')
        -- اللي فشل 3 مرات مش هينجح في الرابعة
        or (status = 'queued' and attempts >= 3
            and created_at < now() - interval '1 day')
    returning id
  )
  select count(*) into affected from deleted;

  -- والأجهزة اللي مافتحتش التطبيق من 6 شهور
  delete from public.push_tokens
   where last_seen_at < now() - interval '6 months';

  return affected;
end;
$$;
