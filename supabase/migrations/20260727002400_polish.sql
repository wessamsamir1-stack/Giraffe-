-- =============================================================================
-- Giraffe — 24. تفاصيل مكمّلة
--
-- تلات حاجات صغيرة، كل واحدة فيهم بتقفل فجوة حقيقية:
--
--   1. **صور المنتج في شاشة المراجعة.** المراجع كان بيشوف «4 صور»
--      بس. يعني بنطلب منه يحكم على محتوى بصري من غير ما يشوفه.
--
--   2. **لغة الإشعار.** كل الرنّات كانت بالعربي، حتى للي جهازه
--      إنجليزي.
--
--   3. **تنبيه تأخّر الطابور.** لوحة المراجعة بتعرض أقدم حالة، بس
--      لازم حد يفتحها عشان يشوف. اللي بيفتحها كل يوم مش محتاج
--      تنبيه، واللي مش بيفتحها هو بالظبط اللي محتاجه.
-- =============================================================================

-- =============================================================================
-- 0. وقت دخول الطابور — عطل اتكشف من الاختبار
--
-- الطابور كان بيحسب مدة الانتظار من `updated_at`. والمشكلة إن فيه
-- محفّز `items_touch` بيحدّث العمود ده مع **أي** تعديل على المنتج.
--
-- يعني صاحب المنتج المعلّم يعدّل سعره → `updated_at` بيتحدّث →
-- المنتج بيرجع لآخر الطابور وبيبان كأنه لسه داخل، **وتنبيه التأخّر
-- مابيرنّش عليه أبداً**.
--
-- مش استغلال متعمّد بالضرورة — بس النتيجة إن أقدم الحالات هي اللي
-- بتضيع، وهي بالظبط اللي محتاجة الاهتمام.
--
-- الحل: عمود مخصص بيتظبط لما المنتج يدخل الطابور، ومابيتغيرش بعدها.
-- =============================================================================
alter table public.items
  add column if not exists moderation_queued_at timestamptz;

-- الحالات الموجودة دلوقتي: بنبدأ عدّادها من آخر تحديث معروف
update public.items
   set moderation_queued_at = updated_at
 where moderation = 'flagged' and moderation_queued_at is null;

create or replace function public.tg_stamp_moderation_queue()
returns trigger
language plpgsql
as $$
begin
  -- بيتظبط عند الدخول للطابور بس — مش مع كل تعديل
  if new.moderation = 'flagged'
     and (tg_op = 'INSERT' or old.moderation is distinct from 'flagged') then
    new.moderation_queued_at := now();
  elsif new.moderation <> 'flagged' then
    new.moderation_queued_at := null;
  end if;
  return new;
end;
$$;

-- قبل حارس الفحص عشان الحارس ممكن يرجّع القيم
drop trigger if exists items_stamp_queue on public.items;
create trigger items_stamp_queue
  before insert or update of moderation on public.items
  for each row execute function public.tg_stamp_moderation_queue();


-- -----------------------------------------------------------------------------
-- 1. الصور في طابور المراجعة
--
-- الدلو `item-photos` عام القراءة، فمفيش سياسة زيادة — بنرجّع
-- المسارات والتطبيق بيبني الروابط.
-- -----------------------------------------------------------------------------
-- الدالة بترجّع setof الـ view، فنوعها معتمد عليه — لازم تتشال الأول
-- وتتعاد بعد ما الـ view يتغيّر.
drop function if exists public.moderation_queue_page(text, int);
drop view if exists public.moderation_queue;

create view public.moderation_queue as
select
  i.id                as item_id,
  i.title,
  i.description,
  i.category_id,
  i.subcategory_id,
  i.owner_id,
  i.country_code,
  i.city_id,
  i.photo_count,
  i.moderation_note,
  public.flag_kind(i.moderation_note) as flag_kind,
  i.created_at,
  i.updated_at,
  i.moderation_queued_at,
  -- من وقت دخول الطابور، مش من آخر تعديل
  extract(epoch from (now() - coalesce(i.moderation_queued_at, i.updated_at)))
    / 60 as waiting_minutes,
  p.display_name      as owner_name,
  p.username          as owner_username,
  coalesce(s.trust_level, 'new') as owner_trust,
  coalesce(s.completed_trades, 0) as owner_trades,
  (select count(*) from public.reports r
    where r.target_type = 'item' and r.target_id = i.id
      and r.status in ('open', 'reviewing')) as open_reports,

  -- الصور بترتيبها. من غيرها المراجعة مستحيلة على منتج اتعلّم
  -- بسبب صوره أصلاً.
  coalesce(
    (select jsonb_agg(ph.storage_path order by ph.position)
       from public.item_photos ph where ph.item_id = i.id),
    '[]'::jsonb) as photos

from public.items i
join public.profiles p on p.id = i.owner_id
left join public.user_stats s on s.user_id = i.owner_id
where i.moderation = 'flagged';

alter view public.moderation_queue set (security_invoker = off);
revoke select on public.moderation_queue from authenticated;

create function public.moderation_queue_page(
  p_kind  text default 'content',
  p_limit int default 30
)
returns setof public.moderation_queue
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_staff(auth.uid()) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  return query
    select * from public.moderation_queue q
     where p_kind = 'all' or q.flag_kind = p_kind
     order by (q.open_reports > 0) desc, q.moderation_queued_at
     limit greatest(1, least(p_limit, 100));
end;
$$;


-- =============================================================================
-- 2. لغة الإشعار
--
-- اللغة خاصية **الجهاز** مش المستخدم: ممكن يكون عنده موبايل بالعربي
-- وتابلت بالإنجليزي، والرنة لازم توصل بلغة الجهاز اللي هتظهر عليه.
-- =============================================================================
alter table public.push_tokens
  add column if not exists lang char(2) not null default 'ar'
    check (lang in ('ar', 'en'));

-- النسخة القديمة (معاملين) لازم تتشال، وإلا كل نداء بمعاملين بيبقى
-- ملتبس بين التوقيعين — وبوستجرس بيرفض بدل ما يختار.
drop function if exists public.register_push_token(text, text);

create function public.register_push_token(
  p_token    text,
  p_platform text,
  p_lang     text default 'ar'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  me   uuid := auth.uid();
  lang char(2);
begin
  if me is null then
    raise exception 'auth_required' using errcode = '28000';
  end if;

  if p_platform not in ('ios', 'android', 'web') then
    raise exception 'bad_platform' using errcode = '22023';
  end if;

  -- أي لغة تانية بترجع للعربي — ده سوق مصر والخليج
  lang := case when lower(coalesce(p_lang, 'ar')) like 'en%' then 'en' else 'ar' end;

  delete from public.push_tokens where token = p_token and user_id <> me;

  insert into public.push_tokens (user_id, token, platform, lang)
  values (me, p_token, p_platform, lang)
  on conflict (user_id, token)
  do update set last_seen_at = now(),
                platform = excluded.platform,
                lang = excluded.lang;
end;
$$;

grant execute on function public.register_push_token(text, text, text)
  to authenticated;

-- الدفعة بترجّع لغة كل جهاز عشان العامل يختار النص المناسب
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
                                                'platform', t.platform,
                                                'lang', t.lang))
              from public.push_tokens t where t.user_id = b.user_id),
           '[]'::jsonb)
    from bumped b;
end;
$$;

revoke execute on function public.push_claim_batch(int) from public, anon, authenticated;


-- =============================================================================
-- 3. تنبيه تأخّر الطابور
--
-- اللوحة بتعرض أقدم حالة مستنية — بس لازم حد يفتحها عشان يشوف.
-- واللي بيفتحها كل يوم مش محتاج التنبيه، واللي مش بيفتحها هو بالظبط
-- اللي محتاجه.
--
-- ملاحظة على العتبة: 24 ساعة مش رقم عشوائي. المستخدم اللي رفع منتج
-- واستنى يوم كامل من غير رد بيفترض إن التطبيق ميت — وبيسيبه.
-- =============================================================================
create or replace function public.moderation_sla_check(p_hours int default 24)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  oldest_min int;
  waiting    int;
  target     record;
  sent       int := 0;
begin
  select max(waiting_minutes)::int,
         count(*) filter (where flag_kind = 'content')::int
    into oldest_min, waiting
    from public.moderation_queue
   where flag_kind = 'content';

  if coalesce(oldest_min, 0) < p_hours * 60 then
    return 0;
  end if;

  -- ---------------------------------------------------------------------------
  -- منع التكرار: التنبيه بيتبعت مرة كل 6 ساعات على الأكتر.
  --
  -- من غير الشرط ده، التنبيه بيرن كل ساعة على نفس الحالة — والمراجع
  -- بيتعلّم يتجاهله، وساعتها بيبقى أسوأ من مفيش تنبيه.
  -- ---------------------------------------------------------------------------
  if exists (
    select 1 from public.notifications
     where kind = 'system'
       and payload->>'alert' = 'moderation_sla'
       and created_at > now() - interval '6 hours'
  ) then
    return 0;
  end if;

  for target in
    select user_id from public.staff where revoked_at is null
  loop
    perform public.notify_user(
      target.user_id,
      'system',
      'طابور المراجعة متأخر — أقدم حالة مستنية ' || (oldest_min / 60) || ' ساعة',
      'Review queue is behind — oldest item waiting ' || (oldest_min / 60) || 'h',
      jsonb_build_object(
        'alert', 'moderation_sla',
        'oldest_hours', oldest_min / 60,
        'waiting', waiting
      )
    );
    sent := sent + 1;
  end loop;

  return sent;
end;
$$;

revoke execute on function public.moderation_sla_check(int)
  from public, anon, authenticated;


-- -----------------------------------------------------------------------------
-- الجدولة — كل ساعة
-- -----------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobname) from cron.job
      where jobname = 'giraffe-moderation-sla';

    perform cron.schedule(
      'giraffe-moderation-sla', '20 * * * *',
      $job$ select public.moderation_sla_check(24) $job$);
  end if;
end $$;
