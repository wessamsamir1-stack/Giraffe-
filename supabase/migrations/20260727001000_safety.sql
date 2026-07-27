-- =============================================================================
-- Giraffe — 10. الأمان: الحظر والكتم والبلاغات والنزاعات
-- =============================================================================

-- -----------------------------------------------------------------------------
-- الحظر
--
-- الحظر عندنا **بيكسر كل القواعد التانية بدون استثناء**:
-- بيقفل غرفة المقايضة فوراً حتى لو الصفقة متفق عليها، وبيخفي منتجات
-- الطرفين عن بعض في الـ deck والسوق.
--
-- من غير الاستثناء ده، قاعدة "الغرفة ما بتختفيش" بتتحول لأداة تحرش.
-- -----------------------------------------------------------------------------
create table public.blocks (
  blocker_id  uuid not null references public.profiles(id) on delete cascade,
  blocked_id  uuid not null references public.profiles(id) on delete cascade,
  reason      text,
  created_at  timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint blocks_no_self check (blocker_id <> blocked_id)
);

create index blocks_blocked_idx on public.blocks (blocked_id);

create table public.mutes (
  muter_id    uuid not null references public.profiles(id) on delete cascade,
  muted_id    uuid not null references public.profiles(id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (muter_id, muted_id),
  constraint mutes_no_self check (muter_id <> muted_id)
);

-- -----------------------------------------------------------------------------
-- هل فيه حظر بين الاتنين في أي اتجاه؟
-- -----------------------------------------------------------------------------
create or replace function public.blocked_between(p_one uuid, p_two uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.blocks
     where (blocker_id = p_one and blocked_id = p_two)
        or (blocker_id = p_two and blocked_id = p_one)
  )
$$;

-- -----------------------------------------------------------------------------
-- الحظر بيقفل كل الغرف بين الطرفين فوراً
-- -----------------------------------------------------------------------------
create or replace function public.tg_block_closes_rooms()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.matches
     set closed_by_block = true,
         closed_at = now(),
         stage = case
                   when stage = 'completed' then stage
                   else 'cancelled'
                 end
   where (user_a = new.blocker_id and user_b = new.blocked_id)
      or (user_a = new.blocked_id and user_b = new.blocker_id);

  -- فك حجز أي منتجات كانت مقفولة على الغرف دي
  update public.items i
     set status = 'available',
         reserved_until = null,
         reserved_match_id = null
    from public.matches m
   where i.reserved_match_id = m.id
     and m.closed_by_block
     and i.status = 'reserved';

  return new;
end;
$$;

create trigger blocks_close_rooms
  after insert on public.blocks
  for each row execute function public.tg_block_closes_rooms();

-- -----------------------------------------------------------------------------
-- البلاغات
-- -----------------------------------------------------------------------------
create table public.reports (
  id            uuid primary key default gen_random_uuid(),
  reporter_id   uuid not null references public.profiles(id) on delete cascade,
  target_type   text not null check (target_type in ('user', 'item', 'message')),
  target_id     uuid not null,
  reason        public.report_reason not null,
  details       text check (char_length(details) <= 600),
  evidence_paths text[] not null default '{}',
  status        public.report_status not null default 'open',
  handled_by    uuid references public.profiles(id) on delete set null,
  handled_at    timestamptz,
  created_at    timestamptz not null default now()
);

create index reports_open_idx   on public.reports (created_at desc)
  where status in ('open', 'reviewing');
create index reports_target_idx on public.reports (target_type, target_id);

-- بلاغ واحد لكل مستخدم على كل هدف — نمنع الإغراق
create unique index reports_one_per_target
  on public.reports (reporter_id, target_type, target_id);

-- -----------------------------------------------------------------------------
-- النزاعات
--
-- مفقود تماماً من الـ spec الأصلي.
--
-- الصفقات هتفشل، والمنتج هيطلع مش زي الوصف، وحد هيتأخر وحد ما يجيش.
-- من غير مسار واضح، كل نزاع بيتحول لبلاغ عشوائي وتقييم انتقامي،
-- والسمعة بتتدمر من أول عشرين حالة.
-- -----------------------------------------------------------------------------
create table public.disputes (
  id            uuid primary key default gen_random_uuid(),
  match_id      uuid not null references public.matches(id) on delete cascade,
  opened_by     uuid not null references public.profiles(id) on delete cascade,
  reason        public.dispute_reason not null,
  details       text check (char_length(details) <= 800),
  evidence_paths text[] not null default '{}',
  status        public.dispute_status not null default 'open',
  resolution    text,
  resolved_by   uuid references public.profiles(id) on delete set null,
  resolved_at   timestamptz,
  created_at    timestamptz not null default now(),
  unique (match_id, opened_by)
);

create index disputes_open_idx on public.disputes (created_at desc)
  where status in ('open', 'reviewing');

-- -----------------------------------------------------------------------------
-- فتح نزاع = تجميد الغرفة لحد المراجعة
-- -----------------------------------------------------------------------------
create or replace function public.tg_dispute_freezes_room()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.matches
     set frozen_by_report = true,
         stage = 'disputed',
         last_activity_at = now()
   where id = new.match_id;

  insert into public.messages (match_id, sender_id, kind, body)
  values (new.match_id, null, 'system', 'dispute_opened');

  return new;
end;
$$;

create trigger disputes_freeze_room
  after insert on public.disputes
  for each row execute function public.tg_dispute_freezes_room();

-- -----------------------------------------------------------------------------
-- فحص المحتوى — الطبقة الأولى الرخيصة
--
-- بترجع أعلى درجة خطورة اتلقت في النص، وصفر لو نضيف.
-- الموديل القوي بيتنادى بس على اللي بيعدي من هنا ويفضل مشكوك فيه —
-- تحليل كل منتج بموديل رؤية بند تكلفة بيتضاعف بسرعة مع النمو.
-- -----------------------------------------------------------------------------
create or replace function public.screen_text(p_text text)
returns table (severity smallint, matched_term text, category text)
language sql
stable
security definer
set search_path = public
as $$
  select b.severity, b.term, b.category
    from public.banned_terms b
   where b.is_active
     and public.normalize_ar(p_text) like '%' || b.term_norm || '%'
   order by b.severity desc
   limit 5
$$;
