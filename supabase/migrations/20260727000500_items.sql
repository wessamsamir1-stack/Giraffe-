-- =============================================================================
-- Giraffe — 05. المنتجات
-- =============================================================================

create table public.items (
  id                uuid primary key default gen_random_uuid(),
  owner_id          uuid not null references public.profiles(id) on delete cascade,

  title             text not null check (char_length(title) between 3 and 80),
  title_norm        text generated always as (public.normalize_ar(title)) stored,
  description       text check (char_length(description) <= 600),

  category_id       text not null references public.categories(id),
  subcategory_id    text references public.subcategories(id),

  condition         public.item_condition not null default 'good',
  brand             text,
  model             text,

  status            public.item_status not null default 'pending',
  moderation        public.moderation_status not null default 'pending',
  moderation_note   text,

  -- ---------------------------------------------------------------------------
  -- القيمة التقديرية
  --
  -- قاعدة غير قابلة للتفاوض: **ممنوع رقم واحد قاطع**.
  -- النطاق دايماً، ومعاه عدد المنتجات المشابهة اللي اتبنى عليها.
  --
  -- ولو ثقة النموذج أقل من 0.60 ما نعرضش تقدير خالص ونسيب المستخدم
  -- يحدد بنفسه — تقدير غلط بيولّد خلافات ومسؤولية علينا.
  -- ---------------------------------------------------------------------------
  value_min         numeric(12,2),
  value_max         numeric(12,2),
  currency_code     char(3) not null,
  ai_confidence     numeric(3,2) not null default 0
                      check (ai_confidence between 0 and 1),
  comparable_count  int not null default 0,
  owner_value       numeric(12,2),   -- القيمة اللي المالك شايفها

  -- تفضيلات المقايضة النقدية
  will_pay_up_to    numeric(12,2) not null default 0,
  accepts_cash_diff boolean not null default true,

  country_code      char(2) not null references public.countries(code),
  city_id           text not null references public.cities(id),
  area_id           text references public.areas(id) on delete set null,
  lat               double precision,
  lng               double precision,

  is_service        boolean not null default false,

  photo_count       smallint not null default 0 check (photo_count between 0 and 6),
  interested_count  int not null default 0,
  wishlist_count    int not null default 0,

  -- قفل الحجز بعد قبول عرض — 48 ساعة
  reserved_until    timestamptz,
  reserved_match_id uuid,

  published_at      timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),

  constraint items_value_range check (
    value_min is null or value_max is null or value_max >= value_min
  ),
  -- الخدمات مالهاش تقدير آلي — المستخدم بيحدد قيمتها بنفسه
  constraint items_service_no_ai check (
    not is_service or ai_confidence = 0
  )
);

create index items_owner_idx    on public.items (owner_id);
create index items_market_idx   on public.items (city_id, status)
  where status = 'available';
create index items_category_idx on public.items (category_id, city_id, status)
  where status = 'available';
create index items_geo_idx      on public.items (city_id, lat, lng)
  where status = 'available';
create index items_fresh_idx    on public.items (published_at desc nulls last)
  where status = 'available';
create index items_title_trgm   on public.items using gin (title_norm gin_trgm_ops);
create index items_reserved_idx on public.items (reserved_until)
  where reserved_until is not null;

create trigger items_touch
  before update on public.items
  for each row execute function public.tg_touch_updated_at();

comment on column public.items.lat is
  'إحداثي مزحزح ~1 كم — مش الموقع الحقيقي. شوف public.jitter_point.';

-- -----------------------------------------------------------------------------
-- صور المنتج
-- -----------------------------------------------------------------------------
create table public.item_photos (
  id            uuid primary key default gen_random_uuid(),
  item_id       uuid not null references public.items(id) on delete cascade,
  storage_path  text not null,
  position      smallint not null default 0 check (position between 0 and 5),
  is_cover      boolean not null default false,
  -- نتيجة الطبقة الأولى من فحص المحتوى
  moderation    public.moderation_status not null default 'pending',
  moderation_score numeric(3,2),
  created_at    timestamptz not null default now(),
  unique (item_id, position)
);

create index item_photos_item_idx on public.item_photos (item_id, position);

-- صورة غلاف واحدة بالضبط لكل منتج
create unique index item_photos_one_cover
  on public.item_photos (item_id) where is_cover;

-- -----------------------------------------------------------------------------
-- المالك بيقايض بإيه
--
-- ده النص التاني من شرط الترشيح المزدوج: الكارت ما بيظهرش إلا لو
-- **المالك كمان** عايز حاجة من اللي إنت مالكه.
-- -----------------------------------------------------------------------------
create table public.item_wanted_categories (
  item_id         uuid not null references public.items(id) on delete cascade,
  category_id     text not null references public.categories(id),
  subcategory_id  text references public.subcategories(id),
  -- بوستجرس مابيسمحش بتعبير جوه المفتاح الأساسي، فبنثبّت العمود
  subcategory_key text generated always as (coalesce(subcategory_id, '*')) stored,
  primary key (item_id, category_id, subcategory_key)
);

create index item_wanted_lookup on public.item_wanted_categories (category_id);

-- -----------------------------------------------------------------------------
-- تحديث عدّاد الصور تلقائياً
-- -----------------------------------------------------------------------------
create or replace function public.tg_sync_photo_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target uuid := coalesce(new.item_id, old.item_id);
begin
  update public.items
     set photo_count = (select count(*) from public.item_photos where item_id = target)
   where id = target;
  return coalesce(new, old);
end;
$$;

create trigger item_photos_count
  after insert or delete on public.item_photos
  for each row execute function public.tg_sync_photo_count();
