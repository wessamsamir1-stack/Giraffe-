-- =============================================================================
-- Giraffe — 18. الذكاء الاصطناعي: المهام والتكلفة والاعتماد
--
-- المبدأ الحاكم: **الذكاء الاصطناعي بيقترح والمستخدم بيقرر.**
--
-- ومبدأ تاني مش أقل أهمية: **لو الذكاء الاصطناعي فشل، المستخدم مايتوقفش.**
-- كل مسار له بديل يدوي، والمنتج بيتنشر عادي من غير تحليل.
-- =============================================================================

create type public.ai_job_kind as enum (
  'analyze_item',     -- تحليل صور المنتج
  'estimate_value',   -- تقدير نطاق القيمة
  'moderate_item',    -- فحص المحتوى
  'moderate_image'
);

create type public.ai_job_status as enum (
  'queued',
  'running',
  'done',
  'failed',
  'skipped'           -- اتخطّت بسبب السقف أو لأن الطبقة الرخيصة كفت
);

-- -----------------------------------------------------------------------------
-- سجل مهام الذكاء الاصطناعي
--
-- بيتسجل كل نداء: المدخل والمخرج والموديل والتكلفة. من غير السجل ده
-- مفيش طريقة نعرف بيها ليه الفاتورة كبرت ولا نراجع جودة النتائج.
-- -----------------------------------------------------------------------------
create table public.ai_jobs (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid references public.profiles(id) on delete set null,
  item_id      uuid references public.items(id) on delete cascade,
  kind         public.ai_job_kind not null,
  status       public.ai_job_status not null default 'queued',
  model        text,
  input        jsonb not null default '{}'::jsonb,
  output       jsonb,
  error        text,
  cost_cents   numeric(10,4) not null default 0,
  duration_ms  int,
  created_at   timestamptz not null default now(),
  finished_at  timestamptz
);

create index ai_jobs_user_idx on public.ai_jobs (user_id, created_at desc);
create index ai_jobs_item_idx on public.ai_jobs (item_id);
create index ai_jobs_cost_idx on public.ai_jobs (created_at)
  where cost_cents > 0;

-- -----------------------------------------------------------------------------
-- سقف التكلفة
--
-- تحليل كل صورة بموديل رؤية بند تكلفة حقيقي بيتضاعف بسرعة مع النمو،
-- وهو كمان **سطح هجوم**: حد يرفع 500 صورة ويولّع الفاتورة.
--
-- سقفان: يومي لكل مستخدم، ويومي عام للمنصة كلها.
-- -----------------------------------------------------------------------------
create table public.ai_budget (
  id                   boolean primary key default true check (id),
  daily_user_cents     numeric(10,2) not null default 30,     -- ~0.30 دولار
  daily_global_cents   numeric(10,2) not null default 5000,   -- ~50 دولار
  enabled              boolean not null default true,
  updated_at           timestamptz not null default now()
);

insert into public.ai_budget (id) values (true) on conflict do nothing;

-- -----------------------------------------------------------------------------
-- هل مسموح ننادي الذكاء الاصطناعي؟
--
-- بترجع jsonb عشان دالة الحافة تعرف السبب وتعرضه أو تتخطى بهدوء.
-- -----------------------------------------------------------------------------
create or replace function public.ai_quota_check(p_user uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  b            public.ai_budget;
  user_spent   numeric;
  global_spent numeric;
begin
  select * into b from public.ai_budget where id;

  if not b.enabled then
    return jsonb_build_object('allowed', false, 'reason', 'ai_disabled');
  end if;

  select coalesce(sum(cost_cents), 0) into user_spent
    from public.ai_jobs
   where user_id = p_user
     and created_at > now() - interval '24 hours';

  if user_spent >= b.daily_user_cents then
    return jsonb_build_object(
      'allowed', false,
      'reason', 'user_budget_exceeded',
      'spent', user_spent
    );
  end if;

  select coalesce(sum(cost_cents), 0) into global_spent
    from public.ai_jobs
   where created_at > now() - interval '24 hours';

  if global_spent >= b.daily_global_cents then
    return jsonb_build_object(
      'allowed', false,
      'reason', 'global_budget_exceeded',
      'spent', global_spent
    );
  end if;

  return jsonb_build_object('allowed', true);
end;
$$;

-- -----------------------------------------------------------------------------
-- تقدير القيمة من بياناتنا نفسها
--
-- **الأولوية دايماً لمقارناتنا مش للنموذج.**
--
-- النموذج بيغلط كتير في أسعار المستعمل المحلية لأنها مش في بيانات
-- تدريبه، والأهم إن مقارناتنا بتتحسن كل يوم مع كل صفقة مكتملة —
-- ودي أثمن بيانات هنملكها وأصعب حاجة أي منافس يقلدها.
--
-- بترجع null لو مفيش مقارنات كفاية، وساعتها الحافة بتنادي النموذج.
-- -----------------------------------------------------------------------------
create or replace function public.estimate_from_comparables(
  p_country       char(2),
  p_category      text,
  p_subcategory   text default null,
  p_brand         text default null,
  p_model         text default null,
  p_condition     public.item_condition default 'good'
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  result jsonb;
begin
  -- الأدق أولاً: نفس الموديل ونفس الحالة
  select jsonb_build_object(
           'value_min', round(avg(value_min)::numeric, 2),
           'value_max', round(avg(value_max)::numeric, 2),
           'sample_size', sum(sample_size),
           'confidence', 0.90,
           'source', 'comparables_model'
         )
    into result
    from public.price_comparables
   where country_code = p_country
     and category_id = p_category
     and condition = p_condition
     and p_model is not null
     and model_norm is not null
     and model_norm % public.normalize_ar(p_model)
  having sum(sample_size) >= 5;

  if result is not null then return result; end if;

  -- بعده: نفس القسم الفرعي والحالة
  select jsonb_build_object(
           'value_min', round(avg(value_min)::numeric, 2),
           'value_max', round(avg(value_max)::numeric, 2),
           'sample_size', sum(sample_size),
           'confidence', 0.72,
           'source', 'comparables_subcategory'
         )
    into result
    from public.price_comparables
   where country_code = p_country
     and category_id = p_category
     and subcategory_id is not distinct from p_subcategory
     and condition = p_condition
  having sum(sample_size) >= 8;

  if result is not null then return result; end if;

  -- أوسع: القسم والحالة
  select jsonb_build_object(
           'value_min', round(avg(value_min)::numeric, 2),
           'value_max', round(avg(value_max)::numeric, 2),
           'sample_size', sum(sample_size),
           'confidence', 0.60,
           'source', 'comparables_category'
         )
    into result
    from public.price_comparables
   where country_code = p_country
     and category_id = p_category
     and condition = p_condition
  having sum(sample_size) >= 12;

  return result;   -- ممكن ترجع null — وده مقصود
end;
$$;

-- -----------------------------------------------------------------------------
-- تغذية المقارنات من الصفقات المكتملة
--
-- كل صفقة بتتم بتغذي التقدير. ده اللي بيخلي الدقة تتحسن مع الوقت
-- بدل ما تفضل ثابتة على تخمين نموذج.
-- -----------------------------------------------------------------------------
create or replace function public.learn_from_completed_trade(p_match uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  m public.matches;
  it public.items;
begin
  select * into m from public.matches where id = p_match and stage = 'completed';
  if m is null then return; end if;

  for it in
    select * from public.items where id in (m.item_a, m.item_b)
  loop
    continue when it.value_min is null or it.value_max is null;

    insert into public.price_comparables (
      country_code, category_id, subcategory_id, brand, model,
      condition, value_min, value_max, sample_size, source
    )
    values (
      it.country_code, it.category_id, it.subcategory_id, it.brand, it.model,
      it.condition, it.value_min, it.value_max, 1, 'internal'
    );
  end loop;
end;
$$;

-- -----------------------------------------------------------------------------
-- اعتماد المنتج بعد الفحص
--
-- بتتنادى من دالة الحافة بصلاحيات الخدمة.
--
-- ثلاث نتائج:
--   approved  → المنتج بينشر وتنبيهات قوائم الرغبات بتتبعت
--   flagged   → بيفضل مخفي لحد مراجعة بشرية
--   rejected  → بيترفض ويتبلغ صاحبه بالسبب
-- -----------------------------------------------------------------------------
create or replace function public.apply_moderation(
  p_item     uuid,
  p_result   public.moderation_status,
  p_note     text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  it public.items;
begin
  select * into it from public.items where id = p_item;
  if it is null then return; end if;

  update public.items
     set moderation = p_result,
         moderation_note = p_note,
         status = case
                    when p_result = 'approved' then 'available'
                    when p_result = 'rejected' then 'rejected'
                    else status
                  end,
         published_at = case
                          when p_result = 'approved' and published_at is null
                            then now()
                          else published_at
                        end
   where id = p_item;

  if p_result = 'approved' then
    perform public.fanout_wishlist_alerts(p_item);
  elsif p_result = 'rejected' then
    perform public.notify_user(
      it.owner_id,
      'system',
      'منتجك اترفض: ' || coalesce(p_note, 'مخالف لشروط النشر'),
      'Your item was rejected: ' || coalesce(p_note, 'violates listing rules'),
      jsonb_build_object('item_id', p_item)
    );
  end if;
end;
$$;

-- -----------------------------------------------------------------------------
-- الطبقة الأولى من الفحص — رخيصة وفورية
--
-- بترجع القرار المبدئي:
--   rejected  → لقينا مصطلح خطورة 3، مفيش داعي ننادي أي موديل
--   flagged   → خطورة 1 أو 2، محتاج الموديل يحسم
--   approved  → نضيف، والموديل بيتنادى على الصور بس
--
-- الفكرة: **الموديل القوي مابيتنداش إلا على المشكوك فيه**. ده الفرق
-- بين فاتورة معقولة وفاتورة بتتضاعف مع كل مستخدم جديد.
-- -----------------------------------------------------------------------------
create or replace function public.prescreen_item(p_item uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  it       public.items;
  worst    smallint := 0;
  matched  text;
  category text;
begin
  select * into it from public.items where id = p_item;
  if it is null then
    return jsonb_build_object('decision', 'flagged', 'reason', 'item_not_found');
  end if;

  select severity, matched_term, s.category
    into worst, matched, category
    from public.screen_text(it.title || ' ' || coalesce(it.description, '')) s
   order by severity desc
   limit 1;

  if worst is null then worst := 0; end if;

  return jsonb_build_object(
    'decision', case
                  when worst >= 3 then 'rejected'
                  when worst >= 1 then 'flagged'
                  else 'approved'
                end,
    'severity', worst,
    'matched_term', matched,
    'category', category,
    -- الصور محتاجة الموديل حتى لو النص نضيف
    'needs_vision', it.photo_count > 0
  );
end;
$$;

-- -----------------------------------------------------------------------------
-- سياسات الحماية
-- -----------------------------------------------------------------------------
alter table public.ai_jobs   enable row level security;
alter table public.ai_budget enable row level security;

grant select on public.ai_jobs to authenticated;

-- المستخدم بيشوف مهامه هو بس — وبدون التكلفة (عمود مخفي)
revoke select on public.ai_jobs from authenticated;
grant select (id, item_id, kind, status, output, error, created_at, finished_at)
  on public.ai_jobs to authenticated;

create policy ai_jobs_own on public.ai_jobs
  for select using (user_id = auth.uid());

-- الميزانية للإدارة فقط — مفيش سياسة قراءة يعني مفيش وصول
