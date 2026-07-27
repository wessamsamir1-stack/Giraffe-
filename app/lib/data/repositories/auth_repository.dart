import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_init.dart';

/// نتيجة عملية حساب.
///
/// بنرجع نتيجة صريحة بدل ما نرمي استثناءات للواجهة، عشان كل شاشة
/// تقدر تعرض رسالة مفهومة بدل ما تنهار.
class AuthResult {
  const AuthResult.ok() : error = null;
  const AuthResult.failed(this.error);

  final String? error;

  bool get isOk => error == null;
}

/// طبقة الحساب.
///
/// **قاعدة أمنية مطبقة هنا:** رسالة الخطأ عند فشل الدخول واحدة دايماً
/// (`auth.err.generic`) سواء البريد غلط أو كلمة السر غلط — عشان مانسمحش
/// بتعداد الحسابات.
///
/// الرسائل التفصيلية اللي بيرجّعها سوبابيز مابتوصلش للمستخدم أبداً.
class AuthRepository {
  const AuthRepository();

  bool get hasBackend => SupabaseInit.isReady;

  SupabaseClient get _client => SupabaseInit.client;

  String? get currentUserId =>
      hasBackend ? _client.auth.currentUser?.id : 'u_me';

  bool get isSignedIn => currentUserId != null;

  String? get currentEmail =>
      hasBackend ? _client.auth.currentUser?.email : 'demo@giraffe.app';

  Stream<AuthState>? get onAuthStateChange =>
      hasBackend ? _client.auth.onAuthStateChange : null;

  // ---------------------------------------------------------------------------
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    if (!hasBackend) return const AuthResult.ok();

    try {
      await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'display_name': displayName.trim()},
      );
      return const AuthResult.ok();
    } on AuthException catch (error) {
      // البريد المسجّل بالفعل مابنكشفوش — سوبابيز بيبعت تنبيه للمالك
      if (error.message.toLowerCase().contains('already registered')) {
        return const AuthResult.ok();
      }
      return const AuthResult.failed('auth.err.generic');
    } catch (_) {
      return const AuthResult.failed('common.error');
    }
  }

  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    if (!hasBackend) return const AuthResult.ok();

    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return const AuthResult.ok();
    } on AuthException {
      // رسالة موحّدة — ممنوع نكشف إذا كان الحساب موجود
      return const AuthResult.failed('auth.err.generic');
    } catch (_) {
      return const AuthResult.failed('common.error');
    }
  }

  /// إرسال رابط استعادة كلمة السر.
  ///
  /// بترجع نجاح **دايماً** حتى لو البريد مش مسجّل — نفس قاعدة منع التعداد.
  Future<AuthResult> requestPasswordReset(String email) async {
    if (!hasBackend) return const AuthResult.ok();
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
    } catch (_) {
      // بنبلع الخطأ عن قصد
    }
    return const AuthResult.ok();
  }

  Future<AuthResult> verifyOtp({
    required String token,
    required String target,
    required bool isEmail,
  }) async {
    if (!hasBackend) return const AuthResult.ok();

    try {
      await _client.auth.verifyOTP(
        type: isEmail ? OtpType.email : OtpType.sms,
        token: token,
        email: isEmail ? target : null,
        phone: isEmail ? null : target,
      );
      return const AuthResult.ok();
    } on AuthException {
      return const AuthResult.failed('auth.err.generic');
    } catch (_) {
      return const AuthResult.failed('common.error');
    }
  }

  Future<AuthResult> sendPhoneOtp(String phone) async {
    if (!hasBackend) return const AuthResult.ok();
    try {
      await _client.auth.signInWithOtp(phone: phone);
      return const AuthResult.ok();
    } catch (_) {
      return const AuthResult.failed('common.error');
    }
  }

  Future<void> signOut() async {
    if (!hasBackend) return;
    await _client.auth.signOut();
  }

  /// حذف الحساب — شرط إجباري لقبول التطبيق على متجر آبل.
  ///
  /// الحذف الفعلي بيتم في Edge Function بصلاحيات الخدمة، لأن العميل
  /// مايقدرش (ولا المفروض يقدر) يحذف من `auth.users`.
  Future<AuthResult> requestAccountDeletion() async {
    if (!hasBackend) return const AuthResult.ok();
    try {
      await _client
          .from('profiles')
          .update({'deletion_requested_at': DateTime.now().toIso8601String()})
          .eq('id', currentUserId!);
      return const AuthResult.ok();
    } catch (_) {
      return const AuthResult.failed('common.error');
    }
  }
}
