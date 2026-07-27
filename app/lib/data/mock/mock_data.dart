import '../models/models.dart';

/// بيانات تجريبية للتصميم المبدئي.
///
/// كل ده بيتشال لما تتربط سوبابيز — الشاشات بتقرأ من هنا بس.
class Mock {
  const Mock._();

  // ------------------------------------------------------------- المستخدمون
  static const me = UserProfile(
    id: 'u_me',
    displayName: 'وسام سمير',
    username: 'wessam',
    countryCode: 'EG',
    cityId: 'cairo',
    trustLevel: TrustLevel.trusted,
    completedTrades: 12,
    rating: 4.7,
    ratingCount: 11,
    memberSinceYear: 2025,
    bio: 'بحب الإلكترونيات والكاميرات. صفقاتي كلها في وسط البلد أو مدينة نصر.',
    avatarSeed: 3,
    responseHours: 2,
    phoneVerified: true,
  );

  static const ahmed = UserProfile(
    id: 'u_ahmed',
    displayName: 'أحمد فتحي',
    username: 'ahmedf',
    countryCode: 'EG',
    cityId: 'giza',
    trustLevel: TrustLevel.elite,
    completedTrades: 34,
    rating: 4.9,
    ratingCount: 31,
    memberSinceYear: 2024,
    bio: 'مصور. بقايض عدسات وكاميرات بس.',
    avatarSeed: 1,
    responseHours: 1,
    phoneVerified: true,
  );

  static const sara = UserProfile(
    id: 'u_sara',
    displayName: 'سارة العلي',
    username: 'sara_q8',
    countryCode: 'KW',
    cityId: 'salmiya',
    trustLevel: TrustLevel.verified,
    completedTrades: 3,
    rating: 4.5,
    ratingCount: 3,
    memberSinceYear: 2026,
    avatarSeed: 5,
    responseHours: 6,
    phoneVerified: true,
  );

  static const khaled = UserProfile(
    id: 'u_khaled',
    displayName: 'خالد المطيري',
    username: 'khaled',
    countryCode: 'SA',
    cityId: 'riyadh',
    trustLevel: TrustLevel.trusted,
    completedTrades: 9,
    rating: 4.6,
    ratingCount: 8,
    memberSinceYear: 2025,
    avatarSeed: 2,
    responseHours: 3,
    phoneVerified: true,
  );

  static const mona = UserProfile(
    id: 'u_mona',
    displayName: 'منى حسن',
    username: 'mona_h',
    countryCode: 'EG',
    cityId: 'alex',
    trustLevel: TrustLevel.newbie,
    completedTrades: 0,
    rating: 0,
    ratingCount: 0,
    memberSinceYear: 2026,
    avatarSeed: 7,
    responseHours: 12,
  );

  static const users = [me, ahmed, sara, khaled, mona];

  static UserProfile user(String id) =>
      users.firstWhere((u) => u.id == id, orElse: () => me);

  // ------------------------------------------------------------- منتجاتي
  static const myPs5 = Item(
    id: 'i_ps5',
    ownerId: 'u_me',
    title: 'بلايستيشن 5 سليم مع دراعين',
    categoryId: 'gaming',
    subCategoryId: 'consoles',
    condition: ItemCondition.likeNew,
    status: ItemStatus.available,
    valueMin: 24000,
    valueMax: 28000,
    countryCode: 'EG',
    cityId: 'cairo',
    brand: 'Sony',
    model: 'PS5 Slim 1TB',
    description: 'استعمال خفيف جداً، بالكرتونة والضمان. معاه لعبتين.',
    photoCount: 4,
    imageSeed: 11,
    interestedCount: 14,
    wishlistCount: 38,
    comparableCount: 23,
    aiConfidence: 0.87,
    wantedCategoryIds: ['mobiles', 'cameras', 'computers'],
  );

  static const myLens = Item(
    id: 'i_lens',
    ownerId: 'u_me',
    title: 'عدسة كانون 50mm f/1.8',
    categoryId: 'cameras',
    subCategoryId: 'lenses',
    condition: ItemCondition.good,
    status: ItemStatus.negotiating,
    valueMin: 3500,
    valueMax: 4200,
    countryCode: 'EG',
    cityId: 'cairo',
    brand: 'Canon',
    model: 'EF 50mm f/1.8 STM',
    description: 'شغالة تمام، فيها خدش بسيط في البودي مش مؤثر.',
    photoCount: 3,
    imageSeed: 12,
    interestedCount: 6,
    wishlistCount: 12,
    comparableCount: 17,
    aiConfidence: 0.79,
    wantedCategoryIds: ['cameras', 'electronics'],
  );

  static const myDesk = Item(
    id: 'i_desk',
    ownerId: 'u_me',
    title: 'مكتب خشب زان مع كرسي',
    categoryId: 'furniture',
    subCategoryId: 'office',
    condition: ItemCondition.good,
    status: ItemStatus.available,
    valueMin: 4000,
    valueMax: 5500,
    countryCode: 'EG',
    cityId: 'cairo',
    description: 'مكتب متين ومساحته كبيرة. الكرسي جلد.',
    photoCount: 2,
    imageSeed: 13,
    interestedCount: 3,
    wishlistCount: 5,
    comparableCount: 9,
    aiConfidence: 0.52,
    wantedCategoryIds: ['electronics', 'misc'],
  );

  static const myItems = [myPs5, myLens, myDesk];

  // ------------------------------------------------------------- منتجات الآخرين
  static const iphone = Item(
    id: 'i_iphone',
    ownerId: 'u_ahmed',
    title: 'آيفون 15 برو 256 جيجا',
    categoryId: 'mobiles',
    subCategoryId: 'phones',
    condition: ItemCondition.likeNew,
    status: ItemStatus.available,
    valueMin: 38000,
    valueMax: 44000,
    countryCode: 'EG',
    cityId: 'giza',
    brand: 'Apple',
    model: 'iPhone 15 Pro',
    description: 'بطارية 94%. بالعلبة والشاحن. مفيش أي خدوش.',
    photoCount: 5,
    imageSeed: 21,
    interestedCount: 42,
    wishlistCount: 96,
    comparableCount: 31,
    aiConfidence: 0.93,
    wantedCategoryIds: ['gaming', 'computers'],
  );

  static const macbook = Item(
    id: 'i_macbook',
    ownerId: 'u_khaled',
    title: 'ماك بوك اير M2',
    categoryId: 'computers',
    subCategoryId: 'laptops',
    condition: ItemCondition.good,
    status: ItemStatus.available,
    valueMin: 2800,
    valueMax: 3400,
    countryCode: 'SA',
    cityId: 'riyadh',
    brand: 'Apple',
    model: 'MacBook Air M2 8/256',
    description: 'استعمال سنة واحدة. الشاشة نظيفة والبطارية ممتازة.',
    photoCount: 4,
    imageSeed: 22,
    interestedCount: 27,
    wishlistCount: 64,
    comparableCount: 19,
    aiConfidence: 0.88,
    wantedCategoryIds: ['cameras', 'watches'],
  );

  static const camera = Item(
    id: 'i_camera',
    ownerId: 'u_ahmed',
    title: 'كاميرا سوني A7 III بودي',
    categoryId: 'cameras',
    subCategoryId: 'dslr',
    condition: ItemCondition.good,
    status: ItemStatus.available,
    valueMin: 52000,
    valueMax: 60000,
    countryCode: 'EG',
    cityId: 'giza',
    brand: 'Sony',
    model: 'A7 III',
    description: 'شاتر 24 ألف. بالبطاريتين والشنطة.',
    photoCount: 6,
    imageSeed: 23,
    interestedCount: 19,
    wishlistCount: 51,
    comparableCount: 12,
    aiConfidence: 0.81,
    wantedCategoryIds: ['computers', 'mobiles'],
  );

  static const watch = Item(
    id: 'i_watch',
    ownerId: 'u_sara',
    title: 'ساعة أبل الجيل 9',
    categoryId: 'mobiles',
    subCategoryId: 'smartwatch',
    condition: ItemCondition.likeNew,
    status: ItemStatus.available,
    valueMin: 95,
    valueMax: 120,
    countryCode: 'KW',
    cityId: 'salmiya',
    brand: 'Apple',
    model: 'Watch S9 45mm',
    description: 'مستعملة شهرين بس. بكل الملحقات.',
    photoCount: 3,
    imageSeed: 24,
    interestedCount: 8,
    wishlistCount: 22,
    comparableCount: 14,
    aiConfidence: 0.9,
    wantedCategoryIds: ['fashion', 'watches'],
  );

  static const designService = Item(
    id: 'i_design',
    ownerId: 'u_mona',
    title: 'تصميم هوية بصرية كاملة',
    categoryId: 'services',
    subCategoryId: 'design',
    condition: ItemCondition.brandNew,
    status: ItemStatus.available,
    valueMin: 6000,
    valueMax: 9000,
    countryCode: 'EG',
    cityId: 'alex',
    description: 'لوجو + ألوان + خطوط + بروفايل. بقايضها بتصوير منتجات أو صيانة لابتوب.',
    photoCount: 4,
    imageSeed: 25,
    interestedCount: 11,
    wishlistCount: 7,
    comparableCount: 0,
    aiConfidence: 0.0,
    wantedCategoryIds: ['services', 'cameras'],
    isService: true,
  );

  static const bike = Item(
    id: 'i_bike',
    ownerId: 'u_khaled',
    title: 'دراجة جبلية Trek',
    categoryId: 'vehicles',
    subCategoryId: 'bicycles',
    condition: ItemCondition.good,
    status: ItemStatus.available,
    valueMin: 1800,
    valueMax: 2300,
    countryCode: 'SA',
    cityId: 'riyadh',
    brand: 'Trek',
    photoCount: 3,
    imageSeed: 26,
    interestedCount: 5,
    wishlistCount: 9,
    comparableCount: 8,
    aiConfidence: 0.72,
    wantedCategoryIds: ['sports', 'electronics'],
  );

  static const sofa = Item(
    id: 'i_sofa',
    ownerId: 'u_mona',
    title: 'أنتريه مودرن 3 قطع',
    categoryId: 'furniture',
    subCategoryId: 'living',
    condition: ItemCondition.good,
    status: ItemStatus.available,
    valueMin: 12000,
    valueMax: 16000,
    countryCode: 'EG',
    cityId: 'alex',
    photoCount: 5,
    imageSeed: 27,
    interestedCount: 9,
    wishlistCount: 14,
    comparableCount: 21,
    aiConfidence: 0.68,
    wantedCategoryIds: ['appliances', 'furniture'],
  );

  static const marketItems = [
    iphone,
    camera,
    macbook,
    designService,
    sofa,
    watch,
    bike,
  ];

  static Item item(String id) => [...myItems, ...marketItems]
      .firstWhere((i) => i.id == id, orElse: () => myPs5);

  // ------------------------------------------------------------- الصفقات المرشحة
  static const deck = [
    TradeCandidate(
      id: 'tc_1',
      theirItem: iphone,
      theirOwner: ahmed,
      myItem: myPs5,
      compatibility: 92,
      distanceKm: 3.4,
      cashDelta: 14000,
    ),
    TradeCandidate(
      id: 'tc_2',
      theirItem: camera,
      theirOwner: ahmed,
      myItem: myPs5,
      compatibility: 78,
      distanceKm: 3.4,
      cashDelta: 29000,
    ),
    TradeCandidate(
      id: 'tc_3',
      theirItem: designService,
      theirOwner: mona,
      myItem: myLens,
      compatibility: 71,
      distanceKm: 214,
      cashDelta: -1500,
    ),
    TradeCandidate(
      id: 'tc_4',
      theirItem: sofa,
      theirOwner: mona,
      myItem: myDesk,
      compatibility: 64,
      distanceKm: 214,
      cashDelta: 8500,
    ),
  ];

  // ------------------------------------------------------------- المقايضات
  static const matches = [
    TradeMatch(
      id: 'm_1',
      other: ahmed,
      myItem: myPs5,
      theirItem: iphone,
      stage: TradeStage.offerPending,
      lastMessage: 'تمام، أنا موافق على 14 ألف فرق',
      lastActivity: 'من 5 دقائق',
      unread: 2,
    ),
    TradeMatch(
      id: 'm_2',
      other: mona,
      myItem: myLens,
      theirItem: designService,
      stage: TradeStage.negotiating,
      lastMessage: 'ينفع نتقابل الأربع؟',
      lastActivity: 'من ساعة',
    ),
    TradeMatch(
      id: 'm_3',
      other: khaled,
      myItem: myDesk,
      theirItem: bike,
      stage: TradeStage.meetingSet,
      lastMessage: 'اتفقنا — الساعة 6 في المول',
      lastActivity: 'إمبارح',
    ),
    TradeMatch(
      id: 'm_4',
      other: sara,
      myItem: myPs5,
      theirItem: watch,
      stage: TradeStage.completed,
      lastMessage: 'شكراً! صفقة موفقة',
      lastActivity: 'من 3 أيام',
      archived: true,
    ),
  ];

  static TradeMatch match(String id) =>
      matches.firstWhere((m) => m.id == id, orElse: () => matches.first);

  // ------------------------------------------------------------- الرسائل
  static const conversation = [
    Message(
      id: 'msg_0',
      kind: MessageKind.system,
      isMine: false,
      time: '',
      text: 'اتعمل ماتش! ابدأوا التفاوض على الصفقة.',
    ),
    Message(
      id: 'msg_1',
      kind: MessageKind.text,
      isMine: false,
      time: '10:12',
      text: 'أهلاً! البلايستيشن لسه متاح؟',
    ),
    Message(
      id: 'msg_2',
      kind: MessageKind.text,
      isMine: true,
      time: '10:14',
      text: 'أهلاً بيك. أيوة متاح، بالكرتونة ومعاه لعبتين.',
    ),
    Message(
      id: 'msg_3',
      kind: MessageKind.text,
      isMine: false,
      time: '10:15',
      text: 'حلو. الآيفون عندي بطارية 94% وبالعلبة. تفتكر الفرق كام؟',
    ),
    Message(
      id: 'msg_4',
      kind: MessageKind.offer,
      isMine: true,
      time: '10:22',
      offer: TradeOffer(
        id: 'o_1',
        giveItem: myPs5,
        getItem: iphone,
        cashDelta: 14000,
        status: OfferStatus.pending,
        fromMe: true,
      ),
    ),
    Message(
      id: 'msg_5',
      kind: MessageKind.text,
      isMine: false,
      time: '10:29',
      text: 'تمام، أنا موافق على 14 ألف فرق',
    ),
  ];

  // ------------------------------------------------------------- أماكن اللقاء
  static const meetingPlaces = [
    MeetingPlace(
      id: 'p_1',
      nameAr: 'مول مصر',
      nameEn: 'Mall of Egypt',
      typeAr: 'مركز تجاري',
      typeEn: 'Shopping mall',
      cityId: 'giza',
      distanceKm: 4.2,
    ),
    MeetingPlace(
      id: 'p_2',
      nameAr: 'سيتي ستارز',
      nameEn: 'City Stars',
      typeAr: 'مركز تجاري',
      typeEn: 'Shopping mall',
      cityId: 'cairo',
      distanceKm: 6.8,
    ),
    MeetingPlace(
      id: 'p_3',
      nameAr: 'قسم شرطة مدينة نصر',
      nameEn: 'Nasr City police station',
      typeAr: 'مركز شرطة',
      typeEn: 'Police station',
      cityId: 'cairo',
      distanceKm: 2.1,
    ),
    MeetingPlace(
      id: 'p_4',
      nameAr: 'كافيه سيلانترو - التجمع',
      nameEn: 'Cilantro - New Cairo',
      typeAr: 'مقهى',
      typeEn: 'Coffee shop',
      cityId: 'cairo',
      distanceKm: 9.4,
    ),
    MeetingPlace(
      id: 'p_5',
      nameAr: 'محطة مترو الدقي',
      nameEn: 'Dokki metro station',
      typeAr: 'محطة عامة',
      typeEn: 'Public station',
      cityId: 'giza',
      distanceKm: 5.5,
    ),
  ];

  // ------------------------------------------------------------- قائمة الرغبات
  static const wishlist = [
    WishItem(id: 'w_1', categoryId: 'mobiles', subCategoryId: 'phones', keyword: 'آيفون 15'),
    WishItem(id: 'w_2', categoryId: 'cameras', subCategoryId: 'lenses', keyword: 'عدسة 24-70'),
    WishItem(id: 'w_3', categoryId: 'computers', subCategoryId: 'laptops', maxValue: 45000),
  ];

  // ------------------------------------------------------------- التقييمات
  static const reviews = [
    Review(
      id: 'r_1',
      author: 'أحمد فتحي',
      rating: 5,
      comment: 'تعامل محترم جداً والمنتج كان أحسن من الوصف. أنصح بيه.',
      date: 'من أسبوع',
    ),
    Review(
      id: 'r_2',
      author: 'سارة العلي',
      rating: 4.5,
      comment: 'وصل في الميعاد بالظبط. الصفقة اتمّت في 10 دقايق.',
      date: 'من شهر',
    ),
    Review(
      id: 'r_3',
      author: 'خالد المطيري',
      rating: 5,
      comment: 'أفضل مقايضة عملتها. شرح كل تفصيلة قبل ما نتقابل.',
      date: 'من شهرين',
    ),
  ];

  // ------------------------------------------------------------- الإشعارات
  static const notifications = [
    AppNotification(
      id: 'n_1',
      kind: NotificationKind.match,
      titleAr: 'ماتش جديد مع أحمد فتحي',
      titleEn: 'New match with Ahmed Fathy',
      time: 'من 5 دقائق',
    ),
    AppNotification(
      id: 'n_2',
      kind: NotificationKind.wishlist,
      titleAr: 'آيفون 15 برو اتضاف في القاهرة — من قائمة رغباتك',
      titleEn: 'iPhone 15 Pro listed in Cairo — from your wishlist',
      time: 'من 20 دقيقة',
    ),
    AppNotification(
      id: 'n_3',
      kind: NotificationKind.offer,
      titleAr: 'عرض جديد على البلايستيشن 5',
      titleEn: 'New offer on your PlayStation 5',
      time: 'من ساعة',
    ),
    AppNotification(
      id: 'n_4',
      kind: NotificationKind.message,
      titleAr: 'منى حسن بعتتلك رسالة',
      titleEn: 'Mona Hassan sent you a message',
      time: 'إمبارح',
      unread: false,
    ),
    AppNotification(
      id: 'n_5',
      kind: NotificationKind.nearby,
      titleAr: '6 فرص مقايضة جديدة على بعد 5 كم منك',
      titleEn: '6 new trade opportunities within 5 km',
      time: 'من يومين',
      unread: false,
    ),
  ];
}
