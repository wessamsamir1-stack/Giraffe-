-- =============================================================================
-- Giraffe — 13. الإحصائيات ومستوى الثقة والمهام الدورية
-- =============================================================================

-- -----------------------------------------------------------------------------
-- إعادة حساب إحصائيات مستخدم ومستوى ثقته
--
-- كل الحسابات على **آخر 90 يوم** مش على عمر الحساب.
--
-- ليه؟ عشان الناس تقدر تتحسن، والحساب القديم اللي سلوكه بقى سيء
-- ما يستفيدش من قِدَمه. ودي كمان بتقلل جدوى الصفقات الوهمية لأن
-- أثرها بيتلاشى بعد 3 شهور.
--
-- شروط المستويات معلنة في التطبيق — مفيش صندوق أسود:
--   verified : موبايل موثّق + صفقة مكتملة واحدة
--   trusted  : 5 صفقات + تقييم 4.0 + نسبة إلغاء < 20٪
--   elite    : 20 صفقة + تقييم 4.5 + متوسط رد < 6 ساعات
-- -----------------------------------------------------------------------------
create or replace function public.refresh_user_stats(p_user uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_done        int;
  v_cancelled   int;
  v_done_90     int;
  v_cancel_90   int;
  v_no_shows    int;
  v_rating      numeric(3,2);
  v_rating_n    int;
  v_response    int;
  v_phone       boolean;
  v_level       public.trust_level;
  v_cancel_rate numeric;
  v_score       numeric(6,2);
begin
  select coalesce(p.phone_verified, false) into v_phone
    from public.profiles p where p.id = p_user;

  select
    count(*) filter (where m.stage = 'completed'),
    count(*) filter (where m.stage = 'cancelled'),
    count(*) filter (where m.stage = 'completed'
                       and m.closed_at > now() - interval '90 days'),
    count(*) filter (where m.stage = 'cancelled'
                       and m.closed_at > now() - interval '90 days')
  into v_done, v_cancelled, v_done_90, v_cancel_90
  from public.matches m
  where m.user_a = p_user or m.user_b = p_user;

  select count(*) into v_no_shows
    from public.meetings mt
   where mt.no_show_user = p_user;

  select
    coalesce(round(avg(r.overall)::numeric, 2), 0),
    count(*)
  into v_rating, v_rating_n
  from public.reviews r
  where r.reviewee_id = p_user
    and r.published_at is not null;

  -- متوسط زمن الرد على أول رسالة من الطرف التاني في كل غرفة
  select round(avg(extract(epoch from gap) / 60))::int
    into v_response
    from (
      select min(mine.created_at) - min(theirs.created_at) as gap
        from public.matches m
        join public.messages theirs
          on theirs.match_id = m.id
         and theirs.sender_id is distinct from p_user
         and theirs.kind <> 'system'
        join public.messages mine
          on mine.match_id = m.id
         and mine.sender_id = p_user
         and mine.created_at > theirs.created_at
       where (m.user_a = p_user or m.user_b = p_user)
         and m.created_at > now() - interval '90 days'
       group by m.id
    ) response_times
   where gap is not null;

  v_cancel_rate := case
    when (v_done_90 + v_cancel_90) = 0 then 0
    else v_cancel_90::numeric / (v_done_90 + v_cancel_90)
  end;

  -- ---------------------------------------------------------------------------
  -- المستوى
  -- ---------------------------------------------------------------------------
  v_level := 'new';

  if v_phone and v_done >= 1 then
    v_level := 'verified';
  end if;

  if v_phone and v_done >= 5 and v_rating >= 4.0 and v_cancel_rate < 0.20 then
    v_level := 'trusted';
  end if;

  if v_phone and v_done >= 20 and v_rating >= 4.5
     and coalesce(v_response, 999999) <= 360 then
    v_level := 'elite';
  end if;

  -- ---------------------------------------------------------------------------
  -- الدرجة المخفية للترتيب الداخلي — المستخدم مابيشوفهاش أبداً
  -- ---------------------------------------------------------------------------
  v_score := least(100,
      least(v_done_90, 20) * 2.0
    + v_rating * 6.0
    + case when v_phone then 8 else 0 end
    + case
        when v_response is null then 0
        when v_response <= 60  then 12
        when v_response <= 360 then 8
        when v_response <= 1440 then 4
        else 0
      end
    - v_cancel_rate * 25
    - least(v_no_shows, 5) * 4
  );

  insert into public.user_stats as s (
    user_id, completed_trades, cancelled_trades, no_shows,
    completed_trades_90d, cancelled_trades_90d,
    rating_avg, rating_count, avg_response_minutes,
    trust_level, ranking_score, computed_at
  )
  values (
    p_user, v_done, v_cancelled, v_no_shows,
    v_done_90, v_cancel_90,
    v_rating, v_rating_n, v_response,
    v_level, greatest(0, v_score), now()
  )
  on conflict (user_id) do update set
    completed_trades     = excluded.completed_trades,
    cancelled_trades     = excluded.cancelled_trades,
    no_shows             = excluded.no_shows,
    completed_trades_90d = excluded.completed_trades_90d,
    cancelled_trades_90d = excluded.cancelled_trades_90d,
    rating_avg           = excluded.rating_avg,
    rating_count         = excluded.rating_count,
    avg_response_minutes = excluded.avg_response_minutes,
    trust_level          = excluded.trust_level,
    ranking_score        = excluded.ranking_score,
    computed_at          = now();
end;
$$;


-- -----------------------------------------------------------------------------
-- عدّاد قوائم الرغبات على المنتج
-- -----------------------------------------------------------------------------
create or replace function public.tg_sync_wishlist_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.items
     set wishlist_count = wishlist_count + 1
   where id = new.item_id;
  return new;
end;
$$;

create trigger wishlist_alerts_count
  after insert on public.wishlist_alerts
  for each row execute function public.tg_sync_wishlist_count();


-- =============================================================================
-- المهام الدورية
--
-- على سوبابيز بتتجدول بـ pg_cron. محلياً بتتنادى يدوي في الاختبارات.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- فك الحجوزات المنتهية (48 ساعة)
--
-- من غير الوظيفة دي، منتج اتقبل عليه عرض وما اكتملش بيفضل مقفول للأبد.
-- -----------------------------------------------------------------------------
create or replace function public.release_expired_reservations()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  affected int;
begin
  with released as (
    update public.items
       set status = 'available',
           reserved_until = null,
           reserved_match_id = null
     where status = 'reserved'
       and reserved_until is not null
       and reserved_until < now()
    returning id
  )
  select count(*) into affected from released;

  update public.offers
     set status = 'expired'
   where status = 'pending'
     and expires_at < now();

  return affected;
end;
$$;


-- -----------------------------------------------------------------------------
-- أرشفة الغرف الخاملة 30 يوم
--
-- الغرفة ما بتختفيش بمزاج طرف واحد، لكن الخمول الطويل بيأرشفها تلقائياً.
-- الأرشفة مش حذف — المستخدم يقدر يحييها بضغطة، والسجل بيفضل موجود.
-- -----------------------------------------------------------------------------
create or replace function public.archive_stale_matches()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  affected int;
begin
  with archived as (
    update public.matches
       set archived_at = now()
     where archived_at is null
       and closed_at is null
       and stage in ('negotiating', 'offer_pending')
       and last_activity_at < now() - interval '30 days'
    returning id
  )
  select count(*) into affected from archived;

  -- المنتجات ترجع متاحة عشان ما تفضلش محبوسة في غرفة ميتة
  update public.items i
     set status = 'available'
    from public.matches m
   where m.archived_at is not null
     and i.status = 'negotiating'
     and i.id in (m.item_a, m.item_b);

  return affected;
end;
$$;


-- -----------------------------------------------------------------------------
-- تحديث إحصائيات كل المستخدمين اللي عندهم نشاط حديث
-- -----------------------------------------------------------------------------
create or replace function public.refresh_stale_stats(p_batch int default 500)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  n int := 0;
begin
  for r in
    select user_id
      from public.user_stats
     where computed_at < now() - interval '24 hours'
     order by computed_at asc
     limit p_batch
  loop
    perform public.refresh_user_stats(r.user_id);
    n := n + 1;
  end loop;
  return n;
end;
$$;


-- -----------------------------------------------------------------------------
-- تنظيف الحدود اليومية القديمة
-- -----------------------------------------------------------------------------
create or replace function public.purge_old_daily_limits()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  affected int;
begin
  with deleted as (
    delete from public.daily_limits
     where day < current_date - 7
    returning user_id
  )
  select count(*) into affected from deleted;
  return affected;
end;
$$;


-- -----------------------------------------------------------------------------
-- جدولة المهام — تتفعّل على سوبابيز بعد تفعيل pg_cron
--
--   select cron.schedule('release-reservations', '*/15 * * * *',
--     $$ select public.release_expired_reservations() $$);
--
--   select cron.schedule('archive-stale', '0 3 * * *',
--     $$ select public.archive_stale_matches() $$);
--
--   select cron.schedule('publish-reviews', '0 4 * * *',
--     $$ select public.publish_due_reviews() $$);
--
--   select cron.schedule('refresh-stats', '0 * * * *',
--     $$ select public.refresh_stale_stats() $$);
--
--   select cron.schedule('purge-limits', '30 3 * * *',
--     $$ select public.purge_old_daily_limits() $$);
-- -----------------------------------------------------------------------------
