-- =============================================================================
-- Giraffe — 12. محرك المطابقة
--
-- ده قلب المنتج. لو الملف ده اشتغل صح، التطبيق ينفع يكبر.
-- لو غلط، مفيش feature تاني هينفع.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- مدى رغبة صاحب منتج معيّن في منتج تاني
--
-- إشارتان، وبناخد الأقوى فيهم:
--   1. قائمة رغباته بتطابق المنتج            (0 – 100)
--   2. المنتج بتاعه معلّم إنه بيقايض بالقسم ده (60)
-- -----------------------------------------------------------------------------
create or replace function public.owner_interest_score(
  p_owner       uuid,
  p_their_item  uuid,
  p_my_item     public.items
)
returns int
language sql
stable
security definer
set search_path = public
as $$
  select greatest(
    public.wishlist_match_score(p_owner, p_my_item),
    case
      when exists (
        select 1
          from public.item_wanted_categories w
         where w.item_id = p_their_item
           and w.category_id = p_my_item.category_id
           and (w.subcategory_id is null
                or w.subcategory_id = p_my_item.subcategory_id)
      ) then 60
      else 0
    end
  )
$$;


-- -----------------------------------------------------------------------------
-- نسبة التوافق
--
-- الأوزان مضبوطة عمداً بحيث إن **الرغبة المتبادلة تساوي 70٪** من الدرجة.
-- الباقي (القيمة والمسافة والثقة) بيرتّب بين الصفقات الممكنة، مش بيقرر
-- إذا كانت ممكنة أصلاً.
--
--   35٪  قد إيه أنا عايز منتجهم
--   35٪  قد إيه هم عايزين منتجي
--   15٪  تقارب القيمة (بعد الفرق النقدي)
--    8٪  المسافة
--    7٪  ثقة ونشاط الطرف التاني
-- -----------------------------------------------------------------------------
create or replace function public.trade_compatibility(
  p_my_interest    int,
  p_their_interest int,
  p_my_value       numeric,
  p_their_value    numeric,
  p_distance_km    double precision,
  p_trust          public.trust_level,
  p_last_active    timestamptz
)
returns smallint
language sql
immutable
parallel safe
as $$
  select least(99, greatest(1, round(
      0.35 * coalesce(p_my_interest, 0)
    + 0.35 * coalesce(p_their_interest, 0)

    -- تقارب القيمة: 100 لو متساويين، وبيقل كل ما الفجوة النسبية تكبر.
    -- الفرق النقدي بيجسّر الفجوة، فبنخفف العقوبة (نقسم على 2).
    + 0.15 * case
        when p_my_value is null or p_their_value is null
             or greatest(p_my_value, p_their_value) = 0
          then 50
        else greatest(0, 100 - (
               abs(p_their_value - p_my_value)
               / greatest(p_my_value, p_their_value) * 100 / 2
             ))
      end

    -- المسافة: 100 تحت 3 كم، وبتنزل خطياً لحد 50 كم
    + 0.08 * case
        when p_distance_km is null then 60
        when p_distance_km <= 3   then 100
        when p_distance_km >= 50  then 0
        else 100 - ((p_distance_km - 3) / 47 * 100)
      end

    -- الثقة والنشاط
    + 0.07 * (
        case p_trust
          when 'elite'    then 100
          when 'trusted'  then 80
          when 'verified' then 60
          else 35
        end * 0.7
        + case
            when p_last_active is null then 0
            when p_last_active > now() - interval '2 days'  then 100
            when p_last_active > now() - interval '7 days'  then 70
            when p_last_active > now() - interval '30 days' then 35
            else 0
          end * 0.3
      )
  )))::smallint
$$;


-- -----------------------------------------------------------------------------
-- توليد الـ deck
--
-- ============================ شرط الترشيح المزدوج ============================
--
-- الكارت **ما بيظهرش أبداً** إلا لو الشرطين اتحققوا مع بعض:
--
--   1. منتجهم بيطابق حاجة في قائمة رغباتي        (my_interest   >= 50)
--   2. منتجي بيطابق حاجة في قائمة رغباتهم        (their_interest >= 50)
--
-- الشرط التاني هو السر كله. من غيره احتمال الماتش = احتمال الإعجاب
-- **تربيع** — يعني 0.25٪ عند إعجاب 5٪. مع الشرطين بيقفز لـ 15–25٪.
--
-- ============================ الاقتران الحتمي ==============================
--
-- لكل منتج عندهم بنختار **منتج واحد** من عندي للمقايضة، والاختيار حتمي:
-- الأعلى في رغبتهم، وعند التساوي الأقدم (بالـ id).
--
-- ده مقصود: لازم أنا أشوف الزوج (منتجي M ↔ منتجهم T) وهم يشوفوا نفس
-- الزوج بالظبط، وإلا الماتش المتبادل مش هيتحقق أبداً.
-- =============================================================================
create or replace function public.get_deck(
  p_user  uuid default auth.uid(),
  p_limit int  default 20
)
returns table (
  their_item_id   uuid,
  their_owner_id  uuid,
  my_item_id      uuid,
  compatibility   smallint,
  distance_km     numeric,
  cash_delta      numeric,
  currency_code   char(3)
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_market  text;
  v_lat     double precision;
  v_lng     double precision;
begin
  if p_user is null then
    raise exception 'auth_required';
  end if;

  -- الـ deck مابيشتغلش من غير 3 رغبات + منتج واحد متاح.
  -- ده مش تشدد — ده الفرق بين كارت مفيد وكارت فاضي.
  if not public.is_setup_complete(p_user) then
    return;
  end if;

  select c.market_group, p.lat, p.lng
    into v_market, v_lat, v_lng
    from public.profiles p
    join public.cities c on c.id = p.city_id
   where p.id = p_user;

  return query
  with candidates as (
    select
      ti.id                                     as their_item_id,
      ti.owner_id                               as their_owner_id,
      ti.value_min, ti.value_max, ti.currency_code,
      ti.lat as their_lat, ti.lng as their_lng,
      po.last_active_at,
      us.trust_level,
      public.wishlist_match_score(p_user, ti)   as my_interest
    from public.items    ti
    join public.profiles po on po.id = ti.owner_id
    join public.cities   pc on pc.id = po.city_id
    join public.user_stats us on us.user_id = po.id
   where ti.status = 'available'
     and ti.moderation = 'approved'
     and ti.owner_id <> p_user
     and not po.is_banned
     -- كل مدينة سوق منفصل. المقايضة عملية فيزيائية — لازم يتقابلوا.
     and pc.market_group = v_market
     and not exists (
           select 1 from public.swipes s
            where s.user_id = p_user and s.target_item_id = ti.id
         )
     and not public.blocked_between(p_user, ti.owner_id)
  ),
  wanted as (
    select * from candidates where my_interest >= 50
  ),
  paired as (
    select distinct on (w.their_item_id)
      w.*,
      mi.id         as my_item_id,
      mi.value_min  as my_min,
      mi.value_max  as my_max,
      public.owner_interest_score(w.their_owner_id, w.their_item_id, mi)
                    as their_interest
    from wanted w
    join public.items mi
      on mi.owner_id = p_user
     and mi.status = 'available'
    order by
      w.their_item_id,
      public.owner_interest_score(w.their_owner_id, w.their_item_id, mi) desc,
      mi.id asc     -- كسر التعادل حتمي — الطرفان لازم يشوفوا نفس الزوج
  ),
  scored as (
    select
      p.their_item_id,
      p.their_owner_id,
      p.my_item_id,
      public.trade_compatibility(
        p.my_interest,
        p.their_interest,
        (coalesce(p.my_min, 0) + coalesce(p.my_max, 0)) / 2.0,
        (coalesce(p.value_min, 0) + coalesce(p.value_max, 0)) / 2.0,
        public.haversine_km(v_lat, v_lng, p.their_lat, p.their_lng),
        p.trust_level,
        p.last_active_at
      ) as compatibility,
      round(
        public.haversine_km(v_lat, v_lng, p.their_lat, p.their_lng)::numeric, 1
      ) as distance_km,
      -- موجب = أنا أدفع فرق (منتجهم أغلى)
      round(
        ((coalesce(p.value_min, 0) + coalesce(p.value_max, 0)) / 2.0)
        - ((coalesce(p.my_min, 0) + coalesce(p.my_max, 0)) / 2.0),
        2
      ) as cash_delta,
      p.currency_code,
      p.their_interest
    from paired p
    where p.their_interest >= 50      -- ◀︎ الشرط التاني من الترشيح المزدوج
  )
  select
    s.their_item_id,
    s.their_owner_id,
    s.my_item_id,
    s.compatibility,
    s.distance_km,
    s.cash_delta,
    s.currency_code
  from scored s
  order by s.compatibility desc, s.distance_km asc nulls last
  limit greatest(1, least(p_limit, 50));
end;
$$;

comment on function public.get_deck is
  'كروت الصفقات المرشحة. بيطبّق شرط الترشيح المزدوج والاقتران الحتمي.';


-- -----------------------------------------------------------------------------
-- تسجيل سحبة وكشف الماتش
--
-- الماتش بيتكوّن لما الطرفين يوافقوا على **نفس الزوج بالظبط**:
--   أنا سحبت: أدي M مقابل T
--   هم سحبوا: يدوا T مقابل M
--
-- الاقتران الحتمي في get_deck هو اللي بيضمن إن الطرفين شافوا نفس الزوج.
--
-- بترجع jsonb:
--   {"ok": true, "matched": false}
--   {"ok": true, "matched": true, "match_id": "..."}
--   {"ok": false, "error": "daily_limit_reached"}
-- -----------------------------------------------------------------------------
create or replace function public.record_swipe(
  p_target_item  uuid,
  p_offered_item uuid,
  p_intent       public.swipe_intent,
  p_user         uuid default auth.uid()
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_target      public.items;
  v_offered     public.items;
  v_limits      public.daily_limits;
  v_match_id    uuid;
  v_reciprocal  uuid;
  v_a           uuid;
  v_b           uuid;
  v_item_a      uuid;
  v_item_b      uuid;
begin
  if p_user is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;

  select * into v_target  from public.items where id = p_target_item;
  select * into v_offered from public.items where id = p_offered_item;

  if v_target is null or v_offered is null then
    return jsonb_build_object('ok', false, 'error', 'item_not_found');
  end if;

  if v_offered.owner_id <> p_user then
    return jsonb_build_object('ok', false, 'error', 'not_your_item');
  end if;

  if v_target.owner_id = p_user then
    return jsonb_build_object('ok', false, 'error', 'cannot_swipe_own_item');
  end if;

  if public.blocked_between(p_user, v_target.owner_id) then
    return jsonb_build_object('ok', false, 'error', 'blocked');
  end if;

  -- ---------------------------------------------------------------------------
  -- الحدود اليومية — التخطي مش بيتحسب
  -- ---------------------------------------------------------------------------
  if p_intent <> 'skip' then
    insert into public.daily_limits (user_id, day)
    values (p_user, current_date)
    on conflict (user_id, day) do nothing;

    select * into v_limits
      from public.daily_limits
     where user_id = p_user and day = current_date
     for update;

    if v_limits.swipes_used >= 50 then
      return jsonb_build_object('ok', false, 'error', 'daily_limit_reached');
    end if;

    if p_intent = 'dream' and v_limits.dreams_used >= 3 then
      return jsonb_build_object('ok', false, 'error', 'dream_limit_reached');
    end if;

    update public.daily_limits
       set swipes_used = swipes_used + 1,
           dreams_used = dreams_used + (case when p_intent = 'dream' then 1 else 0 end)
     where user_id = p_user and day = current_date;
  end if;

  -- ---------------------------------------------------------------------------
  -- تسجيل السحبة (إعادة السحب بتحدّث النيّة — عشان زر التراجع)
  -- ---------------------------------------------------------------------------
  insert into public.swipes (user_id, target_item_id, offered_item_id, intent)
  values (p_user, p_target_item, p_offered_item, p_intent)
  on conflict (user_id, target_item_id)
  do update set intent = excluded.intent,
                offered_item_id = excluded.offered_item_id,
                created_at = now();

  if p_intent = 'skip' then
    return jsonb_build_object('ok', true, 'matched', false);
  end if;

  update public.items
     set interested_count = interested_count + 1
   where id = p_target_item;

  -- ---------------------------------------------------------------------------
  -- كشف الماتش المتبادل
  -- ---------------------------------------------------------------------------
  select s.id into v_reciprocal
    from public.swipes s
   where s.user_id = v_target.owner_id
     and s.target_item_id = p_offered_item
     and s.offered_item_id = p_target_item
     and s.intent <> 'skip'
   limit 1;

  if v_reciprocal is null then
    return jsonb_build_object('ok', true, 'matched', false);
  end if;

  -- سقف الغرف النشطة — 10 غرف للمستخدم العادي
  if public.active_room_count(p_user) >= 10
     or public.active_room_count(v_target.owner_id) >= 10 then
    return jsonb_build_object('ok', false, 'error', 'room_limit_reached');
  end if;

  -- ترتيب ثابت للطرفين عشان نمنع التكرار
  if p_user < v_target.owner_id then
    v_a := p_user;            v_b := v_target.owner_id;
    v_item_a := p_offered_item; v_item_b := p_target_item;
  else
    v_a := v_target.owner_id; v_b := p_user;
    v_item_a := p_target_item; v_item_b := p_offered_item;
  end if;

  insert into public.matches (user_a, user_b, item_a, item_b)
  values (v_a, v_b, v_item_a, v_item_b)
  on conflict (user_a, user_b, item_a, item_b) do nothing
  returning id into v_match_id;

  if v_match_id is null then
    select id into v_match_id
      from public.matches
     where user_a = v_a and user_b = v_b
       and item_a = v_item_a and item_b = v_item_b;
  else
    perform public.notify_user(
      v_a, 'match', 'في ماتش جديد 🎉', 'It''s a match 🎉',
      jsonb_build_object('match_id', v_match_id)
    );
    perform public.notify_user(
      v_b, 'match', 'في ماتش جديد 🎉', 'It''s a match 🎉',
      jsonb_build_object('match_id', v_match_id)
    );
  end if;

  return jsonb_build_object('ok', true, 'matched', true, 'match_id', v_match_id);
end;
$$;


-- -----------------------------------------------------------------------------
-- التراجع عن آخر سحبة
--
-- **مجاني وبلا حدود** عن عمد.
--
-- في المقايضة السحبة الغلط مؤلمة أكتر بكتير من تطبيقات التعارف: ممكن
-- تكون فوّت الحاجة الوحيدة اللي بتدور عليها من شهور وممكن ما ترجعش تاني.
-- تحويله لميزة مدفوعة معناه بيع حل لمشكلة إحنا سببناها في أسوأ لحظة.
-- -----------------------------------------------------------------------------
create or replace function public.undo_last_swipe(p_user uuid default auth.uid())
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_swipe public.swipes;
begin
  if p_user is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;

  select * into v_swipe
    from public.swipes
   where user_id = p_user
   order by created_at desc
   limit 1;

  if v_swipe is null then
    return jsonb_build_object('ok', false, 'error', 'nothing_to_undo');
  end if;

  -- التراجع بعد تكوّن الماتش ممنوع — الطرف التاني اتبلغ خلاص
  if exists (
    select 1 from public.matches m
     where (m.item_a = v_swipe.target_item_id and m.item_b = v_swipe.offered_item_id)
        or (m.item_b = v_swipe.target_item_id and m.item_a = v_swipe.offered_item_id)
  ) then
    return jsonb_build_object('ok', false, 'error', 'already_matched');
  end if;

  delete from public.swipes where id = v_swipe.id;

  if v_swipe.intent <> 'skip' then
    update public.items
       set interested_count = greatest(0, interested_count - 1)
     where id = v_swipe.target_item_id;

    update public.daily_limits
       set swipes_used = greatest(0, swipes_used - 1),
           dreams_used = greatest(
             0,
             dreams_used - (case when v_swipe.intent = 'dream' then 1 else 0 end)
           )
     where user_id = p_user and day = current_date;
  end if;

  return jsonb_build_object(
    'ok', true,
    'target_item_id', v_swipe.target_item_id,
    'offered_item_id', v_swipe.offered_item_id
  );
end;
$$;
