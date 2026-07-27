-- =============================================================================
-- Giraffe — 08. غرفة المقايضة: الرسائل والعروض واللقاء والإتمام
-- =============================================================================

-- -----------------------------------------------------------------------------
-- الرسائل
-- -----------------------------------------------------------------------------
create table public.messages (
  id            uuid primary key default gen_random_uuid(),
  match_id      uuid not null references public.matches(id) on delete cascade,
  -- null = رسالة نظام
  sender_id     uuid references public.profiles(id) on delete set null,
  kind          public.message_kind not null default 'text',
  body          text check (char_length(body) <= 2000),
  image_path    text,
  offer_id      uuid,
  meeting_id    uuid,
  read_at       timestamptz,
  created_at    timestamptz not null default now(),

  constraint messages_sender_required check (
    kind = 'system' or sender_id is not null
  )
);

create index messages_match_idx  on public.messages (match_id, created_at desc);
create index messages_unread_idx on public.messages (match_id)
  where read_at is null;

-- المحفّز اللي اتعرّف في الملف السابق — بيتعلّق دلوقتي بعد وجود الرسائل
create trigger matches_created
  after insert on public.matches
  for each row execute function public.tg_match_created();

-- -----------------------------------------------------------------------------
-- العروض
--
-- الفرق النقدي مسموح ومهم — هو اللي بيقفل معظم الصفقات الواقعية،
-- وهو اللي بيحل مشكلة توافق الرغبات جزئياً.
--
-- بس **مفيش أي معالجة دفع**. الفلوس يد بيد عند اللقاء، وGiraffe مش
-- طرف في العملية ومش بيحتفظ بأي مبالغ. القرار ده بيأجّل باب تنظيمي
-- كامل (اعرف عميلك، مكافحة غسل الأموال، ترخيص) لحد ما يبقى وقته.
-- -----------------------------------------------------------------------------
create table public.offers (
  id            uuid primary key default gen_random_uuid(),
  match_id      uuid not null references public.matches(id) on delete cascade,
  from_user     uuid not null references public.profiles(id) on delete cascade,

  give_item_id  uuid not null references public.items(id) on delete cascade,
  get_item_id   uuid not null references public.items(id) on delete cascade,

  -- موجب = المُرسِل بيدفع فرق. سالب = المُرسِل بيستلم فرق.
  cash_delta    numeric(12,2) not null default 0,
  currency_code char(3) not null,

  status        public.offer_status not null default 'pending',
  replaces_offer_id uuid references public.offers(id) on delete set null,

  created_at    timestamptz not null default now(),
  responded_at  timestamptz,
  expires_at    timestamptz not null default (now() + interval '7 days'),

  constraint offers_distinct_items check (give_item_id <> get_item_id)
);

create index offers_match_idx  on public.offers (match_id, created_at desc);
create index offers_open_idx   on public.offers (match_id) where status = 'pending';

alter table public.messages
  add constraint messages_offer_fk
  foreign key (offer_id) references public.offers(id) on delete set null;

-- عرض معلّق واحد بس في كل غرفة
create unique index offers_single_pending
  on public.offers (match_id) where status = 'pending';

-- -----------------------------------------------------------------------------
-- قبول العرض = حجز المنتجين 48 ساعة
--
-- من غير القفل ده، نفس المنتج ممكن يتوعد لتلات ناس في نفس الوقت،
-- وده أسرع طريق لتدمير الثقة في المنصة.
-- -----------------------------------------------------------------------------
create or replace function public.tg_offer_status_changed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = old.status then
    return new;
  end if;

  new.responded_at := now();

  if new.status = 'accepted' then
    update public.items
       set status = 'reserved',
           reserved_until = now() + interval '48 hours',
           reserved_match_id = new.match_id
     where id in (new.give_item_id, new.get_item_id);

    update public.matches
       set stage = 'agreed',
           last_activity_at = now()
     where id = new.match_id;

  elsif new.status in ('declined', 'expired') then
    update public.items
       set status = 'negotiating',
           reserved_until = null,
           reserved_match_id = null
     where id in (new.give_item_id, new.get_item_id)
       and reserved_match_id = new.match_id;

    update public.matches
       set stage = 'negotiating',
           last_activity_at = now()
     where id = new.match_id
       and stage = 'offer_pending';
  end if;

  return new;
end;
$$;

create trigger offers_status_change
  before update of status on public.offers
  for each row execute function public.tg_offer_status_changed();

create or replace function public.tg_offer_created()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.matches
     set stage = 'offer_pending',
         last_activity_at = now()
   where id = new.match_id
     and stage = 'negotiating';

  insert into public.messages (match_id, sender_id, kind, offer_id)
  values (new.match_id, new.from_user, 'offer', new.id);

  return new;
end;
$$;

create trigger offers_created
  after insert on public.offers
  for each row execute function public.tg_offer_created();

-- -----------------------------------------------------------------------------
-- اللقاء
--
-- المكان **لازم** يكون من القائمة المعتمدة — مفيش إدخال حر.
-- دي أهم قاعدة أمان في التطبيق: أخطر لحظة في رحلة المستخدم هي لحظة
-- اللقاء الحقيقي مع غريب، ومفيش أي payment rail نرجّع منه فلوس.
-- -----------------------------------------------------------------------------
create table public.meetings (
  id            uuid primary key default gen_random_uuid(),
  match_id      uuid not null references public.matches(id) on delete cascade,
  place_id      uuid not null references public.meeting_places(id),
  scheduled_at  timestamptz not null,
  created_by    uuid not null references public.profiles(id) on delete cascade,
  status        public.meeting_status not null default 'proposed',
  confirmed_by  uuid references public.profiles(id) on delete set null,
  no_show_user  uuid references public.profiles(id) on delete set null,
  created_at    timestamptz not null default now(),

  constraint meetings_future check (scheduled_at > created_at)
);

create index meetings_match_idx on public.meetings (match_id, scheduled_at desc);

alter table public.messages
  add constraint messages_meeting_fk
  foreign key (meeting_id) references public.meetings(id) on delete set null;

create or replace function public.tg_meeting_created()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.matches
     set stage = 'meeting_set',
         last_activity_at = now()
   where id = new.match_id
     and stage in ('agreed', 'negotiating', 'offer_pending');

  insert into public.messages (match_id, sender_id, kind, meeting_id)
  values (new.match_id, new.created_by, 'meeting', new.id);

  return new;
end;
$$;

create trigger meetings_created
  after insert on public.meetings
  for each row execute function public.tg_meeting_created();

-- -----------------------------------------------------------------------------
-- قائمة التحقق قبل التسليم
-- -----------------------------------------------------------------------------
create table public.meeting_checklists (
  meeting_id      uuid not null references public.meetings(id) on delete cascade,
  user_id         uuid not null references public.profiles(id) on delete cascade,
  matches_desc    boolean not null default false,
  tested_working  boolean not null default false,
  cash_agreed     boolean not null default false,
  place_is_public boolean not null default false,
  updated_at      timestamptz not null default now(),
  primary key (meeting_id, user_id)
);

-- -----------------------------------------------------------------------------
-- تأكيد الإتمام بالـ QR
--
-- الصفقة **ما بتتسجلش مكتملة** إلا بتأكيد الطرفين. الشرط ده هو اللي
-- بيمنع تسجيل صفقات وهمية بين حسابين لرفع مستوى الثقة.
-- -----------------------------------------------------------------------------
create table public.trade_confirmations (
  match_id      uuid not null references public.matches(id) on delete cascade,
  user_id       uuid not null references public.profiles(id) on delete cascade,
  -- كود لمرة واحدة بيتولّد على الخادم وبيتعرض كـ QR
  code          text not null,
  confirmed_at  timestamptz,
  created_at    timestamptz not null default now(),
  primary key (match_id, user_id)
);

create or replace function public.tg_check_trade_complete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  both_confirmed boolean;
  m public.matches;
begin
  if new.confirmed_at is null then
    return new;
  end if;

  select count(*) filter (where confirmed_at is not null) = 2
    into both_confirmed
    from public.trade_confirmations
   where match_id = new.match_id;

  if not both_confirmed then
    return new;
  end if;

  select * into m from public.matches where id = new.match_id;

  update public.matches
     set stage = 'completed',
         closed_at = now(),
         last_activity_at = now()
   where id = new.match_id;

  update public.items
     set status = 'traded',
         reserved_until = null,
         reserved_match_id = null
   where id in (m.item_a, m.item_b);

  insert into public.messages (match_id, sender_id, kind, body)
  values (new.match_id, null, 'system', 'trade_completed');

  perform public.refresh_user_stats(m.user_a);
  perform public.refresh_user_stats(m.user_b);

  return new;
end;
$$;

create trigger trade_confirmations_complete
  after insert or update of confirmed_at on public.trade_confirmations
  for each row execute function public.tg_check_trade_complete();

-- -----------------------------------------------------------------------------
-- تحديث نشاط الغرفة مع كل رسالة
-- -----------------------------------------------------------------------------
create or replace function public.tg_bump_match_activity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.matches
     set last_activity_at = now()
   where id = new.match_id;
  return new;
end;
$$;

create trigger messages_bump_activity
  after insert on public.messages
  for each row execute function public.tg_bump_match_activity();
