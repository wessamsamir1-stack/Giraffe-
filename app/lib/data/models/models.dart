import 'package:flutter/foundation.dart';

import '../catalog/countries.dart';

// -----------------------------------------------------------------------------
// أدوات تحويل آمنة
//
// أي حقل جاي من الشبكة ممكن يكون null أو من نوع غير متوقع. القاعدة هنا:
// **ماينفعش صف واحد غلط يكسر الشاشة كلها**.
// -----------------------------------------------------------------------------
String _str(Object? value, [String fallback = '']) =>
    value == null ? fallback : value.toString();

int _int(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? fallback;
}

double _dbl(Object? value, [double fallback = 0]) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? fallback;
}

double? _dblOrNull(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

bool _bool(Object? value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is String) return value == 'true' || value == 't';
  return fallback;
}

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString());

T _enumFrom<T extends Enum>(List<T> values, Object? raw, T fallback) {
  final key = _str(raw);
  for (final value in values) {
    if (value.wire == key) return value;
  }
  return fallback;
}

/// اسم القيمة كما هو مخزّن في قاعدة البيانات.
extension EnumWire on Enum {
  String get wire {
    // camelCase في الدارت ← snake_case في بوستجرس
    return name.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (m) => '_${m.group(0)!.toLowerCase()}',
    );
  }
}

// -----------------------------------------------------------------------------
// مستويات الثقة
// -----------------------------------------------------------------------------
enum TrustLevel { newbie, verified, trusted, elite }

extension TrustLevelX on TrustLevel {
  /// `newbie` في الدارت اسمها `new` في القاعدة (كلمة محجوزة في الدارت).
  String get dbValue => this == TrustLevel.newbie ? 'new' : name;

  static TrustLevel parse(Object? raw) => switch (_str(raw)) {
        'verified' => TrustLevel.verified,
        'trusted' => TrustLevel.trusted,
        'elite' => TrustLevel.elite,
        _ => TrustLevel.newbie,
      };

  String get labelKey => switch (this) {
        TrustLevel.newbie => 'trust.new',
        TrustLevel.verified => 'trust.verified',
        TrustLevel.trusted => 'trust.trusted',
        TrustLevel.elite => 'trust.elite',
      };
}

// -----------------------------------------------------------------------------
enum ItemCondition { brandNew, likeNew, good, fair, forParts }

extension ItemConditionX on ItemCondition {
  String get labelKey => switch (this) {
        ItemCondition.brandNew => 'item.cond.new',
        ItemCondition.likeNew => 'item.cond.likeNew',
        ItemCondition.good => 'item.cond.good',
        ItemCondition.fair => 'item.cond.fair',
        ItemCondition.forParts => 'item.cond.forParts',
      };

  static ItemCondition parse(Object? raw) =>
      _enumFrom(ItemCondition.values, raw, ItemCondition.good);
}

// -----------------------------------------------------------------------------
enum ItemStatus {
  draft,
  pending,
  available,
  reserved,
  negotiating,
  traded,
  inactive,
  rejected,
}

extension ItemStatusX on ItemStatus {
  String get labelKey => switch (this) {
        ItemStatus.available => 'item.status.available',
        ItemStatus.reserved => 'item.status.reserved',
        ItemStatus.negotiating => 'item.status.negotiating',
        ItemStatus.traded => 'item.status.traded',
        _ => 'item.status.inactive',
      };

  static ItemStatus parse(Object? raw) =>
      _enumFrom(ItemStatus.values, raw, ItemStatus.available);
}

// -----------------------------------------------------------------------------
enum TradeStage {
  negotiating,
  offerPending,
  agreed,
  meetingSet,
  completed,
  cancelled,
  disputed,
}

extension TradeStageX on TradeStage {
  String get labelKey => switch (this) {
        TradeStage.negotiating => 'room.negotiating',
        TradeStage.offerPending => 'room.offerPending',
        TradeStage.agreed => 'room.agreed',
        TradeStage.meetingSet => 'room.meetingSet',
        TradeStage.completed => 'room.completed',
        TradeStage.cancelled => 'room.cancelled',
        TradeStage.disputed => 'room.disputed',
      };

  int get step => switch (this) {
        TradeStage.negotiating => 0,
        TradeStage.offerPending => 1,
        TradeStage.agreed => 2,
        TradeStage.meetingSet => 3,
        _ => 4,
      };

  static TradeStage parse(Object? raw) =>
      _enumFrom(TradeStage.values, raw, TradeStage.negotiating);
}

// -----------------------------------------------------------------------------
enum SwipeIntent { skip, interested, dream }

enum MessageKind { text, image, offer, meeting, system }

extension MessageKindX on MessageKind {
  static MessageKind parse(Object? raw) =>
      _enumFrom(MessageKind.values, raw, MessageKind.text);
}

enum OfferStatus { pending, accepted, declined, countered, expired }

extension OfferStatusX on OfferStatus {
  static OfferStatus parse(Object? raw) =>
      _enumFrom(OfferStatus.values, raw, OfferStatus.pending);
}

enum NotificationKind { match, message, offer, wishlist, nearby, meeting, review, system }

extension NotificationKindX on NotificationKind {
  static NotificationKind parse(Object? raw) =>
      _enumFrom(NotificationKind.values, raw, NotificationKind.system);
}

// =============================================================================
// الملف الشخصي
// =============================================================================
@immutable
class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.username,
    required this.countryCode,
    required this.cityId,
    required this.trustLevel,
    required this.completedTrades,
    required this.rating,
    required this.ratingCount,
    required this.memberSinceYear,
    this.bio = '',
    this.avatarPath,
    this.avatarSeed = 0,
    this.responseHours = 4,
    this.phoneVerified = false,
    this.emailVerified = true,
    this.areaId,
  });

  final String id;
  final String displayName;
  final String username;
  final String countryCode;
  final String cityId;
  final String? areaId;
  final TrustLevel trustLevel;
  final int completedTrades;
  final double rating;
  final int ratingCount;
  final int memberSinceYear;
  final String bio;
  final String? avatarPath;

  /// بديل لوني ثابت لحد ما الصورة تترفع.
  final int avatarSeed;

  final int responseHours;
  final bool phoneVerified;
  final bool emailVerified;

  Country get country => Countries.byCode(countryCode);

  City get city => country.cities.firstWhere(
        (c) => c.id == cityId,
        orElse: () => country.cities.first,
      );

  /// الصف بييجي من `profiles` مع `user_stats` مدمجة (join أو embed).
  factory UserProfile.fromMap(Map<String, dynamic> row) {
    final stats = row['user_stats'];
    final s = stats is List
        ? (stats.isEmpty ? const <String, dynamic>{} : stats.first as Map<String, dynamic>)
        : (stats as Map<String, dynamic>? ?? const <String, dynamic>{});

    final created = _date(row['created_at']);
    final username = _str(row['username']);

    return UserProfile(
      id: _str(row['id']),
      displayName: _str(row['display_name'], username),
      username: username,
      countryCode: _str(row['country_code'], 'EG'),
      cityId: _str(row['city_id'], 'cairo'),
      areaId: row['area_id'] as String?,
      trustLevel: TrustLevelX.parse(s['trust_level']),
      completedTrades: _int(s['completed_trades']),
      rating: _dbl(s['rating_avg']),
      ratingCount: _int(s['rating_count']),
      memberSinceYear: created?.year ?? DateTime.now().year,
      bio: _str(row['bio']),
      avatarPath: row['avatar_path'] as String?,
      avatarSeed: username.isEmpty ? 0 : username.codeUnitAt(0),
      responseHours: (_int(s['avg_response_minutes'], 240) / 60).ceil(),
      phoneVerified: _bool(row['phone_verified']),
      emailVerified: _bool(row['email_verified'], true),
    );
  }
}

// =============================================================================
// المنتج
//
// ملاحظة تصميمية: العنوان والوصف **نص واحد** مش مترجم.
// ده محتوى بيكتبه المستخدم بلغته — الترجمة بتخص الكتالوج (الأقسام والمدن)
// مش محتوى الناس.
// =============================================================================
@immutable
class Item {
  const Item({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.categoryId,
    required this.condition,
    required this.status,
    required this.countryCode,
    required this.cityId,
    this.subCategoryId,
    this.description = '',
    this.valueMin,
    this.valueMax,
    this.currencyCode = 'EGP',
    this.brand = '',
    this.model = '',
    this.photoCount = 1,
    this.coverPath,
    this.imageSeed = 0,
    this.interestedCount = 0,
    this.wishlistCount = 0,
    this.comparableCount = 0,
    this.aiConfidence = 0.0,
    this.wantedCategoryIds = const [],
    this.isService = false,
    this.reservedUntil,
  });

  final String id;
  final String ownerId;
  final String title;
  final String description;
  final String categoryId;
  final String? subCategoryId;
  final ItemCondition condition;
  final ItemStatus status;

  /// نطاق القيمة التقديري. `null` معناه إن الثقة كانت أقل من الحد
  /// فما عرضناش تقدير أصلاً — وده مقصود مش نقص بيانات.
  final double? valueMin;
  final double? valueMax;
  final String currencyCode;

  final String countryCode;
  final String cityId;
  final String brand;
  final String model;
  final int photoCount;
  final String? coverPath;
  final int imageSeed;
  final int interestedCount;
  final int wishlistCount;
  final int comparableCount;
  final double aiConfidence;
  final List<String> wantedCategoryIds;
  final bool isService;
  final DateTime? reservedUntil;

  Country get country => Countries.byCode(countryCode);

  City get city => country.cities.firstWhere(
        (c) => c.id == cityId,
        orElse: () => country.cities.first,
      );

  /// ثقة أقل من 0.60 = ما نعرضش تقدير خالص.
  bool get hasReliableEstimate =>
      aiConfidence >= 0.6 && valueMin != null && valueMax != null;

  double get midValue =>
      ((valueMin ?? 0) + (valueMax ?? valueMin ?? 0)) / 2;

  factory Item.fromMap(Map<String, dynamic> row) {
    final wanted = row['item_wanted_categories'];
    final photos = row['item_photos'];

    String? cover;
    if (photos is List && photos.isNotEmpty) {
      final first = photos.firstWhere(
        (p) => _bool((p as Map<String, dynamic>)['is_cover']),
        orElse: () => photos.first,
      ) as Map<String, dynamic>;
      cover = first['storage_path'] as String?;
    }

    final id = _str(row['id']);

    return Item(
      id: id,
      ownerId: _str(row['owner_id']),
      title: _str(row['title']),
      description: _str(row['description']),
      categoryId: _str(row['category_id'], 'misc'),
      subCategoryId: row['subcategory_id'] as String?,
      condition: ItemConditionX.parse(row['condition']),
      status: ItemStatusX.parse(row['status']),
      valueMin: _dblOrNull(row['value_min']),
      valueMax: _dblOrNull(row['value_max']),
      currencyCode: _str(row['currency_code'], 'EGP'),
      countryCode: _str(row['country_code'], 'EG'),
      cityId: _str(row['city_id'], 'cairo'),
      brand: _str(row['brand']),
      model: _str(row['model']),
      photoCount: _int(row['photo_count'], 1),
      coverPath: cover,
      imageSeed: id.isEmpty ? 0 : id.codeUnits.fold<int>(0, (a, b) => a + b),
      interestedCount: _int(row['interested_count']),
      wishlistCount: _int(row['wishlist_count']),
      comparableCount: _int(row['comparable_count']),
      aiConfidence: _dbl(row['ai_confidence']),
      isService: _bool(row['is_service']),
      reservedUntil: _date(row['reserved_until']),
      wantedCategoryIds: wanted is List
          ? wanted
              .map((w) => _str((w as Map<String, dynamic>)['category_id']))
              .where((c) => c.isNotEmpty)
              .toList()
          : const [],
    );
  }
}

// =============================================================================
// كارت الصفقة — مش كارت منتج
// =============================================================================
@immutable
class TradeCandidate {
  const TradeCandidate({
    required this.id,
    required this.theirItem,
    required this.theirOwner,
    required this.myItem,
    required this.compatibility,
    required this.distanceKm,
    this.cashDelta = 0,
  });

  final String id;
  final Item theirItem;
  final UserProfile theirOwner;
  final Item myItem;

  /// من 0 لـ 100.
  final int compatibility;

  final double distanceKm;

  /// موجب = أنا أدفع فرق · سالب = أنا أستلم فرق.
  final double cashDelta;

  /// الصف جاي من `get_deck` مع المنتجات والملف مدموجين في الاستعلام.
  factory TradeCandidate.fromMap(
    Map<String, dynamic> row, {
    required Item theirItem,
    required UserProfile theirOwner,
    required Item myItem,
  }) {
    return TradeCandidate(
      id: '${_str(row['their_item_id'])}:${_str(row['my_item_id'])}',
      theirItem: theirItem,
      theirOwner: theirOwner,
      myItem: myItem,
      compatibility: _int(row['compatibility']),
      distanceKm: _dbl(row['distance_km']),
      cashDelta: _dbl(row['cash_delta']),
    );
  }
}

// =============================================================================
// الماتش
// =============================================================================
@immutable
class TradeMatch {
  const TradeMatch({
    required this.id,
    required this.other,
    required this.myItem,
    required this.theirItem,
    required this.stage,
    required this.lastMessage,
    required this.lastActivity,
    this.unread = 0,
    this.archived = false,
    this.closedByBlock = false,
    this.frozen = false,
  });

  final String id;
  final UserProfile other;
  final Item myItem;
  final Item theirItem;
  final TradeStage stage;
  final String lastMessage;
  final String lastActivity;
  final int unread;
  final bool archived;
  final bool closedByBlock;
  final bool frozen;

  /// الغرفة تقبل إرسال رسائل؟
  bool get isWritable =>
      !closedByBlock &&
      !frozen &&
      stage != TradeStage.completed &&
      stage != TradeStage.cancelled;
}

// =============================================================================
@immutable
class Message {
  const Message({
    required this.id,
    required this.kind,
    required this.isMine,
    required this.time,
    this.text = '',
    this.offer,
    this.createdAt,
  });

  final String id;
  final MessageKind kind;
  final bool isMine;
  final String time;
  final String text;
  final TradeOffer? offer;
  final DateTime? createdAt;

  factory Message.fromMap(
    Map<String, dynamic> row, {
    required String myId,
    TradeOffer? offer,
  }) {
    final created = _date(row['created_at']);
    return Message(
      id: _str(row['id']),
      kind: MessageKindX.parse(row['kind']),
      isMine: _str(row['sender_id']) == myId,
      time: created == null
          ? ''
          : '${created.hour.toString().padLeft(2, '0')}:'
              '${created.minute.toString().padLeft(2, '0')}',
      text: _str(row['body']),
      offer: offer,
      createdAt: created,
    );
  }
}

// =============================================================================
@immutable
class TradeOffer {
  const TradeOffer({
    required this.id,
    required this.giveItem,
    required this.getItem,
    required this.cashDelta,
    required this.status,
    required this.fromMe,
  });

  final String id;
  final Item giveItem;
  final Item getItem;
  final double cashDelta;
  final OfferStatus status;
  final bool fromMe;
}

// =============================================================================
@immutable
class WishItem {
  const WishItem({
    required this.id,
    required this.categoryId,
    this.subCategoryId,
    this.keyword = '',
    this.maxValue,
    this.notify = true,
  });

  final String id;
  final String categoryId;
  final String? subCategoryId;
  final String keyword;
  final double? maxValue;
  final bool notify;

  factory WishItem.fromMap(Map<String, dynamic> row) => WishItem(
        id: _str(row['id']),
        categoryId: _str(row['category_id']),
        subCategoryId: row['subcategory_id'] as String?,
        keyword: _str(row['keyword']),
        maxValue: _dblOrNull(row['max_value']),
        notify: _bool(row['notify'], true),
      );

  Map<String, dynamic> toInsert(String userId) => {
        'user_id': userId,
        'category_id': categoryId,
        if (subCategoryId != null) 'subcategory_id': subCategoryId,
        if (keyword.isNotEmpty) 'keyword': keyword,
        if (maxValue != null) 'max_value': maxValue,
        'notify': notify,
      };
}

// =============================================================================
@immutable
class MeetingPlace {
  const MeetingPlace({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.typeAr,
    required this.typeEn,
    required this.cityId,
    required this.distanceKm,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final String typeAr;
  final String typeEn;
  final String cityId;
  final double distanceKm;

  String name(bool ar) => ar ? nameAr : nameEn;
  String type(bool ar) => ar ? typeAr : typeEn;

  static const Map<String, (String, String)> _kinds = {
    'mall': ('مركز تجاري', 'Shopping mall'),
    'police_station': ('مركز شرطة', 'Police station'),
    'cafe': ('مقهى', 'Coffee shop'),
    'metro_station': ('محطة مترو', 'Metro station'),
    'fuel_station': ('محطة وقود', 'Fuel station'),
    'public_square': ('ميدان عام', 'Public square'),
  };

  factory MeetingPlace.fromMap(Map<String, dynamic> row) {
    final kind = _kinds[_str(row['kind'])] ?? ('مكان عام', 'Public place');
    return MeetingPlace(
      id: _str(row['id']),
      nameAr: _str(row['name_ar']),
      nameEn: _str(row['name_en']),
      typeAr: kind.$1,
      typeEn: kind.$2,
      cityId: _str(row['city_id']),
      distanceKm: _dbl(row['distance_km']),
    );
  }
}

// =============================================================================
@immutable
class Review {
  const Review({
    required this.id,
    required this.author,
    required this.rating,
    required this.comment,
    required this.date,
  });

  final String id;
  final String author;
  final double rating;
  final String comment;
  final String date;

  factory Review.fromMap(Map<String, dynamic> row) {
    final reviewer = row['reviewer'] as Map<String, dynamic>?;
    return Review(
      id: _str(row['id']),
      author: _str(reviewer?['display_name'], 'مستخدم'),
      rating: _dbl(row['overall']),
      comment: _str(row['comment']),
      date: _str(row['published_at']).split('T').first,
    );
  }
}

// =============================================================================
@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.titleAr,
    required this.titleEn,
    required this.time,
    this.unread = true,
    this.payload = const {},
  });

  final String id;
  final NotificationKind kind;
  final String titleAr;
  final String titleEn;
  final String time;
  final bool unread;
  final Map<String, dynamic> payload;

  String title(bool ar) => ar ? titleAr : titleEn;

  factory AppNotification.fromMap(Map<String, dynamic> row) => AppNotification(
        id: _str(row['id']),
        kind: NotificationKindX.parse(row['kind']),
        titleAr: _str(row['title_ar']),
        titleEn: _str(row['title_en']),
        time: _str(row['created_at']).split('T').first,
        unread: row['read_at'] == null,
        payload: (row['payload'] as Map<String, dynamic>?) ?? const {},
      );
}
