import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_state.dart';
import '../models/models.dart';
import 'ai_repository.dart';
import 'auth_repository.dart';
import 'deck_repository.dart';
import 'items_repository.dart';
import 'moderation_repository.dart';
import 'matches_repository.dart';
import 'notifications_repository.dart';
import 'profile_repository.dart';
import 'storage_repository.dart';
import 'wishlist_repository.dart';

// =============================================================================
// المستودعات
//
// كل مستودع بيتصرّف على الخادم لو متاح، وعلى البيانات التجريبية لو لأ.
// الشاشات مابتعرفش الفرق — وده مقصود عشان المشروع يفضل قابل للتشغيل
// من غير ما حد يجهّز خادم.
// =============================================================================
final authRepositoryProvider = Provider((ref) => const AuthRepository());
final profileRepositoryProvider = Provider((ref) => const ProfileRepository());
final itemsRepositoryProvider = Provider((ref) => const ItemsRepository());
final wishlistRepositoryProvider = Provider((ref) => const WishlistRepository());
final deckRepositoryProvider = Provider((ref) => const DeckRepository());
final matchesRepositoryProvider = Provider((ref) => const MatchesRepository());
final storageRepositoryProvider = Provider((ref) => const StorageRepository());
final notificationsRepositoryProvider =
    Provider((ref) => const NotificationsRepository());
final aiRepositoryProvider = Provider((ref) => const AiRepository());
final moderationRepositoryProvider =
    Provider((ref) => const ModerationRepository());

// =============================================================================
// البيانات
// =============================================================================

/// ملفي الشخصي.
final myProfileProvider = FutureProvider<UserProfile?>((ref) {
  return ref.watch(profileRepositoryProvider).myProfile();
});

/// منتجاتي.
final myItemsProvider = FutureProvider<List<Item>>((ref) {
  return ref.watch(itemsRepositoryProvider).myItems();
});

/// قائمة رغباتي.
final myWishlistProvider = FutureProvider<List<WishItem>>((ref) {
  return ref.watch(wishlistRepositoryProvider).mine();
});

/// السوق المفتوح — مقيّد بمجموعة سوق المستخدم.
final marketFeedProvider =
    FutureProvider.family<List<Item>, String?>((ref, categoryId) {
  final city = ref.watch(cityProvider);
  return ref.watch(itemsRepositoryProvider).market(
        categoryId: categoryId,
        marketGroup: _marketGroupFor(city.id),
      );
});

/// كروت الصفقات.
final deckProvider = FutureProvider<List<TradeCandidate>>((ref) {
  return ref.watch(deckRepositoryProvider).deck();
});

/// الحدود اليومية.
final swipeQuotaProvider = FutureProvider<({int swipes, int dreams})>((ref) {
  return ref.watch(deckRepositoryProvider).remainingToday();
});

/// الماتشات.
final matchesProvider =
    FutureProvider.family<List<TradeMatch>, bool>((ref, archived) {
  return ref.watch(matchesRepositoryProvider).list(archived: archived);
});

/// غرفة واحدة.
final matchProvider =
    FutureProvider.family<TradeMatch?, String>((ref, matchId) {
  return ref.watch(matchesRepositoryProvider).byId(matchId);
});

/// بث رسائل الغرفة.
final roomMessagesProvider =
    StreamProvider.family<List<Message>, String>((ref, matchId) {
  return ref.watch(matchesRepositoryProvider).messageStream(matchId);
});

/// رقم المستخدم الحالي.
final myUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authRepositoryProvider).currentUserId;
});

/// ملف مستخدم بالرقم.
final ownerProvider =
    FutureProvider.family<UserProfile?, String>((ref, userId) {
  return ref.watch(profileRepositoryProvider).byId(userId);
});

/// منتج واحد.
final itemProvider = FutureProvider.family<Item?, String>((ref, itemId) {
  return ref.watch(itemsRepositoryProvider).byId(itemId);
});

/// أماكن اللقاء المعتمدة في مدينة المستخدم.
final meetingPlacesProvider = FutureProvider<List<MeetingPlace>>((ref) {
  final city = ref.watch(cityProvider);
  return ref.watch(matchesRepositoryProvider).meetingPlaces(city.id);
});

/// منتجات مستخدم معيّن.
final userItemsProvider =
    FutureProvider.family<List<Item>, String>((ref, userId) {
  return ref.watch(itemsRepositoryProvider).byOwner(userId);
});

/// ملف مستخدم باسم المستخدم.
final publicProfileProvider =
    FutureProvider.family<UserProfile?, String>((ref, username) {
  return ref.watch(profileRepositoryProvider).byUsername(username);
});

/// الإشعارات.
final notificationsProvider = FutureProvider<List<AppNotification>>((ref) {
  return ref.watch(notificationsRepositoryProvider).list();
});

/// عدد الإشعارات غير المقروءة — للشارة على أيقونة الجرس.
final unreadCountProvider = FutureProvider<int>((ref) {
  return ref.watch(notificationsRepositoryProvider).unreadCount();
});

/// نتائج البحث.
final searchResultsProvider =
    FutureProvider.family<List<Item>, String>((ref, term) {
  if (term.trim().isEmpty) return Future.value(const <Item>[]);
  final city = ref.watch(cityProvider);
  return ref.watch(itemsRepositoryProvider).search(
        term,
        marketGroup: _marketGroupFor(city.id),
      );
});

/// تقييمات مستخدم.
final reviewsProvider =
    FutureProvider.family<List<Review>, String>((ref, userId) {
  return ref.watch(profileRepositoryProvider).reviewsFor(userId);
});

// -----------------------------------------------------------------------------
/// مجموعة السوق للمدينة.
///
/// مصر بس هي المفتوحة عند الإطلاق، والقاهرة والجيزة سوق واحد لأن الناس
/// بتتنقل بينهم يومياً. القيم دي مطابقة لعمود `cities.market_group`.
String _marketGroupFor(String cityId) => switch (cityId) {
      'cairo' || 'giza' => 'eg_greater_cairo',
      'alex' || 'beheira' => 'eg_alex',
      'mansoura' || 'tanta' || 'zagazig' || 'damietta' => 'eg_delta',
      'ismailia' || 'portsaid' || 'suez' => 'eg_canal',
      'fayoum' || 'minya' || 'asyut' || 'sohag' => 'eg_upper',
      'luxor' || 'aswan' => 'eg_south',
      'hurghada' => 'eg_redsea',
      _ => 'eg_greater_cairo',
    };


// -----------------------------------------------------------------------------
// المراجعة البشرية
//
// الصلاحية بتتفحص في القاعدة. الـ providers دي بتخفي اللوحة عن غير
// الطاقم — وده تحسين عرض بس، مش حماية.
// -----------------------------------------------------------------------------
final amIStaffProvider = FutureProvider<bool>((ref) {
  return ref.watch(moderationRepositoryProvider).amIStaff();
});

final moderationStatsProvider = FutureProvider<ModerationStats>((ref) {
  return ref.watch(moderationRepositoryProvider).stats();
});

final moderationQueueProvider =
    FutureProvider.family<List<QueueEntry>, FlagKind>((ref, kind) {
  return ref.watch(moderationRepositoryProvider).queue(kind: kind);
});
