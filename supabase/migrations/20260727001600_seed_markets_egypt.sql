-- =============================================================================
-- Giraffe — بذور الأسواق: الدول والمدن والمناطق وأماكن اللقاء
--
-- قرار الإطلاق: **مصر — القاهرة الكبرى أولاً**.
--
-- باقي المدن والدول موجودة في البيانات لكن `is_active = false`.
-- المدينة مابتتفتحش إلا لما اللي قبلها توصل الكتلة الحرجة:
--   300 مستخدم نشط · 800 منتج متاح · نسبة ماتش 15٪
-- =============================================================================

-- -----------------------------------------------------------------------------
-- الدول
--
-- ⚠️ الدينار الكويتي والبحريني والريال العماني بـ **3 خانات عشرية**.
--    لو التنسيق اتعمل بخانتين، القيم هتبان غلط في 3 دول من 7.
-- -----------------------------------------------------------------------------
insert into public.countries
  (code, name_ar, name_en, dial_code, flag, currency_code, currency_ar,
   currency_en, currency_decimals, phone_digits, phone_prefix, is_active, sort_order)
values
  ('EG', 'مصر',       'Egypt',                '+20',  '🇪🇬', 'EGP', 'ج.م', 'EGP', 2, 10, '1', true,  10),
  ('SA', 'السعودية',  'Saudi Arabia',         '+966', '🇸🇦', 'SAR', 'ر.س', 'SAR', 2,  9, '5', false, 20),
  ('AE', 'الإمارات',  'United Arab Emirates', '+971', '🇦🇪', 'AED', 'د.إ', 'AED', 2,  9, '5', false, 30),
  ('KW', 'الكويت',    'Kuwait',               '+965', '🇰🇼', 'KWD', 'د.ك', 'KWD', 3,  8, null, false, 40),
  ('QA', 'قطر',       'Qatar',                '+974', '🇶🇦', 'QAR', 'ر.ق', 'QAR', 2,  8, null, false, 50),
  ('BH', 'البحرين',   'Bahrain',              '+973', '🇧🇭', 'BHD', 'د.ب', 'BHD', 3,  8, null, false, 60),
  ('OM', 'عُمان',      'Oman',                 '+968', '🇴🇲', 'OMR', 'ر.ع', 'OMR', 3,  8, null, false, 70)
on conflict (code) do update set
  name_ar           = excluded.name_ar,
  name_en           = excluded.name_en,
  currency_decimals = excluded.currency_decimals,
  phone_digits      = excluded.phone_digits,
  phone_prefix      = excluded.phone_prefix,
  is_active         = excluded.is_active;


-- -----------------------------------------------------------------------------
-- مدن مصر
--
-- market_group هو **وحدة السيولة الحقيقية** مش المدينة الإدارية:
-- القاهرة والجيزة سوق واحد لأن الناس بتتنقل بينهم يومياً.
-- -----------------------------------------------------------------------------
insert into public.cities
  (id, country_code, name_ar, name_en, lat, lng, market_group, is_active, sort_order)
values
  -- ◀︎ سوق الإطلاق
  ('cairo',    'EG', 'القاهرة',     'Cairo',      30.0444, 31.2357, 'eg_greater_cairo', true,  10),
  ('giza',     'EG', 'الجيزة',      'Giza',       30.0131, 31.2089, 'eg_greater_cairo', true,  20),

  -- الموجة التانية
  ('alex',     'EG', 'الإسكندرية',  'Alexandria', 31.2001, 29.9187, 'eg_alex',   false, 30),
  ('beheira',  'EG', 'البحيرة',     'Beheira',    31.0341, 30.4682, 'eg_alex',   false, 40),

  ('mansoura', 'EG', 'المنصورة',    'Mansoura',   31.0409, 31.3785, 'eg_delta',  false, 50),
  ('tanta',    'EG', 'طنطا',        'Tanta',      30.7865, 31.0004, 'eg_delta',  false, 60),
  ('zagazig',  'EG', 'الزقازيق',    'Zagazig',    30.5877, 31.5020, 'eg_delta',  false, 70),
  ('damietta', 'EG', 'دمياط',       'Damietta',   31.4175, 31.8144, 'eg_delta',  false, 80),

  ('ismailia', 'EG', 'الإسماعيلية', 'Ismailia',   30.5965, 32.2715, 'eg_canal',  false, 90),
  ('portsaid', 'EG', 'بورسعيد',     'Port Said',  31.2653, 32.3019, 'eg_canal',  false, 100),
  ('suez',     'EG', 'السويس',      'Suez',       29.9668, 32.5498, 'eg_canal',  false, 110),

  ('fayoum',   'EG', 'الفيوم',      'Fayoum',     29.3084, 30.8428, 'eg_upper',  false, 120),
  ('minya',    'EG', 'المنيا',      'Minya',      28.1099, 30.7503, 'eg_upper',  false, 130),
  ('asyut',    'EG', 'أسيوط',       'Asyut',      27.1783, 31.1859, 'eg_upper',  false, 140),
  ('sohag',    'EG', 'سوهاج',       'Sohag',      26.5591, 31.6957, 'eg_upper',  false, 150),

  ('luxor',    'EG', 'الأقصر',      'Luxor',      25.6872, 32.6396, 'eg_south',  false, 160),
  ('aswan',    'EG', 'أسوان',       'Aswan',      24.0889, 32.8998, 'eg_south',  false, 170),

  ('hurghada', 'EG', 'الغردقة',     'Hurghada',   27.2579, 33.8116, 'eg_redsea', false, 180)
on conflict (id) do update set
  name_ar      = excluded.name_ar,
  name_en      = excluded.name_en,
  lat          = excluded.lat,
  lng          = excluded.lng,
  market_group = excluded.market_group,
  is_active    = excluded.is_active;


-- -----------------------------------------------------------------------------
-- مدن الخليج — جاهزة ومقفولة
-- -----------------------------------------------------------------------------
insert into public.cities
  (id, country_code, name_ar, name_en, lat, lng, market_group, is_active, sort_order)
values
  ('riyadh',      'SA', 'الرياض',        'Riyadh',       24.7136, 46.6753, 'sa_riyadh',  false, 200),
  ('jeddah',      'SA', 'جدة',           'Jeddah',       21.4858, 39.1925, 'sa_jeddah',  false, 210),
  ('dammam',      'SA', 'الدمام',        'Dammam',       26.4207, 50.0888, 'sa_eastern', false, 220),
  ('khobar',      'SA', 'الخبر',         'Khobar',       26.2794, 50.2083, 'sa_eastern', false, 230),
  ('makkah',      'SA', 'مكة المكرمة',   'Makkah',       21.3891, 39.8579, 'sa_makkah',  false, 240),
  ('madinah',     'SA', 'المدينة المنورة','Madinah',     24.5247, 39.5692, 'sa_madinah', false, 250),

  ('dubai',       'AE', 'دبي',           'Dubai',        25.2048, 55.2708, 'ae_dubai',   false, 300),
  ('sharjah',     'AE', 'الشارقة',       'Sharjah',      25.3463, 55.4209, 'ae_dubai',   false, 310),
  ('ajman',       'AE', 'عجمان',         'Ajman',        25.4052, 55.5136, 'ae_dubai',   false, 320),
  ('abudhabi',    'AE', 'أبوظبي',        'Abu Dhabi',    24.4539, 54.3773, 'ae_abudhabi',false, 330),
  ('alain',       'AE', 'العين',         'Al Ain',       24.1302, 55.8023, 'ae_abudhabi',false, 340),

  ('kuwaitcity',  'KW', 'مدينة الكويت',  'Kuwait City',  29.3759, 47.9774, 'kw_metro',   false, 400),
  ('hawalli',     'KW', 'حولي',          'Hawalli',      29.3328, 48.0289, 'kw_metro',   false, 410),
  ('salmiya',     'KW', 'السالمية',      'Salmiya',      29.3339, 48.0755, 'kw_metro',   false, 420),
  ('farwaniya',   'KW', 'الفروانية',     'Farwaniya',    29.2775, 47.9586, 'kw_metro',   false, 430),

  ('doha',        'QA', 'الدوحة',        'Doha',         25.2854, 51.5310, 'qa_doha',    false, 500),
  ('rayyan',      'QA', 'الريان',        'Al Rayyan',    25.2919, 51.4244, 'qa_doha',    false, 510),

  ('manama',      'BH', 'المنامة',       'Manama',       26.2285, 50.5860, 'bh_metro',   false, 600),
  ('muharraq',    'BH', 'المحرق',        'Muharraq',     26.2572, 50.6119, 'bh_metro',   false, 610),
  ('riffa',       'BH', 'الرفاع',        'Riffa',        26.1300, 50.5550, 'bh_metro',   false, 620),

  ('muscat',      'OM', 'مسقط',          'Muscat',       23.5880, 58.3829, 'om_muscat',  false, 700),
  ('sohar',       'OM', 'صحار',          'Sohar',        24.3417, 56.7094, 'om_north',   false, 710),
  ('salalah',     'OM', 'صلالة',         'Salalah',      17.0151, 54.0924, 'om_dhofar',  false, 720)
on conflict (id) do nothing;


-- -----------------------------------------------------------------------------
-- مناطق القاهرة الكبرى
-- -----------------------------------------------------------------------------
insert into public.areas (id, city_id, name_ar, name_en, lat, lng)
values
  ('cairo.nasr',      'cairo', 'مدينة نصر',      'Nasr City',        30.0626, 31.3450),
  ('cairo.heliopolis','cairo', 'مصر الجديدة',    'Heliopolis',       30.0880, 31.3280),
  ('cairo.maadi',     'cairo', 'المعادي',        'Maadi',            29.9600, 31.2570),
  ('cairo.zamalek',   'cairo', 'الزمالك',        'Zamalek',          30.0610, 31.2200),
  ('cairo.downtown',  'cairo', 'وسط البلد',      'Downtown',         30.0459, 31.2394),
  ('cairo.newcairo',  'cairo', 'القاهرة الجديدة','New Cairo',        30.0300, 31.4700),
  ('cairo.shubra',    'cairo', 'شبرا',           'Shubra',           30.1100, 31.2450),
  ('cairo.ainshams',  'cairo', 'عين شمس',        'Ain Shams',        30.1300, 31.3200),
  ('cairo.mokattam',  'cairo', 'المقطم',         'Mokattam',         30.0100, 31.3100),
  ('cairo.helwan',    'cairo', 'حلوان',          'Helwan',           29.8500, 31.3340),

  ('giza.dokki',      'giza',  'الدقي',          'Dokki',            30.0380, 31.2120),
  ('giza.mohandessin','giza',  'المهندسين',      'Mohandessin',      30.0570, 31.2000),
  ('giza.haram',      'giza',  'الهرم',          'Haram',            29.9900, 31.1600),
  ('giza.faisal',     'giza',  'فيصل',           'Faisal',           30.0060, 31.1800),
  ('giza.october',    'giza',  '٦ أكتوبر',       '6th of October',   29.9400, 30.9200),
  ('giza.zayed',      'giza',  'الشيخ زايد',     'Sheikh Zayed',     30.0400, 30.9700),
  ('giza.agouza',     'giza',  'العجوزة',        'Agouza',           30.0560, 31.2100),
  ('giza.imbaba',     'giza',  'إمبابة',         'Imbaba',           30.0770, 31.2070)
on conflict (id) do nothing;


-- -----------------------------------------------------------------------------
-- أماكن اللقاء المعتمدة — القاهرة الكبرى
--
-- ⚠️ ملاحظة تشغيلية: الإحداثيات هنا **تقريبية** ولازم تتراجع ميدانياً
--    قبل الإطلاق. دي بيانات أمان — الخطأ فيها بيوصّل حد لمكان غلط.
--
--    القائمة دي نقطة بداية مش نهائية. المعيار لإضافة مكان:
--    عام · مزدحم · مضاء · فيه كاميرات أو أمن · وصول مواصلات سهل.
-- -----------------------------------------------------------------------------
insert into public.meeting_places
  (city_id, area_id, name_ar, name_en, kind, lat, lng, safe_hours)
values
  ('cairo', 'cairo.nasr',       'سيتي ستارز',            'City Stars',              'mall',           30.0728, 31.3460, int4range(10, 23)),
  ('cairo', 'cairo.newcairo',   'كايرو فيستيفال سيتي',   'Cairo Festival City',     'mall',           30.0290, 31.4090, int4range(10, 23)),
  ('cairo', 'cairo.newcairo',   'داون تاون كاتاميا',     'Downtown Katameya',       'mall',           30.0180, 31.4300, int4range(10, 23)),
  ('cairo', 'cairo.heliopolis', 'سيتي سنتر ألماظة',      'City Centre Almaza',      'mall',           30.0930, 31.3690, int4range(10, 23)),
  ('cairo', 'cairo.maadi',      'محطة مترو المعادي',     'Maadi Metro Station',     'metro_station',  29.9600, 31.2570, int4range(8, 21)),
  ('cairo', 'cairo.downtown',   'محطة مترو السادات',     'Sadat Metro Station',     'metro_station',  30.0444, 31.2357, int4range(8, 21)),
  ('cairo', 'cairo.nasr',       'قسم شرطة مدينة نصر',    'Nasr City Police Station','police_station', 30.0560, 31.3380, int4range(9, 20)),
  ('cairo', 'cairo.zamalek',    'كافيه بالزمالك',        'Zamalek Café Point',      'cafe',           30.0610, 31.2200, int4range(10, 22)),

  ('giza',  'giza.october',     'مول العرب',             'Mall of Arabia',          'mall',           29.9760, 30.9430, int4range(10, 23)),
  ('giza',  'giza.october',     'مول مصر',               'Mall of Egypt',           'mall',           29.9720, 31.0170, int4range(10, 23)),
  ('giza',  'giza.dokki',       'محطة مترو الدقي',       'Dokki Metro Station',     'metro_station',  30.0380, 31.2120, int4range(8, 21)),
  ('giza',  'giza.mohandessin', 'قسم شرطة العجوزة',      'Agouza Police Station',   'police_station', 30.0560, 31.2050, int4range(9, 20))
on conflict do nothing;


-- -----------------------------------------------------------------------------
-- المصطلحات المحظورة — الطبقة الأولى من فحص المحتوى
--
-- ⚠️ قائمة بداية مش نهائية، ولازم تتوسّع بالمراجعة البشرية للبلاغات.
--
-- الفلسفة: القائمة دي **رخيصة وسريعة** وبتصفّي الأغلبية. اللي بيعدي
-- منها ويفضل مشكوك فيه بس هو اللي بيروح للموديل القوي — عشان تكلفة
-- الذكاء الاصطناعي بند حقيقي بيتضاعف مع النمو.
--
-- severity: 1 مراجعة · 2 تعليق · 3 رفض فوري
-- -----------------------------------------------------------------------------
insert into public.banned_terms (term, category, severity)
values
  -- أسلحة
  ('سلاح',        'weapons', 3),
  ('مسدس',        'weapons', 3),
  ('بندقية',      'weapons', 3),
  ('خرطوش',       'weapons', 3),
  ('ذخيرة',       'weapons', 3),
  ('طلقات',       'weapons', 3),
  ('سنجة',        'weapons', 2),
  ('مطواة',       'weapons', 2),
  ('gun',         'weapons', 3),
  ('pistol',      'weapons', 3),
  ('ammo',        'weapons', 3),

  -- أدوية ومواد
  ('ترامادول',    'drugs', 3),
  ('حبوب منع',    'drugs', 2),
  ('مخدرات',      'drugs', 3),
  ('حشيش',        'drugs', 3),
  ('استروكس',     'drugs', 3),
  ('منشطات',      'drugs', 2),
  ('tramadol',    'drugs', 3),

  -- كحول وتبغ
  ('خمور',        'alcohol', 3),
  ('ويسكي',       'alcohol', 3),
  ('بيرة',        'alcohol', 3),
  ('سجائر',       'tobacco', 2),
  ('معسل',        'tobacco', 2),
  ('فيب',         'tobacco', 2),

  -- تقليد ومسروقات
  ('تقليد درجة',  'counterfeit', 2),
  ('ريبليكا',     'counterfeit', 2),
  ('replica',     'counterfeit', 2),
  ('مسروق',       'stolen', 3),
  ('مش بفاتورة',  'stolen', 1),
  ('مقفول اي كلاود', 'stolen', 3),
  ('icloud locked', 'stolen', 3),

  -- مستندات وحسابات
  ('بطاقة رقم قومي', 'documents', 3),
  ('رخصة قيادة',  'documents', 3),
  ('جواز سفر',    'documents', 3),
  ('شهادة ميلاد', 'documents', 3),
  ('حساب مسروق',  'accounts', 3),

  -- حيوانات حية
  ('كلب للبيع',   'live_animals', 3),
  ('قطة للبيع',   'live_animals', 3),
  ('صقر',         'live_animals', 3),

  -- عملات مشفرة
  ('بيتكوين',     'crypto', 2),
  ('bitcoin',     'crypto', 2),
  ('usdt',        'crypto', 2)
on conflict do nothing;


-- -----------------------------------------------------------------------------
-- تفعيل مصر فقط عند الإطلاق — تأكيد صريح
-- -----------------------------------------------------------------------------
update public.countries set is_active = (code = 'EG');
update public.cities    set is_active = (market_group = 'eg_greater_cairo');
