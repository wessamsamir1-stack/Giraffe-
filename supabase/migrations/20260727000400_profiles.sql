-- =============================================================================
-- Giraffe — 04. الملفات الشخصية والثقة والحدود
-- =============================================================================

-- -----------------------------------------------------------------------------
-- الملف الشخصي
-- -----------------------------------------------------------------------------
create table public.profiles (
  id                uuid primary key references auth.users(id) on delete cascade,
  username          citext not null unique
                      check (username ~ '^[a-z0-9_]{3,20}$'),
  display_name      text not null check (char_length(display_name) between 2 and 40),
  bio               text check (char_length(bio) <= 160),
  avatar_path       text,

  country_code      char(2) not null references public.countries(code),
  city_id           text    not null references public.cities(id),
  area_id           text    references public.areas(id) on delete set null,

  -- إحداثيات **مزحزحة** — مش الموقع الحقيقي أبداً (شوف jitter_point)
  lat               double precision,
  lng               double precision,

  locale            text not null default 'ar' check (locale in ('ar', 'en')),

  email_verified    boolean not null default false,
  -- توثيق الموبايل مطلوب قبل **أول صفقة** مش قبل التصفح.
  -- طلبه عند التسجيل بيقتل نسبة الإكمال؛ طلبه عند أول ماتش بيلاقي
  -- المستخدم متحمس وعنده دافع حقيقي.
  phone_verified    boolean not null default false,

  is_banned         boolean not null default false,
  banned_until      timestamptz,
  ban_reason        text,

  deletion_requested_at timestamptz,

  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  last_active_at    timestamptz not null default now()
);

create index profiles_city_idx     on public.profiles (city_id) where not is_banned;
create index profiles_geo_idx      on public.profiles (city_id, lat, lng) where not is_banned;
create index profiles_active_idx   on public.profiles (last_active_at desc);

create trigger profiles_touch
  before update on public.profiles
  for each row execute function public.tg_touch_updated_at();

-- -----------------------------------------------------------------------------
-- إحصائيات المستخدم ومستوى الثقة
--
-- قرار تصميمي: **مفيش Trust Score رقمي معروض**.
--
-- الرقم الغامض بيعمل تلات مشاكل: المستخدم الجديد بيتعاقب على إنه جديد،
-- ومحدش بيفهم ليه رقمه نزل، وسهل التلاعب بيه.
--
-- بدله: أربع مستويات معلنة الشروط + ranking_score رقمي **مخفي** بيستخدم
-- في ترتيب الكروت بس.
--
-- وكل الحسابات على **آخر 90 يوم** مش على عمر الحساب — عشان الناس تقدر
-- تتحسن، والحساب القديم السيئ ما يستفيدش من قِدَمه.
-- -----------------------------------------------------------------------------
create table public.user_stats (
  user_id               uuid primary key references public.profiles(id) on delete cascade,

  completed_trades      int not null default 0,
  cancelled_trades      int not null default 0,
  no_shows              int not null default 0,

  completed_trades_90d  int not null default 0,
  cancelled_trades_90d  int not null default 0,

  rating_avg            numeric(3,2) not null default 0
                          check (rating_avg between 0 and 5),
  rating_count          int not null default 0,

  avg_response_minutes  int,

  trust_level           public.trust_level not null default 'new',

  -- مخفي عن المستخدم — للترتيب الداخلي فقط
  ranking_score         numeric(6,2) not null default 0,

  computed_at           timestamptz not null default now()
);

create index user_stats_trust_idx on public.user_stats (trust_level);

-- -----------------------------------------------------------------------------
-- جهة اتصال الطوارئ
--
-- بتتطلب أول مرة المستخدم يحدد لقاء. **مش بتظهر لأي مستخدم تاني أبداً** —
-- سياسة RLS بتقصرها على صاحبها فقط.
-- -----------------------------------------------------------------------------
create table public.emergency_contacts (
  user_id     uuid primary key references public.profiles(id) on delete cascade,
  name        text not null,
  phone       text not null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create trigger emergency_contacts_touch
  before update on public.emergency_contacts
  for each row execute function public.tg_touch_updated_at();

-- -----------------------------------------------------------------------------
-- تنبيهات الطوارئ المُرسلة — سجل للمراجعة
-- -----------------------------------------------------------------------------
create table public.sos_alerts (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  match_id    uuid,
  lat         double precision,
  lng         double precision,
  -- الموقع هنا **حقيقي مش مزحزح** — ده استثناء مقصود وموثّق:
  -- في حالة الطوارئ الدقة أهم من الخصوصية.
  is_precise  boolean not null default true,
  created_at  timestamptz not null default now()
);

create index sos_alerts_user_idx on public.sos_alerts (user_id, created_at desc);

-- -----------------------------------------------------------------------------
-- أجهزة الدفع والإشعارات
-- -----------------------------------------------------------------------------
create table public.push_tokens (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  token       text not null,
  platform    text not null check (platform in ('ios', 'android', 'web')),
  created_at  timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  unique (user_id, token)
);

-- -----------------------------------------------------------------------------
-- إعدادات الإشعارات
-- -----------------------------------------------------------------------------
create table public.notification_prefs (
  user_id     uuid primary key references public.profiles(id) on delete cascade,
  matches     boolean not null default true,
  messages    boolean not null default true,
  offers      boolean not null default true,
  wishlist    boolean not null default true,
  nearby      boolean not null default false,
  marketing   boolean not null default false
);

-- -----------------------------------------------------------------------------
-- الحدود اليومية
--
-- 50 سحبة يمين + 3 صفقات أحلام في اليوم للمستخدم العادي.
-- التراجع **مش محدود ومجاني** — في المقايضة السحبة الغلط مؤلمة أكتر
-- من تطبيقات التعارف، فبيع الحل لمشكلة إحنا سببناها قرار سيء.
-- -----------------------------------------------------------------------------
create table public.daily_limits (
  user_id       uuid not null references public.profiles(id) on delete cascade,
  day           date not null default current_date,
  swipes_used   int not null default 0,
  dreams_used   int not null default 0,
  primary key (user_id, day)
);

-- -----------------------------------------------------------------------------
-- سجل الأحداث الأمنية
-- -----------------------------------------------------------------------------
create table public.security_events (
  id          bigserial primary key,
  user_id     uuid references public.profiles(id) on delete set null,
  kind        public.security_event_kind not null,
  ip          inet,
  user_agent  text,
  metadata    jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now()
);

create index security_events_user_idx on public.security_events (user_id, created_at desc);

-- -----------------------------------------------------------------------------
-- إنشاء الملف تلقائياً بعد التسجيل
--
-- المحفّز ده بيجهّز صفوف الإحصائيات والتفضيلات أول ما الملف يتعمل،
-- عشان مانضطرش نتعامل مع صفوف ناقصة في أي استعلام بعد كده.
-- -----------------------------------------------------------------------------
create or replace function public.tg_bootstrap_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.user_stats (user_id) values (new.id)
    on conflict do nothing;
  insert into public.notification_prefs (user_id) values (new.id)
    on conflict do nothing;
  return new;
end;
$$;

create trigger profiles_bootstrap
  after insert on public.profiles
  for each row execute function public.tg_bootstrap_profile();
