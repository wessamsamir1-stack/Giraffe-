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

do $$ begin raise notice E'\n✔ كل الاختبارات نجحت\n'; end $$;
