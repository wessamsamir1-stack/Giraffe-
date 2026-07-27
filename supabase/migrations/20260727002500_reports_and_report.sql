-- =============================================================================
-- Giraffe — 25. طابور البلاغات وتقرير دقة الفحص
--
-- حاجتين:
--
--   1. **بلاغات المستخدمين والرسايل.** لوحة المراجعة كانت بتشوف
--      المنتجات بس. البلاغ على مستخدم أو رسالة كان بيتسجّل في الجدول
--      ومحدش بيفتحه — نفس مشكلة الطابور المقفول اللي حلّيناها للمنتجات.
--
--   2. **تقرير دقة الفحص.** إحنا بنسجّل قرار الآلة جنب قرار البني آدم
--      من ملف 22، بس مفيش حاجة بتقرا السجل ده. والرقم اللي جواه مهم:
--      لو الموديل بيعلّم حاجات المراجع بيوافق عليها، يبقى بيهدر أغلى
--      مورد عندنا.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- إخفاء الرسالة بدل حذفها
--
-- الحذف بيكسر السجل، والسجل ده بيتستعمل في النزاعات. فالرسالة
-- المخالفة بتتخفي ويفضل معروف إنها كانت موجودة واتشالت.
-- -----------------------------------------------------------------------------
alter table public.messages
  add column if not exists removed_at timestamptz,
  add column if not exists removed_by uuid references public.profiles(id);

comment on column public.messages.removed_at is
  'الرسالة اتخفت بقرار مراجعة. النص بيفضل مخزّن للنزاعات.';


-- =============================================================================
-- طابور البلاغات
--
-- بلاغات المنتجات مش هنا — دي بتظهر مع المنتج نفسه في طابور المراجعة
-- وبتتقفل مع قراره. تكرارها هنا معناه إن المراجع يحكم على نفس الحاجة
-- مرتين.
-- =============================================================================
create or replace view public.report_queue as
select
  r.id            as report_id,
  r.target_type,
  r.target_id,
  r.reason,
  r.details,
  r.evidence_paths,
  r.created_at,
  extract(epoch from (now() - r.created_at)) / 60 as waiting_minutes,

  rp.display_name as reporter_name,
  rp.username     as reporter_username,

  -- كام بلاغ مفتوح على نفس الهدف؟ الرقم ده أقوى إشارة عندنا:
  -- خمس ناس مختلفين بلّغوا على نفس الشخص مش صدفة.
  (select count(*) from public.reports r2
    where r2.target_type = r.target_type
      and r2.target_id = r.target_id
      and r2.status in ('open', 'reviewing')) as reports_on_target,

  -- بيانات الهدف حسب نوعه
  case r.target_type
    when 'user' then (
      select jsonb_build_object(
        'display_name', p.display_name,
        'username', p.username,
        'is_banned', p.is_banned,
        'banned_until', p.banned_until,
        'trust', coalesce(s.trust_level::text, 'new'),
        'trades', coalesce(s.completed_trades, 0))
        from public.profiles p
        left join public.user_stats s on s.user_id = p.id
       where p.id = r.target_id)
    when 'message' then (
      select jsonb_build_object(
        'body', m.body,
        'kind', m.kind::text,
        'image_path', m.image_path,
        'match_id', m.match_id,
        'sender_id', m.sender_id,
        'removed_at', m.removed_at,
        'created_at', m.created_at)
        from public.messages m where m.id = r.target_id)
    else '{}'::jsonb
  end as target
from public.reports r
join public.profiles rp on rp.id = r.reporter_id
where r.status in ('open', 'reviewing')
  and r.target_type in ('user', 'message');

alter view public.report_queue set (security_invoker = off);
revoke select on public.report_queue from anon, authenticated;


create or replace function public.report_queue_page(p_limit int default 30)
returns setof public.report_queue
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
    select * from public.report_queue q
     -- الأكتر بلاغات الأول، وبعدين الأقدم
     order by q.reports_on_target desc, q.created_at
     limit greatest(1, least(p_limit, 100));
end;
$$;


-- =============================================================================
-- القرار على بلاغ
--
-- أربع نتايج، مرتبة بالشدّة:
--
--   dismissed → البلاغ مش في محله
--   warned    → تنبيه لصاحب السلوك، من غير عقوبة
--   removed   → الرسالة بتتخفي
--   banned    → المستخدم بيتوقف
-- =============================================================================
create or replace function public.report_decide(
  p_report uuid,
  p_action text,
  p_reason text default null,
  p_days   int default 7
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  me      uuid := auth.uid();
  rep     public.reports;
  is_admin boolean;
  target_user uuid;
begin
  if me is null or not public.is_staff(me) then
    return jsonb_build_object('ok', false, 'error', 'not_authorized');
  end if;

  if p_action not in ('dismissed', 'warned', 'removed', 'banned') then
    return jsonb_build_object('ok', false, 'error', 'bad_action');
  end if;

  -- أي إجراء عقابي لازم معاه سبب. الرفض بس هو اللي بيعدّي من غيره.
  if p_action <> 'dismissed'
     and (p_reason is null or length(trim(p_reason)) < 3) then
    return jsonb_build_object('ok', false, 'error', 'reason_required');
  end if;

  select * into rep from public.reports where id = p_report;
  if rep is null then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;

  if rep.status not in ('open', 'reviewing') then
    return jsonb_build_object('ok', true, 'already', true);
  end if;

  -- ---------------------------------------------------------------------------
  -- تعارض المصالح — نفس قاعدة المنتجات
  --
  -- المراجع مايحكمش على بلاغ هو قدّمه، ولا على بلاغ ضده هو.
  -- ---------------------------------------------------------------------------
  if rep.reporter_id = me then
    return jsonb_build_object('ok', false, 'error', 'own_report');
  end if;

  target_user := case
    when rep.target_type = 'user' then rep.target_id
    when rep.target_type = 'message' then
      (select sender_id from public.messages where id = rep.target_id)
    else null
  end;

  if target_user = me then
    return jsonb_build_object('ok', false, 'error', 'own_report');
  end if;

  select role = 'admin' into is_admin
    from public.staff where user_id = me and revoked_at is null;

  -- ---------------------------------------------------------------------------
  -- الإيقاف الدائم للأدمن بس
  --
  -- الفرق بين إيقاف أسبوع وإيقاف دائم إن التاني مالوش رجعة عملياً.
  -- المراجع العادي يقدر يوقف مؤقتاً، والدائم محتاج قرار أعلى.
  -- ---------------------------------------------------------------------------
  if p_action = 'banned' and p_days is null and not coalesce(is_admin, false) then
    return jsonb_build_object('ok', false, 'error', 'admin_required');
  end if;

  -- ---------------------------------------------------------------------------
  -- التنفيذ
  -- ---------------------------------------------------------------------------
  if p_action = 'removed' and rep.target_type = 'message' then
    update public.messages
       set removed_at = now(), removed_by = me
     where id = rep.target_id and removed_at is null;

  elsif p_action = 'banned' and target_user is not null then
    update public.profiles
       set is_banned = true,
           banned_until = case when p_days is null
                               then null
                               else now() + make_interval(days => p_days) end
     where id = target_user;

    perform public.notify_user(
      target_user, 'system',
      'حسابك اتوقف: ' || p_reason,
      'Your account was suspended: ' || p_reason,
      jsonb_build_object('until', (now() + make_interval(days => coalesce(p_days, 0)))));

  elsif p_action = 'warned' and target_user is not null then
    perform public.notify_user(
      target_user, 'system',
      'تنبيه: ' || p_reason,
      'Warning: ' || p_reason,
      jsonb_build_object('warning', true));
  end if;

  -- ---------------------------------------------------------------------------
  -- كل البلاغات المفتوحة على نفس الهدف بتتقفل بالقرار ده
  --
  -- من غير كده، خمس بلاغات على نفس الشخص معناها المراجع يحكم خمس
  -- مرات على نفس السلوك.
  -- ---------------------------------------------------------------------------
  update public.reports
     set status = case when p_action = 'dismissed' then 'dismissed'
                       else 'actioned' end::public.report_status,
         handled_by = me,
         handled_at = now()
   where target_type = rep.target_type
     and target_id = rep.target_id
     and status in ('open', 'reviewing');

  insert into public.moderation_decisions
    (report_id, moderator_id, decision, reason, waited_minutes)
  values
    (p_report, me,
     case when p_action = 'dismissed' then 'dismissed' else 'rejected' end,
     p_action || ': ' || coalesce(p_reason, ''),
     floor(extract(epoch from (now() - rep.created_at)) / 60));

  return jsonb_build_object('ok', true, 'action', p_action);
end;
$$;

revoke execute on function public.report_decide(uuid, text, text, int)
  from public, anon;
grant execute on function public.report_decide(uuid, text, text, int)
  to authenticated;

grant execute on function public.report_queue_page(int) to authenticated;


-- =============================================================================
-- تقرير دقة الفحص
--
-- إحنا بنسجّل قرار الآلة جنب قرار البني آدم من ملف 22 — بس مفيش حاجة
-- بتقرا السجل ده.
--
-- والرقم اللي جواه هو **معدل التعليم الخاطئ**: من كل المنتجات اللي
-- الموديل علّمها، كام واحد المراجع وافق عليه؟
--
-- الرقم ده لو عالي، الموديل بيهدر أغلى مورد عندنا — انتباه المراجع —
-- على منتجات سليمة. ولو صفر، غالباً الموديل متساهل زيادة ومابيعلّمش
-- حاجات المفروض يعلّمها.
--
-- مفيش رقم «صح» مطلق، بس الاتجاه بيقول لنا نشدّ ولا نرخي.
-- =============================================================================
create or replace function public.moderation_report(p_days int default 30)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  since timestamptz := now() - make_interval(days => greatest(1, p_days));
  total int;
  approved int;
  rejected int;
begin
  if not public.is_staff(auth.uid()) then
    return jsonb_build_object('ok', false, 'error', 'not_authorized');
  end if;

  select count(*) filter (where item_id is not null),
         count(*) filter (where item_id is not null and decision = 'approved'),
         count(*) filter (where item_id is not null and decision = 'rejected')
    into total, approved, rejected
    from public.moderation_decisions
   where decided_at >= since;

  return jsonb_build_object(
    'ok', true,
    'days', p_days,
    'decisions', total,
    'approved', approved,
    'rejected', rejected,

    -- المنتجات اللي الموديل علّمها والمراجع وافق عليها.
    -- ده تعب ضايع — الموديل شكّ في حاجة سليمة.
    'false_flag_rate', case when total > 0
      then round(approved::numeric / total, 3) else null end,

    -- زمن الرد: الوسيط والأسوأ. الوسيط بيقول التجربة العادية،
    -- والـ 90 بيقول أسوأ تجربة المستخدم ممكن يعيشها.
    'median_wait_minutes', (
      select percentile_cont(0.5) within group (order by waited_minutes)
        from public.moderation_decisions
       where decided_at >= since and waited_minutes is not null),
    'p90_wait_minutes', (
      select percentile_cont(0.9) within group (order by waited_minutes)
        from public.moderation_decisions
       where decided_at >= since and waited_minutes is not null),

    -- الإنتاجية لكل مراجع — مش لتقييمه، لمعرفة إحنا محتاجين كام واحد
    'by_moderator', coalesce((
      select jsonb_agg(jsonb_build_object(
               'moderator_id', d.moderator_id,
               'name', p.display_name,
               'decisions', d.n))
        from (select moderator_id, count(*) as n
                from public.moderation_decisions
               where decided_at >= since
               group by moderator_id) d
        join public.profiles p on p.id = d.moderator_id), '[]'::jsonb),

    -- أكتر أسباب التعليم تكراراً — بيوري إحنا بنعلّم على إيه فعلاً
    'top_flags', coalesce((
      select jsonb_agg(jsonb_build_object('note', t.ai_note, 'count', t.n))
        from (select ai_note, count(*) as n
                from public.moderation_decisions
               where decided_at >= since and ai_note is not null
               group by ai_note
               order by count(*) desc
               limit 5) t), '[]'::jsonb),

    'reports_handled', (
      select count(*) from public.moderation_decisions
       where decided_at >= since and report_id is not null)
  );
end;
$$;

grant execute on function public.moderation_report(int) to authenticated;
