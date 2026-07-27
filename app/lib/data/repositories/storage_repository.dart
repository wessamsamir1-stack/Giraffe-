import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_init.dart';

/// تخزين الصور.
///
/// دلاء التخزين:
///   `avatars`     — صور الملف الشخصي (عامة القراءة)
///   `item-photos` — صور المنتجات (عامة القراءة)
///   `evidence`    — مرفقات البلاغات والنزاعات (**خاصة تماماً**)
///
/// مسار الملف دايماً بيبدأ برقم المستخدم، وسياسات التخزين بتفرض إن
/// المستخدم مايكتبش إلا في مجلده هو.
class StorageRepository {
  const StorageRepository();

  static const String avatars = 'avatars';
  static const String itemPhotos = 'item-photos';
  static const String evidence = 'evidence';

  bool get hasBackend => SupabaseInit.isReady;
  SupabaseClient get _client => SupabaseInit.client;

  String? get _me => _client.auth.currentUser?.id;

  /// بترجع مسار التخزين، أو `null` لو فشل الرفع.
  Future<String?> uploadItemPhoto({
    required String itemId,
    required int position,
    required Uint8List bytes,
    String extension = 'jpg',
  }) async {
    if (!hasBackend) return 'mock/$itemId/$position.$extension';

    final me = _me;
    if (me == null) return null;

    final path = '$me/$itemId/$position.$extension';
    try {
      await _client.storage.from(itemPhotos).uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      return path;
    } catch (_) {
      return null;
    }
  }

  Future<String?> uploadAvatar(Uint8List bytes, {String extension = 'jpg'}) async {
    if (!hasBackend) return 'mock/avatar.$extension';

    final me = _me;
    if (me == null) return null;

    final path = '$me/avatar.$extension';
    try {
      await _client.storage.from(avatars).uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      return path;
    } catch (_) {
      return null;
    }
  }

  /// رابط عرض عام. بيرجع `null` لو مفيش مسار — والواجهة بتعرض البديل الملوّن.
  String? publicUrl(String bucket, String? path) {
    if (path == null || path.isEmpty) return null;
    if (!hasBackend) return null;
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  String? itemPhotoUrl(String? path) => publicUrl(itemPhotos, path);

  String? avatarUrl(String? path) => publicUrl(avatars, path);

  /// مرفقات البلاغات خاصة، فبتتعرض برابط موقّع قصير المدى.
  Future<String?> signedEvidenceUrl(String path, {int seconds = 300}) async {
    if (!hasBackend) return null;
    try {
      return await _client.storage.from(evidence).createSignedUrl(path, seconds);
    } catch (_) {
      return null;
    }
  }
}
