import 'package:flutter/foundation.dart';

import '../catalog/countries.dart';

/// مستويات الثقة — بديل الـ Trust Score الرقمي.
enum TrustLevel { newbie, verified, trusted, elite }

extension TrustLevelX on TrustLevel {
  String get labelKey => switch (this) {
        TrustLevel.newbie => 'trust.new',
        TrustLevel.verified => 'trust.verified',
        TrustLevel.trusted => 'trust.trusted',
        TrustLevel.elite => 'trust.elite',
      };
}

enum ItemCondition { brandNew, likeNew, good, fair, forParts }

extension ItemConditionX on ItemCondition {
  String get labelKey => switch (this) {
        ItemCondition.brandNew => 'item.cond.new',
        ItemCondition.likeNew => 'item.cond.likeNew',
        ItemCondition.good => 'item.cond.good',
        ItemCondition.fair => 'item.cond.fair',
        ItemCondition.forParts => 'item.cond.forParts',
      };
}

enum ItemStatus { available, reserved, negotiating, traded, inactive }

extension ItemStatusX on ItemStatus {
  String get labelKey => switch (this) {
        ItemStatus.available => 'item.status.available',
        ItemStatus.reserved => 'item.status.reserved',
        ItemStatus.negotiating => 'item.status.negotiating',
        ItemStatus.traded => 'item.status.traded',
        ItemStatus.inactive => 'item.status.inactive',
      };
}

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
        TradeStage.completed => 4,
        TradeStage.cancelled => 4,
        TradeStage.disputed => 4,
      };
}

enum SwipeIntent { skip, interested, dream }

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
    this.avatarSeed = 0,
    this.responseHours = 4,
    this.phoneVerified = false,
    this.emailVerified = true,
  });

  final String id;
  final String displayName;
  final String username;
  final String countryCode;
  final String cityId;
  final TrustLevel trustLevel;
  final int completedTrades;
  final double rating;
  final int ratingCount;
  final int memberSinceYear;
  final String bio;

  /// بديل مؤقت للصورة لحد ما يتربط التخزين.
  final int avatarSeed;

  final int responseHours;
  final bool phoneVerified;
  final bool emailVerified;

  Country get country => Countries.byCode(countryCode);

  City get city => country.cities.firstWhere(
        (c) => c.id == cityId,
        orElse: () => country.cities.first,
      );
}

@immutable
class Item {
  const Item({
    required this.id,
    required this.ownerId,
    required this.titleAr,
    required this.titleEn,
    required this.categoryId,
    required this.condition,
    required this.status,
    required this.valueMin,
    required this.valueMax,
    required this.countryCode,
    required this.cityId,
    this.subCategoryId,
    this.brand = '',
    this.model = '',
    this.descriptionAr = '',
    this.descriptionEn = '',
    this.photoCount = 1,
    this.imageSeed = 0,
    this.interestedCount = 0,
    this.wishlistCount = 0,
    this.comparableCount = 0,
    this.aiConfidence = 0.0,
    this.wantedCategoryIds = const [],
    this.isService = false,
  });

  final String id;
  final String ownerId;
  final String titleAr;
  final String titleEn;
  final String categoryId;
  final String? subCategoryId;
  final ItemCondition condition;
  final ItemStatus status;

  /// نطاق القيمة التقديري بعملة بلد المنتج.
  final double valueMin;
  final double valueMax;

  final String countryCode;
  final String cityId;
  final String brand;
  final String model;
  final String descriptionAr;
  final String descriptionEn;
  final int photoCount;
  final int imageSeed;
  final int interestedCount;
  final int wishlistCount;

  /// عدد المنتجات المشابهة اللي اتبنى عليها التقدير.
  final int comparableCount;

  /// ثقة النموذج في التقدير. أقل من 0.6 يعني ما نعرضش تقدير.
  final double aiConfidence;

  final List<String> wantedCategoryIds;
  final bool isService;

  String title(bool ar) => ar ? titleAr : titleEn;
  String description(bool ar) => ar ? descriptionAr : descriptionEn;

  Country get country => Countries.byCode(countryCode);

  bool get hasReliableEstimate => aiConfidence >= 0.6;
}

/// كارت الصفقة — مش كارت منتج.
///
/// ده الفرق الجوهري بين Giraffe وأي سوق إلكتروني: المستخدم بيسحب
/// على **صفقة كاملة** مش على منتج مجرد.
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

  /// نسبة التوافق من 0 لـ 100.
  final int compatibility;

  final double distanceKm;

  /// موجب = أنا أدفع فرق. سالب = أنا أستلم فرق. صفر = تعادل.
  final double cashDelta;
}

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
}

enum MessageKind { text, image, offer, system, meeting }

@immutable
class Message {
  const Message({
    required this.id,
    required this.kind,
    required this.isMine,
    required this.time,
    this.text = '',
    this.offer,
  });

  final String id;
  final MessageKind kind;
  final bool isMine;
  final String time;
  final String text;
  final TradeOffer? offer;
}

enum OfferStatus { pending, accepted, declined, countered }

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
}

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
}

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
}

enum NotificationKind { match, message, offer, wishlist, nearby, system }

@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.titleAr,
    required this.titleEn,
    required this.time,
    this.unread = true,
  });

  final String id;
  final NotificationKind kind;
  final String titleAr;
  final String titleEn;
  final String time;
  final bool unread;

  String title(bool ar) => ar ? titleAr : titleEn;
}
