-- =============================================================================
-- Giraffe — 07. السحبات والماتشات
-- =============================================================================

-- -----------------------------------------------------------------------------
-- السحبات
--
-- ملاحظة مهمة: السحبة **مش على منتج** — هي على **صفقة**.
-- المستخدم بيقول "أنا موافق أدي منتجي X مقابل منتجهم Y"، مش
-- "المنتج Y عاجبني". وده الفرق الجوهري بين Giraffe وأي سوق إلكتروني.
-- -----------------------------------------------------------------------------
create table public.swipes (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  target_item_id  uuid not null references public.items(id) on delete cascade,
  offered_item_id uuid not null references public.items(id) on delete cascade,
  intent          public.swipe_intent not null,
  compatibility   smallint,
  created_at      timestamptz not null default now(),

  -- سحبة واحدة لكل منتج مستهدف — مانعرضش نفس المنتج تاني
  unique (user_id, target_item_id)
);

create index swipes_user_idx    on public.swipes (user_id, created_at desc);
create index swipes_target_idx  on public.swipes (target_item_id)
  where intent <> 'skip';
create index swipes_recent_idx  on public.swipes (user_id, created_at desc)
  where intent = 'skip';

-- -----------------------------------------------------------------------------
-- الماتشات — وهي نفسها غرف المقايضة
--
-- user_a دايماً الـ uuid الأصغر عشان نضمن عدم تكرار الزوج.
-- -----------------------------------------------------------------------------
create table public.matches (
  id              uuid primary key default gen_random_uuid(),

  user_a          uuid not null references public.profiles(id) on delete cascade,
  user_b          uuid not null references public.profiles(id) on delete cascade,
  item_a          uuid not null references public.items(id) on delete cascade,
  item_b          uuid not null references public.items(id) on delete cascade,

  stage           public.trade_stage not null default 'negotiating',

  -- ---------------------------------------------------------------------------
  -- قواعد إغلاق الغرفة
  --
  -- الأصل: الغرفة ما بتختفيش بمزاج طرف واحد — عشان مانسمحش بالهروب من
  -- الصفقات بعد الاتفاق.
  --
  -- الاستثناء المطلق: **الحظر بيقفلها فوراً وبدون أي شرط**.
  -- من غير الاستثناء ده الغرفة بتبقى vector تحرش، وبتترفض من مراجعة
  -- متجر آبل تحت بند حماية المستخدم في المحتوى المُنتَج من المستخدمين.
  -- ---------------------------------------------------------------------------
  a_requested_close boolean not null default false,
  b_requested_close boolean not null default false,
  closed_by_block   boolean not null default false,
  frozen_by_report  boolean not null default false,

  archived_at     timestamptz,
  closed_at       timestamptz,

  last_activity_at timestamptz not null default now(),
  created_at      timestamptz not null default now(),

  constraint matches_user_order check (user_a < user_b),
  constraint matches_distinct_users check (user_a <> user_b),
  unique (user_a, user_b, item_a, item_b)
);

create index matches_user_a_idx on public.matches (user_a, last_activity_at desc);
create index matches_user_b_idx on public.matches (user_b, last_activity_at desc);
create index matches_stage_idx  on public.matches (stage);
create index matches_stale_idx  on public.matches (last_activity_at)
  where archived_at is null and closed_at is null;

-- -----------------------------------------------------------------------------
-- هل المستخدم طرف في الماتش؟ — تستخدمها كل سياسات RLS للغرفة
-- -----------------------------------------------------------------------------
create or replace function public.is_match_member(p_match uuid, p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.matches m
     where m.id = p_match
       and (m.user_a = p_user or m.user_b = p_user)
  )
$$;

-- -----------------------------------------------------------------------------
-- عدد الغرف النشطة
--
-- السقف 10 غرف. ده بديل فكرة "منع فتح شاتات جديدة لو عندك غرف مفتوحة"
-- اللي كانت في الـ spec الأصلي — الفكرة دي كانت هتعاقب المستخدم الأنشط،
-- وهو أهم أصل عندنا لأنه اللي بيولّد السيولة.
-- -----------------------------------------------------------------------------
create or replace function public.active_room_count(p_user uuid)
returns int
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::int
    from public.matches m
   where (m.user_a = p_user or m.user_b = p_user)
     and m.archived_at is null
     and m.closed_at is null
     and m.stage not in ('completed', 'cancelled')
$$;

-- -----------------------------------------------------------------------------
-- أول ما يتعمل ماتش: المنتجان يتحولوا لحالة تفاوض
-- -----------------------------------------------------------------------------
create or replace function public.tg_match_created()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.items
     set status = 'negotiating'
   where id in (new.item_a, new.item_b)
     and status = 'available';

  insert into public.messages (match_id, sender_id, kind, body)
  values (new.id, null, 'system', 'match_created');

  return new;
end;
$$;

-- المحفّز نفسه بيتعلّق بعد إنشاء جدول الرسائل في الملف التالي.
