-- =============================================================================
-- Giraffe — 03. الجداول المرجعية
--
-- كلها للقراءة العامة، والكتابة فيها للإدارة بس (سياسات RLS في ملف 14).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- الدول والعملات
-- -----------------------------------------------------------------------------
create table public.countries (
  code            char(2) primary key,
  name_ar         text not null,
  name_en         text not null,
  dial_code       text not null,
  flag            text not null,
  currency_code   char(3) not null,
  currency_ar     text not null,
  currency_en     text not null,
  -- الدينار الكويتي والبحريني والريال العماني بـ 3 خانات مش 2
  currency_decimals smallint not null default 2
    check (currency_decimals between 0 and 3),
  phone_digits    smallint not null,
  phone_prefix    text,          -- أول رقم في الموبايل بعد إزالة الصفر
  -- مصر بس مفتوحة عند الإطلاق. باقي الدول جاهزة في البيانات ومقفولة.
  is_active       boolean not null default false,
  sort_order      smallint not null default 100
);

-- -----------------------------------------------------------------------------
-- المدن — كل مدينة **سوق منفصل**
--
-- ده أهم قيد سيولة في المنتج: المستخدم في أسوان ما بيتعرضش عليه صفقة
-- في الدمام. الـ deck بيتقيّد بالمدينة والمدن المجاورة المعلنة.
-- -----------------------------------------------------------------------------
create table public.cities (
  id              text primary key,
  country_code    char(2) not null references public.countries(code) on delete restrict,
  name_ar         text not null,
  name_en         text not null,
  lat             double precision not null,
  lng             double precision not null,
  -- المدن اللي بيتشارك معاها السوق (القاهرة والجيزة والقليوبية = سوق واحد)
  market_group    text not null,
  is_active       boolean not null default false,
  sort_order      smallint not null default 100
);

create index cities_country_idx on public.cities (country_code) where is_active;
create index cities_market_idx  on public.cities (market_group)  where is_active;

-- -----------------------------------------------------------------------------
-- المناطق داخل المدينة — اختيارية، للعرض بس
-- -----------------------------------------------------------------------------
create table public.areas (
  id        text primary key,
  city_id   text not null references public.cities(id) on delete cascade,
  name_ar   text not null,
  name_en   text not null,
  lat       double precision,
  lng       double precision
);

create index areas_city_idx on public.areas (city_id);

-- -----------------------------------------------------------------------------
-- الأقسام
--
-- restricted = بيظهر تنبيه بالشروط القانونية قبل النشر.
-- is_service = خدمة مش منتج: مفيش حالة منتج ولا شحن ولا تقدير سعر آلي.
-- -----------------------------------------------------------------------------
create table public.categories (
  id            text primary key,
  name_ar       text not null,
  name_en       text not null,
  icon          text not null,
  restricted    boolean not null default false,
  is_service    boolean not null default false,
  is_featured   boolean not null default false,
  sort_order    smallint not null default 100,
  is_active     boolean not null default true
);

create table public.subcategories (
  id            text primary key,
  category_id   text not null references public.categories(id) on delete cascade,
  name_ar       text not null,
  name_en       text not null,
  sort_order    smallint not null default 100
);

create index subcategories_category_idx on public.subcategories (category_id);

-- -----------------------------------------------------------------------------
-- أماكن اللقاء المعتمدة
--
-- المستخدم **مايقدرش** يكتب مكان حر. الاختيار من القائمة دي فقط.
-- ده أهم قيد أمان في التطبيق كله.
-- -----------------------------------------------------------------------------
create table public.meeting_places (
  id          uuid primary key default gen_random_uuid(),
  city_id     text not null references public.cities(id) on delete cascade,
  area_id     text references public.areas(id) on delete set null,
  name_ar     text not null,
  name_en     text not null,
  kind        public.place_kind not null,
  lat         double precision not null,
  lng         double precision not null,
  -- ساعات الازدحام المفضلة للقاء الآمن
  safe_hours  int4range not null default int4range(10, 22),
  is_active   boolean not null default true,
  created_at  timestamptz not null default now()
);

create index meeting_places_city_idx on public.meeting_places (city_id) where is_active;

-- -----------------------------------------------------------------------------
-- المصطلحات المحظورة
--
-- الطبقة الأولى الرخيصة في فحص المحتوى. الموديل القوي بيتنادى بس على
-- اللي بيعدي من هنا ويفضل مشكوك فيه — عشان تكلفة الذكاء الاصطناعي.
-- -----------------------------------------------------------------------------
create table public.banned_terms (
  id          bigserial primary key,
  term        text not null,
  term_norm   text generated always as (public.normalize_ar(term)) stored,
  category    text not null,          -- weapons | drugs | counterfeit | ...
  severity    smallint not null default 1 check (severity between 1 and 3),
  is_active   boolean not null default true
);

create index banned_terms_norm_idx on public.banned_terms
  using gin (term_norm gin_trgm_ops) where is_active;

-- -----------------------------------------------------------------------------
-- مقارنات الأسعار
--
-- مصدر نطاق القيمة المعروض للمستخدم. في البداية بيتعبّى من مصادر خارجية،
-- وبعدين — وده الأهم — بيتبني من **صفقاتنا المكتملة نفسها**، وهي أثمن
-- بيانات هنملكها وأصعب حاجة أي منافس يقلدها.
--
-- ملاحظة: النطاق لكل سوق على حدة. فرق القوة الشرائية بين مصر والخليج
-- بيكسر أي تقدير موحّد.
-- -----------------------------------------------------------------------------
create table public.price_comparables (
  id              uuid primary key default gen_random_uuid(),
  country_code    char(2) not null references public.countries(code),
  category_id     text not null references public.categories(id),
  subcategory_id  text references public.subcategories(id),
  brand           text,
  model           text,
  model_norm      text generated always as (public.normalize_ar(model)) stored,
  condition       public.item_condition not null,
  value_min       numeric(12,2) not null,
  value_max       numeric(12,2) not null,
  sample_size     int not null default 1,
  source          text not null default 'internal',  -- internal | seeded | external
  updated_at      timestamptz not null default now(),
  check (value_max >= value_min)
);

create index price_comparables_lookup_idx on public.price_comparables
  (country_code, category_id, condition);

create index price_comparables_model_idx on public.price_comparables
  using gin (model_norm gin_trgm_ops);
