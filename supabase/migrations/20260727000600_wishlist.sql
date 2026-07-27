-- =============================================================================
-- Giraffe — 06. قائمة الرغبات
--
-- دي **مدخل محرك المطابقة** مش feature جانبي.
--
-- من غيرها الـ deck بيبقى عشوائي، واحتمال الماتش بيساوي احتمال الإعجاب
-- تربيع (0.25٪ عند إعجاب 5٪) — وده معناه إن المستخدم بيسحب 400 كارت
-- من غير ولا ماتش وبيمسح التطبيق.
--
-- المشكلة دي اسمها Double coincidence of wants وهي السبب اللي اتخترعت
-- عشانه العملة من آلاف السنين.
-- =============================================================================

create table public.wishlist_items (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles(id) on delete cascade,

  category_id     text not null references public.categories(id),
  subcategory_id  text references public.subcategories(id),

  keyword         text check (char_length(keyword) <= 60),
  keyword_norm    text generated always as (public.normalize_ar(keyword)) stored,

  max_value       numeric(12,2),
  notify          boolean not null default true,

  created_at      timestamptz not null default now()
);

create index wishlist_user_idx     on public.wishlist_items (user_id);
create index wishlist_category_idx on public.wishlist_items (category_id);
create index wishlist_keyword_trgm on public.wishlist_items
  using gin (keyword_norm gin_trgm_ops) where keyword_norm is not null;

-- منع التكرار: نفس القسم + نفس القسم الفرعي + نفس الكلمة
create unique index wishlist_unique_entry on public.wishlist_items (
  user_id,
  category_id,
  coalesce(subcategory_id, '*'),
  coalesce(keyword_norm, '*')
);

-- -----------------------------------------------------------------------------
-- الحدود
--   • 3 عناصر على الأقل — شرط إنهاء الإعداد الأولي (بيتفرض في الدالة أدناه)
--   • 10 عناصر كحد أقصى للمستخدم العادي
-- -----------------------------------------------------------------------------
create or replace function public.tg_enforce_wishlist_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  current_count int;
begin
  select count(*) into current_count
    from public.wishlist_items
   where user_id = new.user_id;

  if current_count >= 10 then
    raise exception 'wishlist_limit_reached'
      using hint = 'الحد الأقصى 10 عناصر في قائمة الرغبات';
  end if;

  return new;
end;
$$;

create trigger wishlist_limit
  before insert on public.wishlist_items
  for each row execute function public.tg_enforce_wishlist_limit();

-- -----------------------------------------------------------------------------
-- هل المستخدم خلّص الإعداد الأولي؟
--
-- الـ deck بيرفض يشتغل من غير 3 رغبات على الأقل + منتج واحد متاح.
-- ده مش تشدد — ده الفرق بين كارت مفيد وكارت فاضي.
-- -----------------------------------------------------------------------------
create or replace function public.is_setup_complete(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    (select count(*) from public.wishlist_items where user_id = p_user) >= 3
    and
    (select count(*) from public.items
      where owner_id = p_user and status = 'available') >= 1
$$;

-- -----------------------------------------------------------------------------
-- تنبيهات قائمة الرغبات
--
-- سجل بيمنع تكرار التنبيه على نفس المنتج مرتين لنفس المستخدم.
-- -----------------------------------------------------------------------------
create table public.wishlist_alerts (
  user_id     uuid not null references public.profiles(id) on delete cascade,
  item_id     uuid not null references public.items(id) on delete cascade,
  wish_id     uuid references public.wishlist_items(id) on delete set null,
  created_at  timestamptz not null default now(),
  primary key (user_id, item_id)
);

-- -----------------------------------------------------------------------------
-- هل الكلمة المفتاحية موجودة في عنوان المنتج؟
--
-- التشابه المتماثل (%) مش مناسب هنا: "ايفون" مقابل "ايفون 15 برو 256 جيجا"
-- بيدي درجة منخفضة لأن الطولين مختلفين جداً — والنتيجة إن أهم مطابقة
-- في المحرك بتفشل.
--
-- الصح هو **تشابه الكلمة داخل النص** (<%): بيدوّر على أقرب تتابع كلمات
-- في العنوان يشبه الكلمة المفتاحية. ومعاه احتواء نصي مباشر للحالة السهلة.
-- -----------------------------------------------------------------------------
create or replace function public.keyword_hits_title(
  p_keyword text,
  p_title   text
)
returns boolean
language sql
immutable
parallel safe
as $$
  select p_keyword is not null
     and p_title   is not null
     and (
       p_title like '%' || p_keyword || '%'   -- احتواء مباشر
       or p_keyword <% p_title                -- تشابه مع أخطاء إملائية
     )
$$;

-- -----------------------------------------------------------------------------
-- قوة تطابق منتج مع رغبات مستخدم
--
-- بترجع 0 لو مفيش تطابق، وبترجع أعلى درجة لأقوى رغبة متطابقة:
--
--   100  الكلمة المفتاحية متطابقة تقريبياً + نفس القسم الفرعي
--    85  الكلمة المفتاحية متطابقة تقريبياً
--    70  نفس القسم الفرعي
--    50  نفس القسم الرئيسي
--
-- وبيتخصم 20 لو المنتج أغلى من السقف اللي المستخدم حاططه.
-- -----------------------------------------------------------------------------
create or replace function public.wishlist_match_score(
  p_user uuid,
  p_item public.items
)
returns int
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(max(
    greatest(
      0,
      case
        when w.keyword_norm is not null
             and public.keyword_hits_title(w.keyword_norm, p_item.title_norm)
             and w.subcategory_id is not distinct from p_item.subcategory_id
          then 100
        when w.keyword_norm is not null
             and public.keyword_hits_title(w.keyword_norm, p_item.title_norm)
          then 85
        when w.subcategory_id is not null
             and w.subcategory_id = p_item.subcategory_id
          then 70
        when w.category_id = p_item.category_id
          then 50
        else 0
      end
      - case
          when w.max_value is not null
               and p_item.value_min is not null
               and p_item.value_min > w.max_value
            then 20
          else 0
        end
    )
  ), 0)::int
  from public.wishlist_items w
  where w.user_id = p_user
    and w.category_id = p_item.category_id
$$;

comment on function public.wishlist_match_score is
  'قوة تطابق منتج مع قائمة رغبات مستخدم، من 0 لـ 100. أساس شرط الترشيح المزدوج.';
