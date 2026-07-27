import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_init.dart';
import '../mock/mock_data.dart';
import '../models/models.dart';

/// الملف الشخصي والإحصائيات.
class ProfileRepository {
  const ProfileRepository();

  bool get hasBackend => SupabaseInit.isReady;
  SupabaseClient get _client => SupabaseInit.client;

  static const String _columns = '*, user_stats(*)';

  Future<UserProfile?> myProfile() async {
    if (!hasBackend) return Mock.me;

    final id = _client.auth.currentUser?.id;
    if (id == null) return null;

    final rows = await _client.from('profiles').select(_columns).eq('id', id);
    if (rows.isEmpty) return null;
    return UserProfile.fromMap(rows.first);
  }

  Future<UserProfile?> byUsername(String username) async {
    if (!hasBackend) {
      return Mock.users.firstWhere(
        (u) => u.username == username,
        orElse: () => Mock.ahmed,
      );
    }

    final rows =
        await _client.from('profiles').select(_columns).eq('username', username);
    if (rows.isEmpty) return null;
    return UserProfile.fromMap(rows.first);
  }

  Future<UserProfile?> byId(String id) async {
    if (!hasBackend) return Mock.user(id);

    final rows = await _client.from('profiles').select(_columns).eq('id', id);
    if (rows.isEmpty) return null;
    return UserProfile.fromMap(rows.first);
  }

  /// إنشاء أو تحديث الملف — بيتنادى من الإعداد الأولي.
  Future<String?> upsert({
    required String displayName,
    required String username,
    required String countryCode,
    required String cityId,
    String? areaId,
    String? bio,
    String? avatarPath,
    double? lat,
    double? lng,
    String locale = 'ar',
  }) async {
    if (!hasBackend) return null;

    final id = _client.auth.currentUser?.id;
    if (id == null) return 'auth.err.generic';

    try {
      await _client.from('profiles').upsert({
        'id': id,
        'display_name': displayName.trim(),
        'username': username.trim().toLowerCase(),
        'country_code': countryCode,
        'city_id': cityId,
        if (areaId != null) 'area_id': areaId,
        if (bio != null && bio.isNotEmpty) 'bio': bio.trim(),
        if (avatarPath != null) 'avatar_path': avatarPath,
        // الإحداثيات دي **مزحزحة** قبل ما توصل هنا — شوف LocationJitter
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        'locale': locale,
      });
      return null;
    } on PostgrestException catch (error) {
      // 23505 = تعارض فريد، وأشهر سببه إن اسم المستخدم محجوز
      if (error.code == '23505') return 'auth.err.usernameTaken';
      return 'common.error';
    } catch (_) {
      return 'common.error';
    }
  }

  Future<bool> isUsernameAvailable(String username) async {
    if (!hasBackend) return true;
    final rows = await _client
        .from('profiles')
        .select('id')
        .eq('username', username.trim().toLowerCase())
        .limit(1);
    return rows.isEmpty;
  }

  Future<List<Review>> reviewsFor(String userId) async {
    if (!hasBackend) return Mock.reviews;

    final rows = await _client
        .from('reviews')
        .select('*, reviewer:profiles!reviews_reviewer_id_fkey(display_name)')
        .eq('reviewee_id', userId)
        .not('published_at', 'is', null)
        .order('published_at', ascending: false)
        .limit(50);

    return rows.map(Review.fromMap).toList();
  }

  /// جهة اتصال الطوارئ — بتتخزن لصاحبها فقط وسياسة الصفوف بتفرض ده.
  Future<String?> saveEmergencyContact({
    required String name,
    required String phone,
  }) async {
    if (!hasBackend) return null;
    final id = _client.auth.currentUser?.id;
    if (id == null) return 'auth.err.generic';

    try {
      await _client.from('emergency_contacts').upsert({
        'user_id': id,
        'name': name.trim(),
        'phone': phone.trim(),
      });
      return null;
    } catch (_) {
      return 'common.error';
    }
  }

  Future<bool> hasEmergencyContact() async {
    if (!hasBackend) return true;
    final id = _client.auth.currentUser?.id;
    if (id == null) return false;
    final rows = await _client
        .from('emergency_contacts')
        .select('user_id')
        .eq('user_id', id)
        .limit(1);
    return rows.isNotEmpty;
  }
}
