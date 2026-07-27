-- =============================================================================
-- Giraffe — 22. لوحة المراجعة البشرية
--
-- إحنا عملنا الفحص **يفشل بأمان**: أي تعثر والمنتج بيتعلّم flagged
-- ويستنى مراجعة بشرية. وده قرار صح.
--
-- بس ماكانش فيه مراجعة بشرية. يعني عملنا طابور محدش يقدر يفتحه —
-- والمنتجات هتفضل تتكدس فيه وأصحابها مستنيين رد مش جاي.
--
-- الملف ده بيقفل الدايرة.
--
-- -----------------------------------------------------------------------------
-- الفكرة الحاكمة: **مش كل flagged محتاج بني آدم**
--
-- الطابور فيه نوعين مختلفين تماماً اتحطوا مع بعض:
--
--   1. المشكوك فيه فعلاً — الموديل شاف حاجة وقال «راجعوا ده».
--      ده محتاج **حكم بشري**.
--
--   2. النظام اللي تعثّر — السقف اتعدى، أو الموديل مارّدش.
--      ده مش محتاج حكم، ده محتاج **إعادة محاولة**.
--
-- خلطهم مع بعض بيهدر أندر مورد عندنا: انتباه المراجع. لو 90% من
-- الطابور أعطال نظام، المراجع هيقلب على الوضع الآلي وهيعدّي الحالة
-- الحقيقية اللي كانت محتاجاه.
--
-- عشان كده الطابور هنا **مقسوم**.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- من هو المراجع؟
--
-- جدول منفصل مش عمود في profiles. السبب: العمود في profiles معرّض
-- لسياسات التعديل بتاعة المستخدم على ملفه — وأي غلطة في سياسة بتخلي
-- المستخدم يرقّي نفسه. جدول منفصل مالوش أي سياسة كتابة خالص.
-- -----------------------------------------------------------------------------
create type public.staff_role as enum ('moderator', 'admin');

create table public.staff (
  user_id     uuid primary key references public.profiles(id) on delete cascade,
  role        public.staff_role not null default 'moderator',
  granted_by  uuid references public.profiles(id) on delete set null,
  granted_at  timestamptz not null default now(),
  revoked_at  timestamptz
);

comment on table public.staff is
  'الصلاحيات بتتزرع من لوحة سوبابيز بس. مفيش سياسة كتابة — ولا حتى للأدمن.';

create or replace function public.is_staff(p_user uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.staff
     where user_id = p_user and revoked_at is null
  );
$$;


-- =============================================================================
-- سجل القرارات — يُكتب ولا يُعدّل
--
-- كل قرار مراجعة بيتسجل هنا قبل ما يتنفّذ. من غير السجل ده مافيش
-- محاسبة: مانعرفش مين وافق على إيه، ولا نقدر نراجع مراجع بيغلط.
-- =============================================================================
create table public.moderation_decisions (
  id            uuid primary key default gen_random_uuid(),
  item_id       uuid references public.items(id) on delete set null,
  report_id     uuid references public.reports(id) on delete set null,
  moderator_id  uuid not null references public.profiles(id),
  decision      text not null check (decision in ('approved', 'rejected', 'dismissed')),
  reason        text,
  -- بنحتفظ بنسخة من قرار الآلة عشان نقدر نقيس دقتها بعدين
  ai_decision   text,
  ai_note       text,
  decided_at    timestamptz not null default now(),
  -- قد إيه استنى المستخدم؟ ده مؤشر الخدمة الحقيقي
  waited_minutes int
);

create index moderation_decisions_mod_idx  on public.moderation_decisions (moderator_id, decided_at desc);
create index moderation_decisions_item_idx on public.moderation_decisions (item_id);

comment on table public.moderation_decisions is
  'سجل مُلحَق فقط. مفيش update ولا delete — لا للمراجع ولا للأدمن.';


-- =============================================================================
-- تصنيف سبب التعليم
--
-- الملاحظات دي بتتكتب من دوال الحافة. بنترجمها لتصنيف واضح عشان
-- نقدر نقسّم الطابور.
-- =============================================================================
create or replace function public.flag_kind(p_note text)
returns text
language sql
immutable
as $$
  select case
    -- النظام هو اللي تعثّر — مش حكم على المحتوى
    when p_note in ('moderation_unavailable', 'awaiting_review',
                    'quota_check_failed', 'user_budget_exceeded',
                    'global_budget_exceeded')
      then 'system'
    when p_note is null then 'unknown'
    else 'content'          -- الموديل شاف حاجة فعلاً
  end;
$$;


-- =============================================================================
-- الطابور
--
-- الترتيب **الأقدم الأول** عن قصد. الترتيب بالأحدث بيخلي الحالات
-- القديمة تستنى للأبد — وهي بالظبط اللي المستخدم زهق من انتظارها.
-- =============================================================================
create or replace view public.moderation_queue as
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
  extract(epoch from (now() - i.updated_at)) / 60 as waiting_minutes,
  p.display_name      as owner_name,
  p.username          as owner_username,
  coalesce(s.trust_level, 'new') as owner_trust,
  coalesce(s.completed_trades, 0) as owner_trades,
  -- عدد البلاغات على المنتج ده — إشارة قوية للأولوية
  (select count(*) from public.reports r
    where r.target_type = 'item' and r.target_id = i.id
      and r.status in ('open', 'reviewing')) as open_reports
from public.items i
join public.profiles p on p.id = i.owner_id
left join public.user_stats s on s.user_id = i.owner_id
where i.moderation = 'flagged';

comment on view public.moderation_queue is
  'الأقدم الأول. flag_kind بيفرّق بين اللي محتاج حكم واللي محتاج إعادة محاولة.';


-- =============================================================================
-- القرار
--
-- الدالة دي هي **الطريق الوحيد** للمراجعة. الكتابة المباشرة على
-- items ممنوعة بالحارس في ملف 19، والسجل هنا بيتكتب قبل التنفيذ.
-- =============================================================================
create or replace function public.moderate_decide(
  p_item     uuid,
  p_decision text,
  p_reason   text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  me      uuid := auth.uid();
  it      public.items;
  waited  int;
begin
  if me is null or not public.is_staff(me) then
    return jsonb_build_object('ok', false, 'error', 'not_authorized');
  end if;

  if p_decision not in ('approved', 'rejected') then
    return jsonb_build_object('ok', false, 'error', 'bad_decision');
  end if;

  -- الرفض من غير سبب ممنوع: المستخدم بيتبلّغ بالسبب، ومن غيره
  -- بيتعلّم إن القرار عشوائي — وبيعيد نفس الغلطة.
  if p_decision = 'rejected'
     and (p_reason is null or length(trim(p_reason)) < 3) then
    return jsonb_build_object('ok', false, 'error', 'reason_required');
  end if;

  select * into it from public.items where id = p_item;
  if it is null then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;

  -- -------------------------------------------------------------------------
  -- تعارض المصالح
  --
  -- المراجع مايراجعش منتجه. القاعدة دي بتبان بديهية لحد ما حد يستعملها.
  -- -------------------------------------------------------------------------
  if it.owner_id = me then
    return jsonb_build_object('ok', false, 'error', 'own_item');
  end if;

  if it.moderation <> 'flagged' then
    -- حد تاني خلصها بالفعل — مش خطأ، بس مانكتبش قرار تاني
    return jsonb_build_object('ok', true, 'already', true,
                              'current', it.moderation::text);
  end if;

  waited := floor(extract(epoch from (now() - it.updated_at)) / 60);

  insert into public.moderation_decisions
    (item_id, moderator_id, decision, reason, ai_decision, ai_note, waited_minutes)
  values
    (p_item, me, p_decision, p_reason, 'flagged', it.moderation_note, waited);

  -- ---------------------------------------------------------------------------
  -- الحارس في ملف 19 بيجمّد أعمدة الفحص لأي فاعل عنده auth.uid().
  -- ده صح — بس المراجع لازم يعدّي.
  --
  -- بنستعمل إعداد محلي للمعاملة بدل ما نستثني المراجعين في الحارس
  -- نفسه. الفرق مهم: الاستثناء بالدور كان هيخلي المراجع يقدر يعدّل
  -- items مباشرةً ويتخطى السجل ده. الإعداد ده مابيتظبطش إلا من
  -- جوه الدالة دي، وبيموت مع المعاملة.
  -- ---------------------------------------------------------------------------
  perform set_config('giraffe.moderation_ctx', 'moderate_decide', true);

  perform public.apply_moderation(p_item, p_decision::public.moderation_status,
                                  p_reason);

  perform set_config('giraffe.moderation_ctx', '', true);

  -- البلاغات المفتوحة على المنتج ده اتقفلت بالقرار
  update public.reports
     set status = (case when p_decision = 'rejected' then 'actioned'
                        else 'dismissed' end)::public.report_status,
         handled_by = me,
         handled_at = now()
   where target_type = 'item' and target_id = p_item
     and status in ('open', 'reviewing');

  return jsonb_build_object('ok', true, 'decision', p_decision,
                            'waited_minutes', waited);
end;
$$;


-- =============================================================================
-- إعادة المحاولة — للحالات اللي النظام تعثّر فيها
--
-- دي مش قرار بشري. دي بترجّع المنتج للطابور الآلي عشان دالة الحافة
-- تفحصه تاني. المراجع بيضغط زر واحد لكل الدفعة بدل ما يقرا منتجات
-- محدش حكم عليها أصلاً.
-- =============================================================================
create or replace function public.moderate_requeue_system_flags(p_limit int default 100)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  affected int;
begin
  if not public.is_staff(auth.uid()) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  perform set_config('giraffe.moderation_ctx', 'moderate_decide', true);

  with due as (
    select id from public.items
     where moderation = 'flagged'
       and public.flag_kind(moderation_note) = 'system'
     order by updated_at
     limit p_limit
  )
  update public.items i
     set moderation = 'pending',
         moderation_note = null
    from due
   where i.id = due.id;

  get diagnostics affected = row_count;

  perform set_config('giraffe.moderation_ctx', '', true);
  return affected;
end;
$$;


-- =============================================================================
-- مؤشرات الطابور
--
-- الرقم الوحيد اللي بيهم فعلاً هو **أقدم حالة مستنية**. المتوسط
-- بيخبّي الحالة اللي نسيناها من أسبوع.
-- =============================================================================
create or replace function public.moderation_stats()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select case when not public.is_staff(auth.uid()) then
    jsonb_build_object('ok', false, 'error', 'not_authorized')
  else (
    select jsonb_build_object(
      'ok', true,
      'pending_content', count(*) filter (where flag_kind = 'content'),
      'pending_system',  count(*) filter (where flag_kind = 'system'),
      'pending_unknown', count(*) filter (where flag_kind = 'unknown'),
      'oldest_minutes',  coalesce(max(waiting_minutes)::int, 0),
      'with_reports',    count(*) filter (where open_reports > 0),
      'decided_today', (
        select count(*) from public.moderation_decisions
         where decided_at >= date_trunc('day', now())
      )
    )
    from public.moderation_queue
  ) end;
$$;


-- =============================================================================
-- الحماية
-- =============================================================================
alter table public.staff                enable row level security;
alter table public.moderation_decisions enable row level security;

-- الطاقم بيشوف الطاقم. المستخدم العادي مايعرفش مين المراجعين أصلاً —
-- معرفة دي بتخلي الناس تحاول تتواصل معاهم خارج النظام.
grant select on public.staff to authenticated;
create policy staff_read_staff on public.staff
  for select using (public.is_staff(auth.uid()));

-- مفيش سياسة insert/update/delete خالص — الصلاحيات من لوحة سوبابيز بس

grant select on public.moderation_decisions to authenticated;
create policy decisions_read_staff on public.moderation_decisions
  for select using (public.is_staff(auth.uid()));

-- السجل مُلحَق فقط: مفيش سياسة كتابة، والدالة بس هي اللي بتكتب
-- (security definer فبتتخطى RLS).

grant select on public.moderation_queue to authenticated;

-- الـ view بيرث حماية الجداول اللي وراه، وitems فيها سياسة قراءة
-- عامة للمعتمد بس — يعني المعلّم مش هيبان. فبنخليه security definer
-- ونحط الفحص جواه.
alter view public.moderation_queue set (security_invoker = off);

-- وبنقفل الوصول على غير الطاقم بدالة وسيطة بدل ما نسيب الـ view مكشوف
revoke select on public.moderation_queue from authenticated;

create or replace function public.moderation_queue_page(
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
     -- الأقدم الأول، والمُبلَّغ عنه قبل غيره
     order by (q.open_reports > 0) desc, q.updated_at
     limit greatest(1, least(p_limit, 100));
end;
$$;

revoke execute on function public.moderate_requeue_system_flags(int)
  from public;
grant execute on function public.moderate_requeue_system_flags(int)
  to authenticated;


-- =============================================================================
-- تعديل الحارس عشان يعرف سياق المراجعة
--
-- بنعيد تعريف الدالة من ملف 19 وبنضيف شرط واحد.
-- =============================================================================
create or replace function public.tg_guard_item_moderation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- الخادم بمفتاح الخدمة
  if auth.uid() is null then
    return new;
  end if;

  -- ---------------------------------------------------------------------------
  -- سياق المراجعة البشرية.
  --
  -- الإعداد ده بيتظبط من moderate_decide بس، وبـ is_local => true
  -- يعني بيموت آخر المعاملة. والعميل مايقدرش يظبطه: PostgREST بيمرر
  -- إعدادات request.* بس من الرؤوس، و set_config مش دالة مكشوفة.
  --
  -- عملناها كده بدل ما نستثني المراجعين بالدور، لأن الاستثناء بالدور
  -- كان هيخلي المراجع يعدّل items مباشرةً ويتخطى سجل القرارات.
  -- ---------------------------------------------------------------------------
  if coalesce(current_setting('giraffe.moderation_ctx', true), '') = 'moderate_decide' then
    return new;
  end if;

  new.moderation      := old.moderation;
  new.moderation_note := old.moderation_note;
  new.published_at    := old.published_at;

  if old.moderation = 'approved' and (
       new.title       is distinct from old.title
    or new.description is distinct from old.description
    or new.category_id is distinct from old.category_id
  ) then
    new.moderation   := 'pending';
    new.published_at := null;
    if new.status = 'available' then
      new.status := 'pending';
    end if;
  end if;

  if new.status = 'available' and new.moderation <> 'approved' then
    new.status := 'pending';
  end if;

  return new;
end;
$$;
