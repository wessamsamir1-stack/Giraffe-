-- =============================================================================
-- Giraffe — اختبارات الدخان
--
-- بتثبت إن المحرك بيشتغل فعلاً، مش إن السكيما بتتصرّف بس.
-- أي فشل بيوقف السكريبت بـ exception.
-- =============================================================================

\set ON_ERROR_STOP on
\timing off

create or replace function public.assert_true(cond boolean, label text)
returns void language plpgsql as $$
begin
  if cond is not true then
    raise exception '✗ FAILED: %', label;
  end if;
  raise notice '  ✓ %', label;
end;
$$;

create or replace function public.assert_eq(a anyelement, b anyelement, label text)
returns void language plpgsql as $$
begin
  if a is distinct from b then
    raise exception '✗ FAILED: % — expected %, got %', label, b, a;
  end if;
  raise notice '  ✓ % (%)', label, a;
end;
$$;


-- =============================================================================
do $$ begin raise notice E'\n▶ 1. تجهيز المستخدمين والمنتجات'; end $$;
-- =============================================================================

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'wessam@test.local'),
  ('22222222-2222-2222-2222-222222222222', 'ahmed@test.local'),
  ('33333333-3333-3333-3333-333333333333', 'mona@test.local');

insert into public.profiles
  (id, username, display_name, country_code, city_id, area_id, lat, lng, phone_verified)
values
  ('11111111-1111-1111-1111-111111111111', 'wessam', 'وسام سمير',
   'EG', 'cairo', 'cairo.nasr', 30.0626, 31.3450, true),
  ('22222222-2222-2222-2222-222222222222', 'ahmed', 'أحمد فتحي',
   'EG', 'giza', 'giza.dokki', 30.0380, 31.2120, true),
  ('33333333-3333-3333-3333-333333333333', 'mona', 'منى حسن',
   'EG', 'cairo', 'cairo.maadi', 29.9600, 31.2570, true);

-- المنتجات
insert into public.items
  (id, owner_id, title, description, category_id, subcategory_id, condition,
   status, moderation, value_min, value_max, currency_code, ai_confidence,
   comparable_count, country_code, city_id, lat, lng, published_at)
values
  ('aaaaaaaa-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111',
   'بلايستيشن 5 سليم مع دراعين', 'استعمال خفيف بالكرتونة',
   'gaming', 'gaming.consoles', 'like_new', 'available', 'approved',
   24000, 28000, 'EGP', 0.87, 23, 'EG', 'cairo', 30.0626, 31.3450, now()),

  ('aaaaaaaa-0000-0000-0000-000000000002',
   '22222222-2222-2222-2222-222222222222',
   'آيفون 15 برو 256 جيجا', 'بطارية 94% بالعلبة',
   'mobiles', 'mobiles.phones', 'like_new', 'available', 'approved',
   38000, 44000, 'EGP', 0.93, 31, 'EG', 'giza', 30.0380, 31.2120, now()),

  ('aaaaaaaa-0000-0000-0000-000000000003',
   '33333333-3333-3333-3333-333333333333',
   'أنتريه مودرن 3 قطع', 'حالة ممتازة',
   'furniture', 'furniture.living', 'good', 'available', 'approved',
   12000, 16000, 'EGP', 0.68, 21, 'EG', 'cairo', 29.9600, 31.2570, now());

-- بيقايض بإيه
insert into public.item_wanted_categories (item_id, category_id, subcategory_id) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'mobiles',    'mobiles.phones'),
  ('aaaaaaaa-0000-0000-0000-000000000002', 'gaming',     'gaming.consoles'),
  ('aaaaaaaa-0000-0000-0000-000000000003', 'appliances', null);

-- قوائم الرغبات (3 لكل مستخدم = الحد الأدنى للإعداد الأولي)
insert into public.wishlist_items (user_id, category_id, subcategory_id, keyword) values
  ('11111111-1111-1111-1111-111111111111', 'mobiles',    'mobiles.phones',   'ايفون'),
  ('11111111-1111-1111-1111-111111111111', 'computers',  null,               null),
  ('11111111-1111-1111-1111-111111111111', 'cameras',    null,               null),

  ('22222222-2222-2222-2222-222222222222', 'gaming',     'gaming.consoles',  'بلايستيشن'),
  ('22222222-2222-2222-2222-222222222222', 'electronics',null,               null),
  ('22222222-2222-2222-2222-222222222222', 'tools',      null,               null),

  ('33333333-3333-3333-3333-333333333333', 'appliances', null,               null),
  ('33333333-3333-3333-3333-333333333333', 'books',      null,               null),
  ('33333333-3333-3333-3333-333333333333', 'sports',     null,               null);

do $$
begin
  perform public.assert_true(
    public.is_setup_complete('11111111-1111-1111-1111-111111111111'),
    'الإعداد الأولي مكتمل لوسام');
  perform public.assert_true(
    public.is_setup_complete('22222222-2222-2222-2222-222222222222'),
    'الإعداد الأولي مكتمل لأحمد');
end $$;


-- =============================================================================
do $$ begin raise notice E'\n▶ 2. تطبيع النص العربي'; end $$;
-- =============================================================================
do $$
begin
  perform public.assert_eq(public.normalize_ar('آيفون'), 'ايفون', 'آ ← ا');
  perform public.assert_eq(public.normalize_ar('إيفون'), 'ايفون', 'إ ← ا');
  perform public.assert_eq(public.normalize_ar('أيفون'), 'ايفون', 'أ ← ا');
  perform public.assert_eq(public.normalize_ar('شنطـــة'), 'شنطه', 'التطويل والتاء المربوطة');
  perform public.assert_eq(public.normalize_ar('كامِيرَا'), 'كاميرا', 'إزالة التشكيل');
end $$;


-- =============================================================================
do $$ begin raise notice E'\n▶ 3. درجة تطابق قائمة الرغبات'; end $$;
-- =============================================================================
do $$
declare
  iphone public.items;
  sofa   public.items;
  score  int;
begin
  select * into iphone from public.items where id = 'aaaaaaaa-0000-0000-0000-000000000002';
  select * into sofa   from public.items where id = 'aaaaaaaa-0000-0000-0000-000000000003';

  score := public.wishlist_match_score('11111111-1111-1111-1111-111111111111', iphone);
  perform public.assert_true(score >= 85,
    'وسام عايز الآيفون بقوة (الدرجة ' || score || ')');

  score := public.wishlist_match_score('11111111-1111-1111-1111-111111111111', sofa);
  perform public.assert_eq(score, 0, 'وسام مش عايز الأنتريه');
end $$;


-- =============================================================================
do $$ begin raise notice E'\n▶ 4. الـ deck وشرط الترشيح المزدوج'; end $$;
-- =============================================================================
do $$
declare
  n     int;
  row_  record;
begin
  -- وسام: لازم يشوف الآيفون بس. الأنتريه مفلتر لأنه مش في رغباته.
  select count(*) into n
    from public.get_deck('11111111-1111-1111-1111-111111111111', 20);
  perform public.assert_eq(n, 1, 'وسام بيشوف كارت واحد');

  select * into row_
    from public.get_deck('11111111-1111-1111-1111-111111111111', 20);

  perform public.assert_eq(row_.their_item_id,
    'aaaaaaaa-0000-0000-0000-000000000002'::uuid, 'الكارت هو الآيفون');
  perform public.assert_eq(row_.my_item_id,
    'aaaaaaaa-0000-0000-0000-000000000001'::uuid, 'المقابل هو البلايستيشن');
  perform public.assert_true(row_.compatibility >= 70,
    'التوافق عالي (' || row_.compatibility || '٪)');
  perform public.assert_true(row_.cash_delta > 0,
    'وسام بيدفع فرق (' || row_.cash_delta || ' ج.م)');
  perform public.assert_true(row_.distance_km between 0 and 30,
    'المسافة منطقية (' || row_.distance_km || ' كم)');

  -- أحمد: لازم يشوف البلايستيشن بنفس الاقتران بالظبط
  select * into row_
    from public.get_deck('22222222-2222-2222-2222-222222222222', 20);
  perform public.assert_eq(row_.their_item_id,
    'aaaaaaaa-0000-0000-0000-000000000001'::uuid, 'أحمد بيشوف البلايستيشن');
  perform public.assert_true(row_.cash_delta < 0,
    'أحمد بيستلم فرق (' || row_.cash_delta || ')');

  -- منى: مفيش حد عنده أجهزة منزلية → الـ deck فاضي
  select count(*) into n
    from public.get_deck('33333333-3333-3333-3333-333333333333', 20);
  perform public.assert_eq(n, 0, 'منى مفيش لها كروت — مفيش سيولة في قسمها');
end $$;


-- =============================================================================
do $$ begin raise notice E'\n▶ 5. الماتش المتبادل'; end $$;
-- =============================================================================
do $$
declare
  res     jsonb;
  v_match uuid;
  st      public.item_status;
begin
  -- سحبة من طرف واحد = مفيش ماتش
  res := public.record_swipe(
    'aaaaaaaa-0000-0000-0000-000000000002',
    'aaaaaaaa-0000-0000-0000-000000000001',
    'interested',
    '11111111-1111-1111-1111-111111111111');
  perform public.assert_true((res->>'ok')::boolean, 'سحبة وسام اتسجلت');
  perform public.assert_eq((res->>'matched')::boolean, false,
    'مفيش ماتش من طرف واحد');

  -- الطرف التاني = ماتش
  res := public.record_swipe(
    'aaaaaaaa-0000-0000-0000-000000000001',
    'aaaaaaaa-0000-0000-0000-000000000002',
    'interested',
    '22222222-2222-2222-2222-222222222222');
  perform public.assert_eq((res->>'matched')::boolean, true,
    'الماتش اتكوّن لما الطرفين وافقوا');

  v_match := (res->>'match_id')::uuid;
  perform public.assert_true(v_match is not null, 'رقم الماتش رجع');

  -- المنتجان بقوا في التفاوض
  select status into st from public.items
   where id = 'aaaaaaaa-0000-0000-0000-000000000001';
  perform public.assert_eq(st, 'negotiating'::public.item_status,
    'البلايستيشن بقى في التفاوض');

  -- رسالة نظام اتبعتت
  perform public.assert_true(
    exists (select 1 from public.messages m
             where m.match_id = v_match
               and m.kind = 'system' and m.body = 'match_created'),
    'رسالة النظام اتبعتت في الغرفة');

  -- الطرفين اتبلغوا
  perform public.assert_eq(
    (select count(*)::int from public.notifications where kind = 'match'), 2,
    'إشعار الماتش راح للطرفين');

  -- الكارت مابيرجعش تاني بعد السحب
  perform public.assert_eq(
    (select count(*)::int from public.get_deck('11111111-1111-1111-1111-111111111111')),
    0, 'الكارت المسحوب مابيتكررش');
end $$;


-- =============================================================================
do $$ begin raise notice E'\n▶ 6. دورة العرض والحجز'; end $$;
-- =============================================================================
do $$
declare
  m_id     uuid;
  v_offer  uuid;
  st       public.item_status;
  v_stage  public.trade_stage;
  until_   timestamptz;
begin
  select id into m_id from public.matches limit 1;

  insert into public.offers
    (match_id, from_user, give_item_id, get_item_id, cash_delta, currency_code)
  values
    (m_id, '11111111-1111-1111-1111-111111111111',
     'aaaaaaaa-0000-0000-0000-000000000001',
     'aaaaaaaa-0000-0000-0000-000000000002',
     14000, 'EGP')
  returning id into v_offer;

  select m.stage into v_stage from public.matches m where m.id = m_id;
  perform public.assert_eq(v_stage, 'offer_pending'::public.trade_stage,
    'الغرفة بقت في انتظار الرد');

  perform public.assert_true(
    exists (select 1 from public.messages m
             where m.offer_id = v_offer and m.kind = 'offer'),
    'كارت العرض ظهر في المحادثة');

  -- القبول = حجز 48 ساعة
  update public.offers set status = 'accepted' where id = v_offer;

  select status, reserved_until into st, until_
    from public.items where id = 'aaaaaaaa-0000-0000-0000-000000000002';

  perform public.assert_eq(st, 'reserved'::public.item_status,
    'الآيفون اتحجز بعد قبول العرض');
  perform public.assert_true(
    until_ between now() + interval '47 hours' and now() + interval '49 hours',
    'الحجز 48 ساعة');

  select m.stage into v_stage from public.matches m where m.id = m_id;
  perform public.assert_eq(v_stage, 'agreed'::public.trade_stage, 'الطرفان متفقان');
end $$;


-- =============================================================================
do $$ begin raise notice E'\n▶ 7. اللقاء والإتمام بتأكيد الطرفين'; end $$;
-- =============================================================================
do $$
declare
  m_id    uuid;
  place   uuid;
  st      public.item_status;
  v_stage public.trade_stage;
  trades  int;
begin
  select id into m_id from public.matches limit 1;
  select id into place from public.meeting_places where city_id = 'cairo' limit 1;

  insert into public.meetings (match_id, place_id, scheduled_at, created_by)
  values (m_id, place, now() + interval '2 days',
          '11111111-1111-1111-1111-111111111111');

  select m.stage into v_stage from public.matches m where m.id = m_id;
  perform public.assert_eq(v_stage, 'meeting_set'::public.trade_stage,
    'اللقاء اتحدد');

  -- تأكيد طرف واحد مش كفاية
  insert into public.trade_confirmations (match_id, user_id, code, confirmed_at)
  values (m_id, '11111111-1111-1111-1111-111111111111', 'CODE-A', now());

  select m.stage into v_stage from public.matches m where m.id = m_id;
  perform public.assert_true(v_stage <> 'completed'::public.trade_stage,
    'تأكيد طرف واحد مش بيكمّل الصفقة');

  -- الطرف التاني يأكد
  insert into public.trade_confirmations (match_id, user_id, code, confirmed_at)
  values (m_id, '22222222-2222-2222-2222-222222222222', 'CODE-B', now());

  select m.stage into v_stage from public.matches m where m.id = m_id;
  perform public.assert_eq(v_stage, 'completed'::public.trade_stage,
    'الصفقة اكتملت بتأكيد الطرفين');

  select status into st from public.items
   where id = 'aaaaaaaa-0000-0000-0000-000000000002';
  perform public.assert_eq(st, 'traded'::public.item_status,
    'الآيفون اتسجل مقايَض');

  select completed_trades into trades from public.user_stats
   where user_id = '11111111-1111-1111-1111-111111111111';
  perform public.assert_eq(trades, 1, 'عدّاد صفقات وسام اتحدّث');
end $$;


-- =============================================================================
do $$ begin raise notice E'\n▶ 8. التقييم المحجوب'; end $$;
-- =============================================================================
do $$
declare
  m_id      uuid;
  published timestamptz;
  lvl       public.trust_level;
begin
  select id into m_id from public.matches limit 1;

  insert into public.reviews (match_id, reviewer_id, reviewee_id, overall, comment)
  values (m_id, '11111111-1111-1111-1111-111111111111',
          '22222222-2222-2222-2222-222222222222', 5, 'تعامل محترم');

  select published_at into published from public.reviews
   where reviewer_id = '11111111-1111-1111-1111-111111111111';
  perform public.assert_true(published is null,
    'التقييم محجوب لحد ما الطرف التاني يقيّم');

  insert into public.reviews (match_id, reviewer_id, reviewee_id, overall)
  values (m_id, '22222222-2222-2222-2222-222222222222',
          '11111111-1111-1111-1111-111111111111', 5);

  perform public.assert_eq(
    (select count(*)::int from public.reviews where published_at is not null),
    2, 'التقييمان اتنشروا مع بعض');

  select trust_level into lvl from public.user_stats
   where user_id = '11111111-1111-1111-1111-111111111111';
  perform public.assert_eq(lvl, 'verified'::public.trust_level,
    'مستوى الثقة ترقّى لموثّق');
end $$;


-- =============================================================================
do $$ begin raise notice E'\n▶ 9. الحدود اليومية والتراجع'; end $$;
-- =============================================================================
do $$
declare
  res  jsonb;
  used int;
begin
  select swipes_used into used from public.daily_limits
   where user_id = '11111111-1111-1111-1111-111111111111'
     and day = current_date;
  perform public.assert_eq(used, 1, 'سحبة واحدة اتحسبت');

  -- تعدية السقف
  update public.daily_limits set swipes_used = 50
   where user_id = '33333333-3333-3333-3333-333333333333'
      or true;
  insert into public.daily_limits (user_id, day, swipes_used)
  values ('33333333-3333-3333-3333-333333333333', current_date, 50)
  on conflict (user_id, day) do update set swipes_used = 50;

  res := public.record_swipe(
    'aaaaaaaa-0000-0000-0000-000000000001',
    'aaaaaaaa-0000-0000-0000-000000000003',
    'interested',
    '33333333-3333-3333-3333-333333333333');
  perform public.assert_eq(res->>'error', 'daily_limit_reached',
    'السقف اليومي بيتفرض');

  -- التراجع بعد الماتش ممنوع
  res := public.undo_last_swipe('11111111-1111-1111-1111-111111111111');
  perform public.assert_eq(res->>'error', 'already_matched',
    'مينفعش تتراجع بعد ما الماتش اتكوّن');
end $$;


-- =============================================================================
do $$ begin raise notice E'\n▶ 10. الحظر بيكسر كل القواعد'; end $$;
-- =============================================================================
do $$
declare
  m_id   uuid;
  closed boolean;
begin
  -- ماتش جديد بين منى وأحمد عشان نختبر الحظر عليه
  insert into public.matches (user_a, user_b, item_a, item_b)
  values (
    least('22222222-2222-2222-2222-222222222222'::uuid,
          '33333333-3333-3333-3333-333333333333'::uuid),
    greatest('22222222-2222-2222-2222-222222222222'::uuid,
             '33333333-3333-3333-3333-333333333333'::uuid),
    'aaaaaaaa-0000-0000-0000-000000000002',
    'aaaaaaaa-0000-0000-0000-000000000003')
  returning id into m_id;

  insert into public.blocks (blocker_id, blocked_id)
  values ('33333333-3333-3333-3333-333333333333',
          '22222222-2222-2222-2222-222222222222');

  select closed_by_block into closed from public.matches where id = m_id;
  perform public.assert_true(closed,
    'الحظر قفل الغرفة فوراً حتى بعد الاتفاق');

  perform public.assert_true(
    public.blocked_between('22222222-2222-2222-2222-222222222222',
                           '33333333-3333-3333-3333-333333333333'),
    'الحظر بيتقرا في الاتجاهين');
end $$;


-- =============================================================================
do $$ begin raise notice E'\n▶ 11. حدود قائمة الرغبات'; end $$;
-- =============================================================================
do $$
declare
  failed boolean := false;
begin
  begin
    insert into public.wishlist_items (user_id, category_id) values
      ('11111111-1111-1111-1111-111111111111', 'vehicles'),
      ('11111111-1111-1111-1111-111111111111', 'furniture'),
      ('11111111-1111-1111-1111-111111111111', 'appliances'),
      ('11111111-1111-1111-1111-111111111111', 'fashion'),
      ('11111111-1111-1111-1111-111111111111', 'watches'),
      ('11111111-1111-1111-1111-111111111111', 'kids'),
      ('11111111-1111-1111-1111-111111111111', 'sports'),
      ('11111111-1111-1111-1111-111111111111', 'hobbies');
  exception when others then
    failed := true;
  end;

  perform public.assert_true(failed, 'سقف الـ 10 رغبات بيتفرض');
end $$;


-- =============================================================================
do $$ begin raise notice E'\n▶ 12. المهام الدورية'; end $$;
-- =============================================================================
do $$
declare
  n int;
begin
  n := public.release_expired_reservations();
  perform public.assert_true(n >= 0, 'فك الحجوزات بيشتغل');

  n := public.archive_stale_matches();
  perform public.assert_true(n >= 0, 'أرشفة الغرف الخاملة بتشتغل');

  n := public.publish_due_reviews();
  perform public.assert_true(n >= 0, 'نشر التقييمات المتأخرة بيشتغل');

  n := public.refresh_stale_stats(10);
  perform public.assert_true(n >= 0, 'تحديث الإحصائيات بيشتغل');
end $$;


-- =============================================================================
do $$ begin raise notice E'\n▶ 13. فحص المحتوى'; end $$;
-- =============================================================================
do $$
declare
  hits int;
begin
  select count(*) into hits from public.screen_text('للبيع مسدس حالة ممتازة');
  perform public.assert_true(hits > 0, 'كشف السلاح');

  select count(*) into hits from public.screen_text('آيفون 15 برو بالكرتونة');
  perform public.assert_eq(hits, 0, 'المنتج السليم عدّى من غير إنذار');
end $$;


-- =============================================================================
do $$ begin raise notice E'\n▶ 14. الحماية على مستوى الصف'; end $$;
-- =============================================================================

set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

do $$
declare
  n int;
begin
  -- قائمة رغبات الغير مالهاش وصول
  select count(*) into n from public.wishlist_items
   where user_id = '22222222-2222-2222-2222-222222222222';
  perform public.assert_eq(n, 0, 'قائمة رغبات الغير مخفية');

  -- سحبات الغير مالهاش وصول
  select count(*) into n from public.swipes
   where user_id = '22222222-2222-2222-2222-222222222222';
  perform public.assert_eq(n, 0, 'سحبات الغير مخفية');

  -- بس رغباتي أنا شغالة
  select count(*) into n from public.wishlist_items;
  perform public.assert_true(n >= 3, 'رغباتي أنا ظاهرة (' || n || ')');

  -- جهة الطوارئ خاصة تماماً
  select count(*) into n from public.emergency_contacts;
  perform public.assert_eq(n, 0, 'جهات طوارئ الغير مخفية');

  -- الجداول المرجعية مقروءة
  select count(*) into n from public.categories;
  perform public.assert_eq(n, 21, 'الأقسام مقروءة للجميع');
end $$;

do $$
declare
  blocked boolean := false;
begin
  begin
    perform ranking_score from public.user_stats limit 1;
  exception when insufficient_privilege then
    blocked := true;
  end;
  perform public.assert_true(blocked,
    'درجة الترتيب المخفية مش متاحة للمستخدم');
end $$;

reset role;
reset request.jwt.claim.sub;


-- =============================================================================
do $$ begin raise notice E'\n▶ 15. سلامة البيانات المرجعية'; end $$;
-- =============================================================================
do $$
declare
  n int;
begin
  perform public.assert_eq(
    (select count(*)::int from public.categories), 21, 'عدد الأقسام');
  perform public.assert_eq(
    (select count(*)::int from public.subcategories), 113, 'عدد الأقسام الفرعية');
  perform public.assert_eq(
    (select count(*)::int from public.categories where restricted), 2,
    'قسمان مقيّدان فقط');
  perform public.assert_eq(
    (select count(*)::int from public.categories where id = 'realestate'), 0,
    'العقارات مستبعدة');
  perform public.assert_eq(
    (select count(*)::int from public.categories where is_service), 1,
    'قسم الخدمات موجود');

  perform public.assert_eq(
    (select count(*)::int from public.countries where is_active), 1,
    'مصر فقط مفعّلة');
  perform public.assert_eq(
    (select count(*)::int from public.cities where is_active), 2,
    'القاهرة والجيزة فقط مفعّلتان');

  perform public.assert_eq(
    (select currency_decimals::int from public.countries where code = 'KW'), 3,
    'الدينار الكويتي 3 خانات عشرية');
  perform public.assert_eq(
    (select currency_decimals::int from public.countries where code = 'EG'), 2,
    'الجنيه المصري خانتان');

  -- كل جدول لازم يكون عليه RLS
  select count(*) into n
    from pg_tables t
    join pg_class c on c.relname = t.tablename
   where t.schemaname = 'public'
     and not c.relrowsecurity;
  perform public.assert_eq(n, 0, 'RLS مفعّل على كل الجداول');
end $$;

-- =============================================================================
do $$ begin raise notice E'\n▶ 16. الذكاء الاصطناعي: الميزانية والتقدير والفحص'; end $$;
-- =============================================================================
do $$
declare
  quota  jsonb;
  screen jsonb;
  est    jsonb;
  n      int;
begin
  -- الميزانية متاحة لمستخدم جديد
  quota := public.ai_quota_check('11111111-1111-1111-1111-111111111111');
  perform public.assert_eq((quota->>'allowed')::boolean, true,
    'الميزانية متاحة في البداية');

  -- تعدية سقف المستخدم
  insert into public.ai_jobs (user_id, kind, status, cost_cents)
  values ('11111111-1111-1111-1111-111111111111', 'analyze_item', 'done', 40);

  quota := public.ai_quota_check('11111111-1111-1111-1111-111111111111');
  perform public.assert_eq(quota->>'reason', 'user_budget_exceeded',
    'سقف التكلفة اليومي بيتفرض');

  -- الفحص المبدئي: منتج نضيف
  screen := public.prescreen_item('aaaaaaaa-0000-0000-0000-000000000002');
  perform public.assert_eq(screen->>'decision', 'approved',
    'الآيفون عدّى الفحص المبدئي');

  -- الفحص المبدئي: منتج ممنوع
  update public.items
     set title = 'مسدس للبيع'
   where id = 'aaaaaaaa-0000-0000-0000-000000000003';

  screen := public.prescreen_item('aaaaaaaa-0000-0000-0000-000000000003');
  perform public.assert_eq(screen->>'decision', 'rejected',
    'السلاح اترفض قبل ما ننادي أي موديل');

  -- التقدير من المقارنات — مفيش بيانات لسه
  est := public.estimate_from_comparables('EG', 'mobiles', 'mobiles.phones',
                                          'Apple', 'iPhone 15 Pro', 'like_new');
  perform public.assert_true(est is null,
    'مفيش تقدير من غير مقارنات كفاية — والحافة هي اللي بتنادي النموذج');

  -- نغذّي مقارنات كفاية
  insert into public.price_comparables
    (country_code, category_id, subcategory_id, brand, model, condition,
     value_min, value_max, sample_size, source)
  select 'EG', 'mobiles', 'mobiles.phones', 'Apple', 'iPhone 15 Pro',
         'like_new', 38000, 44000, 3, 'seeded'
    from generate_series(1, 3);

  est := public.estimate_from_comparables('EG', 'mobiles', 'mobiles.phones',
                                          'Apple', 'iPhone 15 Pro', 'like_new');
  perform public.assert_true(est is not null, 'التقدير بيطلع من مقارناتنا');
  perform public.assert_eq(est->>'source', 'comparables_model',
    'المصدر: مطابقة الموديل');
  perform public.assert_true((est->>'confidence')::numeric >= 0.9,
    'ثقة عالية للمطابقة الدقيقة');

  -- الاعتماد بينشر المنتج
  update public.items set moderation = 'pending', status = 'pending'
   where id = 'aaaaaaaa-0000-0000-0000-000000000002';

  perform public.apply_moderation('aaaaaaaa-0000-0000-0000-000000000002',
                                  'approved');

  select count(*)::int into n from public.items
   where id = 'aaaaaaaa-0000-0000-0000-000000000002'
     and status = 'available' and published_at is not null;
  perform public.assert_eq(n, 1, 'الاعتماد نشر المنتج');

  -- الرفض بيبلّغ صاحبه
  perform public.apply_moderation('aaaaaaaa-0000-0000-0000-000000000003',
                                  'rejected', 'سلاح');

  select count(*)::int into n from public.items
   where id = 'aaaaaaaa-0000-0000-0000-000000000003' and status = 'rejected';
  perform public.assert_eq(n, 1, 'المنتج الممنوع اترفض');

  perform public.assert_true(
    exists (select 1 from public.notifications
             where kind = 'system' and title_ar like '%اترفض%'),
    'صاحب المنتج المرفوض اتبلّغ بالسبب');

  -- التعلّم من الصفقات المكتملة
  select count(*)::int into n from public.price_comparables
   where source = 'internal';

  perform public.learn_from_completed_trade(
    (select id from public.matches where stage = 'completed' limit 1));

  perform public.assert_true(
    (select count(*)::int from public.price_comparables
      where source = 'internal') > n,
    'الصفقة المكتملة غذّت جدول المقارنات');
end $$;


-- =============================================================================
do $$ begin raise notice E'\n▶ 17. حارس الفحص — المستخدم مايعتمدش نفسه'; end $$;
-- =============================================================================

-- تجهيز بصلاحيات الخادم: منتج معتمد لوسام، ومنتج مرفوض ليه كمان
do $$
begin
  update public.items
     set status = 'pending', moderation = 'pending', published_at = null
   where id = 'aaaaaaaa-0000-0000-0000-000000000001';

  perform public.apply_moderation('aaaaaaaa-0000-0000-0000-000000000001',
                                  'approved');

  insert into public.items
    (id, owner_id, title, category_id, currency_code, country_code, city_id,
     status, moderation)
  values
    ('aaaaaaaa-0000-0000-0000-0000000000e1',
     '11111111-1111-1111-1111-111111111111',
     'منتج اترفض', 'mobiles', 'EGP', 'EG', 'cairo', 'rejected', 'rejected');
end $$;

set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

do $$
declare
  it public.items;
begin
  -- ---------------------------------------------------------------------------
  -- المحاولة المباشرة: اعتمد نفسك
  -- ---------------------------------------------------------------------------
  update public.items
     set moderation = 'approved', status = 'available'
   where id = 'aaaaaaaa-0000-0000-0000-0000000000e1';

  select * into it from public.items
   where id = 'aaaaaaaa-0000-0000-0000-0000000000e1';

  perform public.assert_eq(it.moderation::text, 'rejected',
    'المستخدم مايقدرش يعتمد منتجه بنفسه');
  perform public.assert_true(it.status::text <> 'available',
    'والمنتج المرفوض مابيبقاش متاح');

  -- ---------------------------------------------------------------------------
  -- المحاولة غير المباشرة: عدّل عنوان منتج معتمد بعد ما عدّى
  -- ---------------------------------------------------------------------------
  update public.items
     set title = 'مسدس بحالة ممتازة'
   where id = 'aaaaaaaa-0000-0000-0000-000000000001';

  select * into it from public.items
   where id = 'aaaaaaaa-0000-0000-0000-000000000001';

  perform public.assert_eq(it.moderation::text, 'pending',
    'التعديل الجوهري رجّع المنتج للفحص');
  perform public.assert_eq(it.status::text, 'pending',
    'واتشال من السوق لحد ما يتفحص تاني');
  perform public.assert_true(it.published_at is null,
    'وتاريخ النشر اتلغى');

  -- ---------------------------------------------------------------------------
  -- نداء دالة الاعتماد مباشرة — الباب التالت
  -- ---------------------------------------------------------------------------
  declare
    blocked boolean := false;
  begin
    begin
      perform public.apply_moderation('aaaaaaaa-0000-0000-0000-000000000001',
                                      'approved');
    exception when insufficient_privilege then
      blocked := true;
    end;
    perform public.assert_true(blocked,
      'دالة الاعتماد نفسها مش متاحة للمستخدم');
  end;
end $$;

-- ---------------------------------------------------------------------------
-- التعديل المشروع مايتعاقبش
-- ---------------------------------------------------------------------------
reset role;
reset request.jwt.claim.sub;

do $$
begin
  perform public.apply_moderation('aaaaaaaa-0000-0000-0000-000000000001',
                                  'approved');
end $$;

set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

do $$
declare
  it public.items;
begin
  update public.items set will_pay_up_to = 500
   where id = 'aaaaaaaa-0000-0000-0000-000000000001';

  select * into it from public.items
   where id = 'aaaaaaaa-0000-0000-0000-000000000001';

  perform public.assert_eq(it.moderation::text, 'approved',
    'تعديل السعر مش جوهري — الاعتماد فضل');
  perform public.assert_eq(it.status::text, 'available',
    'والمنتج فضل في السوق');
end $$;

-- ---------------------------------------------------------------------------
-- والإدخال كمان
-- ---------------------------------------------------------------------------
do $$
declare
  it public.items;
begin
  insert into public.items
    (id, owner_id, title, category_id, currency_code, country_code, city_id,
     status, moderation)
  values
    ('aaaaaaaa-0000-0000-0000-0000000000ff',
     '11111111-1111-1111-1111-111111111111',
     'منتج بيحاول ينشر نفسه', 'mobiles', 'EGP', 'EG', 'cairo',
     'available', 'approved');

  select * into it from public.items
   where id = 'aaaaaaaa-0000-0000-0000-0000000000ff';

  perform public.assert_eq(it.moderation::text, 'pending',
    'المنتج الجديد بيبدأ في انتظار الفحص مهما اتبعت');
  perform public.assert_eq(it.status::text, 'pending',
    'ومابيبدأش متاح');
end $$;

reset role;
reset request.jwt.claim.sub;

-- ---------------------------------------------------------------------------
-- والخادم لسه بيقدر يعتمد — الحارس بيفرّق بين الاتنين
-- ---------------------------------------------------------------------------
do $$
declare
  it public.items;
begin
  perform public.apply_moderation('aaaaaaaa-0000-0000-0000-0000000000ff',
                                  'approved');

  select * into it from public.items
   where id = 'aaaaaaaa-0000-0000-0000-0000000000ff';

  perform public.assert_eq(it.status::text, 'available',
    'الخادم لسه بيقدر ينشر');
  perform public.assert_true(it.published_at is not null,
    'وتاريخ النشر اتسجّل');
end $$;


-- =============================================================================
do $$ begin raise notice E'\n▶ 18. كود الإتمام — لازم تشوف شاشة التاني'; end $$;
-- =============================================================================

-- منتجات وغرفة نضيفة للاختبار ده
insert into public.items
  (id, owner_id, title, category_id, condition, status, moderation,
   value_min, value_max, currency_code, country_code, city_id, published_at)
values
  ('bbbbbbbb-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111',
   'لابتوب ديل للمقايضة', 'computers', 'good', 'available', 'approved',
   9000, 11000, 'EGP', 'EG', 'cairo', now()),
  ('bbbbbbbb-0000-0000-0000-000000000002',
   '22222222-2222-2222-2222-222222222222',
   'كاميرا كانون للمقايضة', 'cameras', 'good', 'available', 'approved',
   9500, 11500, 'EGP', 'EG', 'giza', now()),
  ('bbbbbbbb-0000-0000-0000-000000000003',
   '33333333-3333-3333-3333-333333333333',
   'دراجة هوائية للمقايضة', 'sports', 'good', 'available', 'approved',
   4000, 6000, 'EGP', 'EG', 'cairo', now());

do $$
declare
  v_match uuid;
begin
  insert into public.matches (id, user_a, user_b, item_a, item_b, stage)
  values (gen_random_uuid(),
          '11111111-1111-1111-1111-111111111111',
          '22222222-2222-2222-2222-222222222222',
          'bbbbbbbb-0000-0000-0000-000000000001',
          'bbbbbbbb-0000-0000-0000-000000000002',
          'negotiating')
  returning id into v_match;

  create temp table t_match as select v_match as id;
end $$;

do $$
declare
  v_match uuid := (select id from t_match);
  code_a  text;
  code_b  text;
  again   text;
begin
  -- كل طرف بيصدر كوده
  perform set_config('request.jwt.claim.sub',
                     '11111111-1111-1111-1111-111111111111', true);
  code_a := public.issue_trade_code(v_match);

  perform set_config('request.jwt.claim.sub',
                     '22222222-2222-2222-2222-222222222222', true);
  code_b := public.issue_trade_code(v_match);

  perform public.assert_eq(length(code_a), 8, 'الكود 8 خانات');
  perform public.assert_true(code_a <> code_b, 'كل طرف له كود مختلف');

  -- الكود مش مشتق من رقم الغرفة — ده كان جوهر المشكلة القديمة
  perform public.assert_true(
    code_a <> upper(substring(replace(v_match::text, '-', ''), 1, 8)),
    'الكود مش مشتق من رقم الغرفة');

  -- الأبجدية من غير الحروف اللي بتتلخبط
  perform public.assert_true(code_a !~ '[01OIL]',
    'مفيش حروف بتتلخبط في القراءة');

  -- الإصدار ثابت: نفس الكود لو اتنادى تاني
  perform set_config('request.jwt.claim.sub',
                     '11111111-1111-1111-1111-111111111111', true);
  again := public.issue_trade_code(v_match);
  perform public.assert_eq(again, code_a, 'الكود مابيتغيرش لو الشاشة اتفتحت تاني');
end $$;

do $$
declare
  v_match uuid := (select id from t_match);
  code_a  text;
  code_b  text;
  res     jsonb;
  n       int;
begin
  select code into code_a from public.trade_confirmations
   where match_id = v_match and user_id = '11111111-1111-1111-1111-111111111111';
  select code into code_b from public.trade_confirmations
   where match_id = v_match and user_id = '22222222-2222-2222-2222-222222222222';

  -- ---------------------------------------------------------------------------
  -- المحاولة اللي كانت شغالة قبل كده: أكّد نفسك بكودك
  -- ---------------------------------------------------------------------------
  perform set_config('request.jwt.claim.sub',
                     '11111111-1111-1111-1111-111111111111', true);

  res := public.confirm_trade(v_match, code_a);
  perform public.assert_eq(res->>'error', 'invalid_code',
    'مسح كودي أنا مابيأكدش حاجة');

  -- كود مخترع
  res := public.confirm_trade(v_match, 'ZZZZZZZZ');
  perform public.assert_eq(res->>'error', 'invalid_code',
    'الكود المخترع مابيعديش');

  -- ---------------------------------------------------------------------------
  -- المسار الصح: وسام بيمسح كود أحمد → صف وسام هو اللي بيتأكد
  -- ---------------------------------------------------------------------------
  res := public.confirm_trade(v_match, code_b);
  perform public.assert_true((res->>'ok')::boolean, 'مسح كود التاني نجح');
  perform public.assert_eq((res->>'completed')::boolean, false,
    'طرف واحد مايكملش الصفقة');

  select count(*)::int into n from public.trade_confirmations
   where match_id = v_match
     and user_id = '11111111-1111-1111-1111-111111111111'
     and confirmed_at is not null;
  perform public.assert_eq(n, 1, 'اللي اتأكد هو صف وسام مش صف أحمد');

  -- والغرفة لسه مش مكتملة
  select count(*)::int into n from public.matches
   where id = v_match and stage = 'completed';
  perform public.assert_eq(n, 0, 'الصفقة لسه مقفلتش بطرف واحد');

  -- ---------------------------------------------------------------------------
  -- أحمد بيمسح كود وسام → الصفقة بتكتمل
  -- ---------------------------------------------------------------------------
  perform set_config('request.jwt.claim.sub',
                     '22222222-2222-2222-2222-222222222222', true);

  res := public.confirm_trade(v_match, code_a);
  perform public.assert_true((res->>'completed')::boolean,
    'الطرفين أكدوا → الصفقة اكتملت');

  select count(*)::int into n from public.matches
   where id = v_match and stage = 'completed' and closed_at is not null;
  perform public.assert_eq(n, 1, 'الغرفة اتقفلت مكتملة');

  select count(*)::int into n from public.items
   where id in ('bbbbbbbb-0000-0000-0000-000000000001',
                'bbbbbbbb-0000-0000-0000-000000000002')
     and status = 'traded';
  perform public.assert_eq(n, 2, 'المنتجين اتسجلوا متقايضين');
end $$;

-- -----------------------------------------------------------------------------
-- سقف المحاولات
-- -----------------------------------------------------------------------------
do $$
declare
  v_match uuid;
  res     jsonb;
  i       int;
begin
  insert into public.matches (id, user_a, user_b, item_a, item_b, stage)
  values (gen_random_uuid(),
          '11111111-1111-1111-1111-111111111111',
          '33333333-3333-3333-3333-333333333333',
          'bbbbbbbb-0000-0000-0000-000000000001',
          'bbbbbbbb-0000-0000-0000-000000000003',
          'negotiating')
  returning id into v_match;

  perform set_config('request.jwt.claim.sub',
                     '11111111-1111-1111-1111-111111111111', true);
  perform public.issue_trade_code(v_match);

  for i in 1..5 loop
    res := public.confirm_trade(v_match, 'AAAAAAAA');
  end loop;

  res := public.confirm_trade(v_match, 'AAAAAAAA');
  perform public.assert_eq(res->>'error', 'too_many_attempts',
    'سقف المحاولات بيتفرض بعد 5');
end $$;

-- -----------------------------------------------------------------------------
-- والعميل مابيقدرش يكتب على الجدول مباشرةً — ده الباب الحقيقي
-- -----------------------------------------------------------------------------
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

do $$
declare
  blocked boolean := false;
begin
  begin
    insert into public.trade_confirmations
      (match_id, user_id, code, confirmed_at)
    values ((select id from t_match),
            '11111111-1111-1111-1111-111111111111', 'HACKED11', now());
  exception when insufficient_privilege then
    blocked := true;
  end;

  perform public.assert_true(blocked,
    'العميل مايقدرش يكتب تأكيد بنفسه');
end $$;

do $$
declare
  n int;
begin
  -- وكمان مايشوفش كود التاني
  select count(*)::int into n from public.trade_confirmations
   where user_id <> '11111111-1111-1111-1111-111111111111';
  perform public.assert_eq(n, 0, 'كود الطرف التاني مخفي عني');
end $$;

reset role;
reset request.jwt.claim.sub;


-- =============================================================================
do $$ begin raise notice E'\n▶ 19. لوحة المراجعة البشرية'; end $$;
-- =============================================================================

-- منى مراجعة
insert into public.staff (user_id, role) values
  ('33333333-3333-3333-3333-333333333333', 'moderator');

-- منتجات معلّمة: واحد محتوى مشكوك فيه، واتنين عطل نظام
insert into public.items
  (id, owner_id, title, category_id, condition, status, moderation,
   moderation_note, currency_code, country_code, city_id)
values
  ('cccccccc-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111',
   'منتج فيه شك', 'mobiles', 'good', 'pending', 'flagged',
   'صور مش واضحة', 'EGP', 'EG', 'cairo'),
  ('cccccccc-0000-0000-0000-000000000002',
   '22222222-2222-2222-2222-222222222222',
   'منتج النظام تعثّر فيه', 'cameras', 'good', 'pending', 'flagged',
   'moderation_unavailable', 'EGP', 'EG', 'giza'),
  ('cccccccc-0000-0000-0000-000000000003',
   '22222222-2222-2222-2222-222222222222',
   'منتج السقف اتعدى عليه', 'books', 'good', 'pending', 'flagged',
   'awaiting_review', 'EGP', 'EG', 'cairo'),
  -- ودي بتاعة منى نفسها — تعارض مصالح
  ('cccccccc-0000-0000-0000-000000000004',
   '33333333-3333-3333-3333-333333333333',
   'منتج المراجعة نفسها', 'sports', 'good', 'pending', 'flagged',
   'محتوى مشكوك فيه', 'EGP', 'EG', 'cairo');

do $$
begin
  perform public.assert_true(
    public.is_staff('33333333-3333-3333-3333-333333333333'),
    'منى مراجعة');
  perform public.assert_true(
    not public.is_staff('11111111-1111-1111-1111-111111111111'),
    'وسام مش مراجع');

  -- تصنيف سبب التعليم
  perform public.assert_eq(public.flag_kind('moderation_unavailable'), 'system',
    'تعثّر النظام مش حكم على المحتوى');
  perform public.assert_eq(public.flag_kind('awaiting_review'), 'system',
    'تعدّي السقف كمان تعثّر نظام');
  perform public.assert_eq(public.flag_kind('صور مش واضحة'), 'content',
    'ملاحظة الموديل = محتاج حكم بشري');
end $$;

-- -----------------------------------------------------------------------------
-- المستخدم العادي: مايشوفش الطابور ولا يقرر
-- -----------------------------------------------------------------------------
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

do $$
declare
  blocked boolean := false;
  res     jsonb;
  n       int;
begin
  begin
    perform * from public.moderation_queue_page('content', 10);
  exception when insufficient_privilege then
    blocked := true;
  end;
  perform public.assert_true(blocked, 'المستخدم العادي مايشوفش الطابور');

  res := public.moderate_decide('cccccccc-0000-0000-0000-000000000001',
                                'approved');
  perform public.assert_eq(res->>'error', 'not_authorized',
    'المستخدم العادي مايقررش');

  -- وحتى منتجه هو مايقدرش يعتمده (الحارس من ملف 19 لسه شغال)
  update public.items set moderation = 'approved', status = 'available'
   where id = 'cccccccc-0000-0000-0000-000000000001';

  select count(*)::int into n from public.items
   where id = 'cccccccc-0000-0000-0000-000000000001' and moderation = 'flagged';
  perform public.assert_eq(n, 1, 'صاحب المنتج المعلّم مايعتمدش نفسه');

  -- ومايشوفش سجل القرارات
  select count(*)::int into n from public.moderation_decisions;
  perform public.assert_eq(n, 0, 'سجل القرارات مخفي عن غير الطاقم');

  -- ولا يعرف مين المراجعين
  select count(*)::int into n from public.staff;
  perform public.assert_eq(n, 0, 'قائمة الطاقم مخفية عن المستخدم');
end $$;

reset role;
reset request.jwt.claim.sub;

-- -----------------------------------------------------------------------------
-- المراجعة
-- -----------------------------------------------------------------------------
set role authenticated;
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';

do $$
declare
  res   jsonb;
  n     int;
  stats jsonb;
begin
  -- الطابور بيتقسم صح
  select count(*)::int into n
    from public.moderation_queue_page('content', 50);
  perform public.assert_eq(n, 2,
    'طابور المحتوى فيه اللي محتاج حكم بس');

  select count(*)::int into n
    from public.moderation_queue_page('system', 50);
  perform public.assert_eq(n, 2,
    'وطابور أعطال النظام منفصل');

  -- تعارض المصالح
  res := public.moderate_decide('cccccccc-0000-0000-0000-000000000004',
                                'approved');
  perform public.assert_eq(res->>'error', 'own_item',
    'المراجعة ماتراجعش منتجها');

  -- الرفض من غير سبب
  res := public.moderate_decide('cccccccc-0000-0000-0000-000000000001',
                                'rejected');
  perform public.assert_eq(res->>'error', 'reason_required',
    'الرفض لازم معاه سبب');

  -- قرار سليم
  res := public.moderate_decide('cccccccc-0000-0000-0000-000000000001',
                                'rejected', 'الصور مش للمنتج المعروض');
  perform public.assert_true((res->>'ok')::boolean, 'القرار اتنفّذ');

  -- واتسجّل باسمها
  select count(*)::int into n from public.moderation_decisions
   where item_id = 'cccccccc-0000-0000-0000-000000000001'
     and moderator_id = '33333333-3333-3333-3333-333333333333'
     and decision = 'rejected';
  perform public.assert_eq(n, 1, 'القرار اتسجّل باسم المراجعة');

  -- القرار التاني على نفس المنتج مابيتسجلش
  res := public.moderate_decide('cccccccc-0000-0000-0000-000000000001',
                                'approved');
  perform public.assert_true((res->>'already')::boolean,
    'المنتج اللي اتحكم عليه مابيتحكمش تاني');

  select count(*)::int into n from public.moderation_decisions
   where item_id = 'cccccccc-0000-0000-0000-000000000001';
  perform public.assert_eq(n, 1, 'ومفيش قرار مكرر في السجل');

  -- إعادة محاولة أعطال النظام — دفعة واحدة
  select public.moderate_requeue_system_flags(50) into n;
  perform public.assert_eq(n, 2, 'أعطال النظام رجعت للطابور الآلي');

  -- المؤشرات
  stats := public.moderation_stats();
  perform public.assert_true((stats->>'ok')::boolean, 'المؤشرات متاحة للمراجعة');
  perform public.assert_eq((stats->>'pending_system')::int, 0,
    'مفيش أعطال نظام مستنية');
  perform public.assert_eq((stats->>'decided_today')::int, 1,
    'قرار واحد النهاردة');
end $$;

-- -----------------------------------------------------------------------------
-- الأثر الفعلي — بنتحقق منه بره الدور
--
-- RLS بيخفي المنتج المرفوض عن المراجعة نفسها (مش صاحبته ومش معتمد).
-- وده سلوك صح: اللوحة بتقرا من دالة security definer، مش من الجدول.
-- -----------------------------------------------------------------------------
reset role;
reset request.jwt.claim.sub;

do $$
declare
  n int;
begin
  select count(*)::int into n from public.items
   where id = 'cccccccc-0000-0000-0000-000000000001'
     and moderation = 'rejected' and status = 'rejected';
  perform public.assert_eq(n, 1, 'المنتج اترفض فعلاً');

  perform public.assert_true(
    exists (select 1 from public.notifications
             where user_id = '11111111-1111-1111-1111-111111111111'
               and title_ar like '%الصور مش للمنتج%'),
    'صاحب المنتج اتبلّغ بالسبب');

  select count(*)::int into n from public.items
   where id in ('cccccccc-0000-0000-0000-000000000002',
                'cccccccc-0000-0000-0000-000000000003')
     and moderation = 'pending' and moderation_note is null;
  perform public.assert_eq(n, 2, 'أعطال النظام مابقتش معلّمة');
end $$;

set role authenticated;
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';

-- -----------------------------------------------------------------------------
-- السجل مُلحَق فقط — حتى للمراجعة
-- -----------------------------------------------------------------------------
do $$
declare
  blocked boolean := false;
  n int;
begin
  begin
    update public.moderation_decisions set decision = 'approved';
  exception when insufficient_privilege then
    blocked := true;
  end;
  perform public.assert_true(blocked, 'المراجعة ماتقدرش تعدّل سجل قراراتها');

  blocked := false;
  begin
    delete from public.moderation_decisions;
  exception when insufficient_privilege then
    blocked := true;
  end;
  perform public.assert_true(blocked, 'ولا تمسحه');

  -- ولا ترقّي نفسها لأدمن
  blocked := false;
  begin
    update public.staff set role = 'admin';
  exception when insufficient_privilege then
    blocked := true;
  end;
  perform public.assert_true(blocked, 'ولا ترقّي نفسها');

  select count(*)::int into n from public.moderation_decisions;
  perform public.assert_eq(n, 1, 'السجل زي ما هو');
end $$;

-- -----------------------------------------------------------------------------
-- وحتى المراجعة ماتقدرش تعتمد منتج من غير الدالة
-- -----------------------------------------------------------------------------
do $$
declare
  n int;
begin
  update public.items
     set moderation = 'approved', status = 'available'
   where id = 'cccccccc-0000-0000-0000-000000000004';   -- منتجها هي

  -- منتجها هي، فبتشوفه بـ items_read_own
  select count(*)::int into n from public.items
   where id = 'cccccccc-0000-0000-0000-000000000004' and moderation = 'flagged';
  perform public.assert_eq(n, 1,
    'الكتابة المباشرة ممنوعة حتى على المراجعة — عشان مايتخطاش السجل');
end $$;

reset role;
reset request.jwt.claim.sub;


-- =============================================================================
do $$ begin raise notice E'\n▶ 20. الإشعارات الفورية'; end $$;
-- =============================================================================
do $$
declare
  n int;
begin
  -- ---------------------------------------------------------------------------
  -- مش كل إشعار يستاهل رنة
  -- ---------------------------------------------------------------------------
  perform public.assert_true(public.push_worthy('match'),
    'المطابقة تستاهل رنة — دي اللحظة كلها');
  perform public.assert_true(public.push_worthy('message'),
    'والرسالة — الطرف التاني مستني رد');
  perform public.assert_true(public.push_worthy('offer'),
    'والعرض — وله مهلة');
  perform public.assert_true(public.push_worthy('meeting'),
    'واللقاء');

  perform public.assert_true(not public.push_worthy('wishlist'),
    'تنبيه قائمة الرغبات مفيد بس مش عاجل — يستنى في التطبيق');
  perform public.assert_true(not public.push_worthy('system'),
    'ورفض المنتج ماينفعش يوصل كرنة مفاجئة');
  perform public.assert_true(not public.push_worthy('review'),
    'والتقييم مش عاجل');

  -- ---------------------------------------------------------------------------
  -- من غير جهاز مسجّل مفيش صف في الصندوق
  -- ---------------------------------------------------------------------------
  perform public.notify_user(
    '11111111-1111-1111-1111-111111111111', 'match',
    'مطابقة جديدة', 'New match', '{}'::jsonb);

  select count(*)::int into n from public.push_outbox;
  perform public.assert_eq(n, 0, 'مفيش صندوق صادر من غير أجهزة مسجّلة');
end $$;

-- الأجهزة
insert into public.push_tokens (user_id, token, platform) values
  ('11111111-1111-1111-1111-111111111111', 'tok-wessam-1', 'android'),
  ('11111111-1111-1111-1111-111111111111', 'tok-wessam-2', 'ios'),
  ('22222222-2222-2222-2222-222222222222', 'tok-ahmed-1',  'android');

do $$
declare
  n int;
  j record;
begin
  perform public.notify_user(
    '11111111-1111-1111-1111-111111111111', 'match',
    'مطابقة جديدة مع أحمد', 'New match with Ahmed',
    jsonb_build_object('match_id', '00000000-0000-0000-0000-0000000000aa'));

  select count(*)::int into n from public.push_outbox where status = 'queued';
  perform public.assert_eq(n, 1, 'المطابقة دخلت الصندوق');

  -- تنبيه قائمة الرغبات مابيدخلش
  perform public.notify_user(
    '11111111-1111-1111-1111-111111111111', 'wishlist',
    'منتج من قائمتك', 'From your wishlist', '{}'::jsonb);

  select count(*)::int into n from public.push_outbox;
  perform public.assert_eq(n, 1, 'وتنبيه الرغبات مادخلش');

  -- ---------------------------------------------------------------------------
  -- الدمج: 20 رسالة في غرفة = رنة واحدة
  -- ---------------------------------------------------------------------------
  for n in 1..20 loop
    perform public.notify_user(
      '11111111-1111-1111-1111-111111111111', 'message',
      'رسالة رقم ' || n, 'Message ' || n,
      jsonb_build_object('match_id', '00000000-0000-0000-0000-0000000000bb'));
  end loop;

  select count(*)::int into n from public.push_outbox
   where kind = 'message' and status = 'queued';
  perform public.assert_eq(n, 1, '20 رسالة في غرفة واحدة = رنة واحدة');

  -- وبتحمل آخر رسالة مش أولها
  select * into j from public.push_outbox where kind = 'message';
  perform public.assert_eq(j.title_ar, 'رسالة رقم 20',
    'والرنة بتحمل آخر رسالة');

  -- غرفة تانية = رنة منفصلة
  perform public.notify_user(
    '11111111-1111-1111-1111-111111111111', 'message',
    'رسالة في غرفة تانية', 'Other room',
    jsonb_build_object('match_id', '00000000-0000-0000-0000-0000000000cc'));

  select count(*)::int into n from public.push_outbox where kind = 'message';
  perform public.assert_eq(n, 2, 'والغرفة التانية رنة لوحدها');
end $$;

-- -----------------------------------------------------------------------------
-- ساعات الهدوء
-- -----------------------------------------------------------------------------
do $$
declare
  due     timestamptz;
  local_h int;
begin
  due := public.push_not_before('11111111-1111-1111-1111-111111111111');

  -- مصر UTC+2. بنحسب الساعة المحلية دلوقتي عشان نعرف نتوقع إيه.
  local_h := extract(hour from now() + interval '2 hours')::int;

  if local_h >= 8 and local_h < 23 then
    perform public.assert_true(due <= now() + interval '1 second',
      'في ساعات النهار الرنة بتتبعت فوراً');
  else
    perform public.assert_true(due > now(),
      'وفي ساعات الهدوء بتتأجّل');

    -- بتتأجّل لـ 8 الصبح المحلي
    perform public.assert_eq(
      extract(hour from due + interval '2 hours')::int, 8,
      'التأجيل لـ 8 الصبح بالتوقيت المحلي');
  end if;

  -- ومهما كان الوقت، مابنلغيش الرنة
  perform public.assert_true(due < now() + interval '24 hours',
    'والتأجيل مابيزيدش عن يوم — مابنلغيش الإشعار');
end $$;

-- -----------------------------------------------------------------------------
-- الإزاحات الزمنية للأسواق
-- -----------------------------------------------------------------------------
do $$
begin
  perform public.assert_eq(public.country_utc_offset('EG'), 2, 'مصر UTC+2');
  perform public.assert_eq(public.country_utc_offset('SA'), 3, 'السعودية UTC+3');
  perform public.assert_eq(public.country_utc_offset('AE'), 4, 'الإمارات UTC+4');
  perform public.assert_eq(public.country_utc_offset('OM'), 4, 'عُمان UTC+4');
end $$;

-- -----------------------------------------------------------------------------
-- سحب الدفعة
-- -----------------------------------------------------------------------------
do $$
declare
  n     int;
  batch record;
begin
  -- بنخلي كل الصفوف مستحقة عشان الاختبار مايعتمدش على ساعة التشغيل
  update public.push_outbox set not_before = now() - interval '1 minute';

  select count(*)::int into n from public.push_claim_batch(50);
  perform public.assert_true(n >= 3, 'الدفعة اترجعت (' || n || ')');

  -- الرموز بتيجي مع الصف — عشان العامل مايعملش نداء زيادة لكل صف
  select * into batch from public.push_claim_batch(1);
  select count(*)::int into n from public.push_outbox
   where attempts > 0;
  perform public.assert_true(n > 0, 'المحاولات بتتعدّ عند السحب');

  -- والسحب بيوقف عند 3 محاولات
  update public.push_outbox set attempts = 3;
  select count(*)::int into n from public.push_claim_batch(50);
  perform public.assert_eq(n, 0, 'اللي فشل 3 مرات مابيتسحبش تاني');

  update public.push_outbox set attempts = 0;
end $$;

-- -----------------------------------------------------------------------------
-- الرموز الميتة
-- -----------------------------------------------------------------------------
do $$
declare
  n int;
begin
  perform public.push_drop_token('tok-wessam-2');

  select count(*)::int into n from public.push_tokens
   where token = 'tok-wessam-2';
  perform public.assert_eq(n, 0, 'الرمز الميت اتمسح');

  select count(*)::int into n from public.push_tokens
   where user_id = '11111111-1111-1111-1111-111111111111';
  perform public.assert_eq(n, 1, 'وباقي أجهزة المستخدم زي ما هي');
end $$;

-- -----------------------------------------------------------------------------
-- تسجيل الجهاز — والرمز بينتقل لصاحبه الجديد
-- -----------------------------------------------------------------------------
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';

do $$
declare
  n int;
begin
  -- أحمد سجّل دخول على جهاز وسام
  perform public.register_push_token('tok-wessam-1', 'android');

  select count(*)::int into n from public.push_tokens
   where token = 'tok-wessam-1'
     and user_id = '22222222-2222-2222-2222-222222222222';
  perform public.assert_eq(n, 1, 'الرمز انتقل لصاحب الجهاز الجديد');

  select count(*)::int into n from public.push_tokens
   where token = 'tok-wessam-1'
     and user_id = '11111111-1111-1111-1111-111111111111';
  perform public.assert_eq(n, 0,
    'ومابقاش مربوط بالأول — وإلا إشعاراته كانت هتوصل للتاني');

end $$;

do $$
declare
  blocked boolean := false;
begin
  -- الصندوق شغل خادم بحت: مفيش صلاحية أصلاً، مش مجرد سياسة صفوف
  begin
    perform count(*) from public.push_outbox;
  exception when insufficient_privilege then
    blocked := true;
  end;
  perform public.assert_true(blocked, 'صندوق الصادر مقفول على العميل');

  blocked := false;
  begin
    perform * from public.push_claim_batch(10);
  exception when insufficient_privilege then
    blocked := true;
  end;
  perform public.assert_true(blocked, 'والعميل مايسحبش الدفعة');

  blocked := false;
  begin
    perform public.push_drop_token('tok-ahmed-1');
  exception when insufficient_privilege then
    blocked := true;
  end;
  perform public.assert_true(blocked, 'ولا يمسح رموز غيره');
end $$;

reset role;
reset request.jwt.claim.sub;

-- -----------------------------------------------------------------------------
-- التنظيف
-- -----------------------------------------------------------------------------
do $$
declare
  n int;
begin
  update public.push_outbox
     set status = 'sent', created_at = now() - interval '10 days';

  select public.purge_push_outbox() into n;
  perform public.assert_true(n > 0, 'الصفوف القديمة اتنضفت (' || n || ')');

  select count(*)::int into n from public.push_outbox;
  perform public.assert_eq(n, 0, 'والصندوق فضي');
end $$;


-- =============================================================================
do $$ begin raise notice E'\n▶ 21. التفاصيل المكمّلة'; end $$;
-- =============================================================================

-- صور لمنتج معلّم
insert into public.items
  (id, owner_id, title, category_id, condition, status, moderation,
   moderation_note, currency_code, country_code, city_id)
values
  ('dddddddd-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111',
   'منتج بصور محتاج مراجعة', 'mobiles', 'good', 'pending', 'flagged',
   'الصور مش واضحة', 'EGP', 'EG', 'cairo');

insert into public.item_photos (item_id, storage_path, position) values
  ('dddddddd-0000-0000-0000-000000000001', 'u1/a.jpg', 0),
  ('dddddddd-0000-0000-0000-000000000001', 'u1/b.jpg', 1),
  ('dddddddd-0000-0000-0000-000000000001', 'u1/c.jpg', 2);

set role authenticated;
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';

do $$
declare
  row_ record;
begin
  select * into row_ from public.moderation_queue_page('content', 50)
   where item_id = 'dddddddd-0000-0000-0000-000000000001';

  -- المراجع كان بيشوف «3 صور» بس. يعني بنطلب منه يحكم على محتوى
  -- بصري من غير ما يشوفه.
  perform public.assert_eq(jsonb_array_length(row_.photos), 3,
    'الصور بترجع مع الحالة');
  perform public.assert_eq(row_.photos->>0, 'u1/a.jpg',
    'وبالترتيب الصح');
end $$;

reset role;
reset request.jwt.claim.sub;

-- -----------------------------------------------------------------------------
-- لغة الإشعار — خاصية الجهاز مش المستخدم
-- -----------------------------------------------------------------------------
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

do $$
begin
  perform public.register_push_token('tok-ar', 'android', 'ar');
  perform public.register_push_token('tok-en', 'ios', 'en-US');
  -- لغة مش مدعومة بترجع للعربي
  perform public.register_push_token('tok-fr', 'android', 'fr-FR');
end $$;

reset role;
reset request.jwt.claim.sub;

do $$
declare
  n int;
begin
  select count(*)::int into n from public.push_tokens
   where token = 'tok-en' and lang = 'en';
  perform public.assert_eq(n, 1, 'الجهاز الإنجليزي اتسجّل بالإنجليزي');

  select count(*)::int into n from public.push_tokens
   where token = 'tok-ar' and lang = 'ar';
  perform public.assert_eq(n, 1, 'والعربي بالعربي');

  select count(*)::int into n from public.push_tokens
   where token = 'tok-fr' and lang = 'ar';
  perform public.assert_eq(n, 1, 'واللغة غير المدعومة بترجع للعربي');
end $$;

-- واللغة بتوصل للعامل مع كل جهاز
do $$
declare
  b       record;
  langs   text[];
begin
  perform public.notify_user(
    '11111111-1111-1111-1111-111111111111', 'match',
    'مطابقة', 'A match',
    jsonb_build_object('match_id', '00000000-0000-0000-0000-0000000000dd'));

  update public.push_outbox set not_before = now() - interval '1 minute';

  select * into b from public.push_claim_batch(10)
   where user_id = '11111111-1111-1111-1111-111111111111' limit 1;

  select array_agg(distinct t->>'lang')
    into langs
    from jsonb_array_elements(b.tokens) t;

  perform public.assert_true('en' = any(langs),
    'العامل بيوصله جهاز إنجليزي');
  perform public.assert_true('ar' = any(langs),
    'وجهاز عربي — والنص بيتاخد لكل واحد على حدة');
end $$;

-- -----------------------------------------------------------------------------
-- تنبيه تأخّر الطابور
-- -----------------------------------------------------------------------------
do $$
declare
  n int;
begin
  -- الطابور لسه جديد → مفيش تنبيه
  select public.moderation_sla_check(24) into n;
  perform public.assert_eq(n, 0, 'الطابور الجديد مالوش تنبيه');

  -- نخلي الحالة قديمة. بنعدّل عمود الطابور مباشرةً — العمود ده
  -- مابيتغيرش إلا عند الدخول للطابور، عشان كده هو الصح للحساب.
  update public.items
     set moderation_queued_at = now() - interval '30 hours'
   where id = 'dddddddd-0000-0000-0000-000000000001';

  select public.moderation_sla_check(24) into n;
  perform public.assert_true(n > 0,
    'التأخّر بيتبلّغ للطاقم (' || n || ')');

  perform public.assert_true(
    exists (select 1 from public.notifications
             where payload->>'alert' = 'moderation_sla'
               and user_id = '33333333-3333-3333-3333-333333333333'),
    'ومنى المراجعة اتبلّغت');

  -- ---------------------------------------------------------------------------
  -- ومابيتكررش
  --
  -- من غير الشرط ده، التنبيه بيرن كل ساعة على نفس الحالة — والمراجع
  -- بيتعلّم يتجاهله، وساعتها بيبقى أسوأ من مفيش تنبيه.
  -- ---------------------------------------------------------------------------
  select public.moderation_sla_check(24) into n;
  perform public.assert_eq(n, 0, 'والتنبيه مابيتكررش خلال 6 ساعات');
end $$;

-- -----------------------------------------------------------------------------
-- تعديل صاحب المنتج مايرجّعوش لآخر الطابور
--
-- ده كان عطل حقيقي: الطابور كان بيحسب الانتظار من updated_at، والمحفّز
-- items_touch بيحدّثه مع أي تعديل. يعني صاحب المنتج المعلّم يعدّل سعره
-- فيبان كأنه لسه داخل الطابور — وتنبيه التأخّر مايرنّش عليه أبداً.
--
-- والنتيجة إن أقدم الحالات هي اللي بتضيع، وهي بالظبط اللي محتاجة
-- الاهتمام.
-- -----------------------------------------------------------------------------
do $$
declare
  before_min int;
  after_min  int;
begin
  select waiting_minutes::int into before_min
    from public.moderation_queue
   where item_id = 'dddddddd-0000-0000-0000-000000000001';

  perform public.assert_true(before_min >= 60 * 29,
    'الحالة مستنية من 30 ساعة (' || before_min || ' دقيقة)');

  -- صاحب المنتج بيعدّل حاجة غير جوهرية
  update public.items set will_pay_up_to = 250
   where id = 'dddddddd-0000-0000-0000-000000000001';

  select waiting_minutes::int into after_min
    from public.moderation_queue
   where item_id = 'dddddddd-0000-0000-0000-000000000001';

  perform public.assert_true(after_min >= 60 * 29,
    'والتعديل مارجّعهاش لآخر الطابور (' || after_min || ' دقيقة)');

  -- وupdated_at اتحدّث فعلاً — يعني الاختبار بيقيس الحاجة الصح
  perform public.assert_true(
    (select updated_at from public.items
      where id = 'dddddddd-0000-0000-0000-000000000001') > now() - interval '1 minute',
    'مع إن updated_at اتحدّث بالفعل');
end $$;

-- والتنبيه ده شغل خادم — مش للعميل
set role authenticated;
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';

do $$
declare
  blocked boolean := false;
begin
  begin
    perform public.moderation_sla_check(24);
  exception when insufficient_privilege then
    blocked := true;
  end;
  perform public.assert_true(blocked, 'حتى المراجع مايناديش فحص التأخّر');
end $$;

reset role;
reset request.jwt.claim.sub;


-- =============================================================================
do $$ begin raise notice E'\n▶ 22. طابور البلاغات وتقرير الدقة'; end $$;
-- =============================================================================

-- بلاغ على مستخدم من اتنين مختلفين، وبلاغ على رسالة
do $$
declare
  v_match uuid;
  v_msg   uuid;
begin
  select id into v_match from public.matches
   where stage = 'completed' limit 1;

  insert into public.messages (id, match_id, sender_id, kind, body)
  values (gen_random_uuid(), v_match,
          '22222222-2222-2222-2222-222222222222', 'text',
          'كلّمني على الرقم ده بره التطبيق')
  returning id into v_msg;

  create temp table t_msg as select v_msg as id;

  insert into public.reports (reporter_id, target_type, target_id, reason, details)
  values
    ('11111111-1111-1111-1111-111111111111', 'user',
     '22222222-2222-2222-2222-222222222222', 'scam', 'طلب مني تحويل قبل اللقاء'),
    ('33333333-3333-3333-3333-333333333333', 'user',
     '22222222-2222-2222-2222-222222222222', 'scam', 'نفس الأسلوب معايا'),
    ('11111111-1111-1111-1111-111111111111', 'message',
     v_msg, 'inappropriate', 'بيحاول ياخد المعاملة بره التطبيق');
end $$;

-- -----------------------------------------------------------------------------
-- المستخدم العادي مايشوفش الطابور
-- -----------------------------------------------------------------------------
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

do $$
declare
  blocked boolean := false;
  res jsonb;
begin
  begin
    perform * from public.report_queue_page(10);
  exception when insufficient_privilege then
    blocked := true;
  end;
  perform public.assert_true(blocked, 'طابور البلاغات للطاقم بس');

  res := public.moderation_report(30);
  perform public.assert_eq(res->>'error', 'not_authorized',
    'وتقرير الدقة كمان');
end $$;

reset role;
reset request.jwt.claim.sub;

-- -----------------------------------------------------------------------------
-- المراجعة
-- -----------------------------------------------------------------------------
set role authenticated;
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';

do $$
declare
  n     int;
  row_  record;
  res   jsonb;
begin
  select count(*)::int into n from public.report_queue_page(50);
  -- بلاغين على أحمد + بلاغ على الرسالة = 3 صفوف
  perform public.assert_eq(n, 3, 'البلاغات ظهرت في الطابور');

  -- بلاغات المنتجات مش هنا — بتظهر مع المنتج نفسه
  select count(*)::int into n from public.report_queue_page(50)
   where target_type = 'item';
  perform public.assert_eq(n, 0,
    'بلاغات المنتجات مش مكررة هنا — بتتحسم مع المنتج');

  -- الأكتر بلاغات بيطلع الأول
  select * into row_ from public.report_queue_page(50) limit 1;
  perform public.assert_eq(row_.reports_on_target::int, 2,
    'الهدف اللي عليه بلاغين طلع الأول');

  -- وبيانات الهدف بتيجي معاه — المراجع مايقدرش يحكم من غيرها
  select * into row_ from public.report_queue_page(50)
   where target_type = 'message' limit 1;
  perform public.assert_eq(row_.target->>'body',
    'كلّمني على الرقم ده بره التطبيق',
    'نص الرسالة المبلَّغ عنها ظاهر للمراجع');

  -- ---------------------------------------------------------------------------
  -- تعارض المصالح
  -- ---------------------------------------------------------------------------
  insert into public.reports (reporter_id, target_type, target_id, reason)
  values ('33333333-3333-3333-3333-333333333333', 'user',
          '11111111-1111-1111-1111-111111111111', 'harassment');

  res := public.report_decide(
    (select id from public.reports
      where reporter_id = '33333333-3333-3333-3333-333333333333'
        and target_type = 'user'
        and target_id = '11111111-1111-1111-1111-111111111111'),
    'warned', 'اختبار');
  perform public.assert_eq(res->>'error', 'own_report',
    'المراجعة ماتحكمش على بلاغ هي قدّمته');

  -- الإجراء العقابي لازم معاه سبب
  res := public.report_decide(
    (select report_id from public.report_queue_page(50)
      where target_type = 'message' limit 1),
    'removed');
  perform public.assert_eq(res->>'error', 'reason_required',
    'الإخفاء لازم معاه سبب');

  -- ---------------------------------------------------------------------------
  -- إخفاء الرسالة — النص بيفضل للنزاعات
  -- ---------------------------------------------------------------------------
  res := public.report_decide(
    (select report_id from public.report_queue_page(50)
      where target_type = 'message' limit 1),
    'removed', 'محاولة أخذ المعاملة بره التطبيق');
  perform public.assert_true((res->>'ok')::boolean, 'الرسالة اتخفت');

  -- ---------------------------------------------------------------------------
  -- الإيقاف الدائم للأدمن بس
  -- ---------------------------------------------------------------------------
  res := public.report_decide(
    (select report_id from public.report_queue_page(50)
      where target_type = 'user' limit 1),
    'banned', 'نصب متكرر', null);
  perform public.assert_eq(res->>'error', 'admin_required',
    'الإيقاف الدائم مش للمراجع العادي');

  -- الإيقاف المؤقت مسموح
  res := public.report_decide(
    (select report_id from public.report_queue_page(50)
      where target_type = 'user' limit 1),
    'banned', 'نصب متكرر', 7);
  perform public.assert_true((res->>'ok')::boolean, 'والمؤقت مسموح');
end $$;

reset role;
reset request.jwt.claim.sub;

do $$
declare
  m public.messages;
  p public.profiles;
  n int;
begin
  select * into m from public.messages where id = (select id from t_msg);
  perform public.assert_true(m.removed_at is not null, 'الرسالة معلّمة كمخفية');
  perform public.assert_eq(m.body, 'كلّمني على الرقم ده بره التطبيق',
    'ونصها اتحفظ — السجل ده بيتستعمل في النزاعات');

  select * into p from public.profiles
   where id = '22222222-2222-2222-2222-222222222222';
  perform public.assert_true(p.is_banned, 'أحمد اتوقف');
  perform public.assert_true(p.banned_until > now(), 'ومؤقتاً مش دايم');

  -- كل البلاغات على نفس الهدف اتقفلت بقرار واحد
  select count(*)::int into n from public.reports
   where target_type = 'user'
     and target_id = '22222222-2222-2222-2222-222222222222'
     and status in ('open', 'reviewing');
  perform public.assert_eq(n, 0,
    'البلاغين على نفس الشخص اتقفلوا بقرار واحد');

  perform public.assert_true(
    exists (select 1 from public.notifications
             where user_id = '22222222-2222-2222-2222-222222222222'
               and title_ar like '%حسابك اتوقف%'),
    'وأحمد اتبلّغ بالسبب');
end $$;

-- -----------------------------------------------------------------------------
-- تقرير الدقة
-- -----------------------------------------------------------------------------
set role authenticated;
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';

do $$
declare
  rep jsonb;
begin
  rep := public.moderation_report(30);
  perform public.assert_true((rep->>'ok')::boolean, 'التقرير متاح للمراجعة');

  -- من القسم 19: قرار واحد على منتج، وكان رفض
  perform public.assert_eq((rep->>'decisions')::int, 1,
    'قرار واحد على منتج');
  perform public.assert_eq((rep->>'rejected')::int, 1, 'وكان رفض');

  -- معدل التعليم الخاطئ = المنتجات اللي الموديل علّمها والمراجع وافق
  -- عليها. صفر هنا لأن الوحيد اللي اتحكم عليه اترفض.
  perform public.assert_eq((rep->>'false_flag_rate')::numeric, 0::numeric,
    'معدل التعليم الخاطئ صفر — الموديل كان محق');

  perform public.assert_true(
    (rep->>'median_wait_minutes') is not null,
    'وزمن الرد الوسيط محسوب');

  perform public.assert_true(
    jsonb_array_length(rep->'by_moderator') >= 1,
    'والإنتاجية لكل مراجع');

  perform public.assert_eq((rep->>'reports_handled')::int, 2,
    'وقرارات البلاغات متعدّة لوحدها');
end $$;

reset role;
reset request.jwt.claim.sub;


do $$ begin raise notice E'\n✔ كل الاختبارات نجحت\n'; end $$;
