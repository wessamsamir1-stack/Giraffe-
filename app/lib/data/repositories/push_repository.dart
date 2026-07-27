import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/push/push_service.dart';
import '../../core/supabase/supabase_init.dart';

/// ربط الجهاز بالخادم عشان يستقبل الإشعارات.
///
/// المسؤولية هنا **التسجيل بس**. القرار إن الإشعار يتبعت ولا لأ،
/// وساعات الهدوء، والدمج — كل ده في القاعدة، مش هنا.
class PushRepository {
  const PushRepository(this._push);

  final PushService _push;

  bool get hasBackend => SupabaseInit.isReady;
  SupabaseClient get _client => SupabaseInit.client;

  String get _platform {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    return 'android';
  }

  /// بيتنادى بعد تسجيل الدخول وكل مرة التطبيق بيفتح.
  ///
  /// بيرجّع الرمز اللي اتسجّل، أو `null` لو مفيش.
  Future<String?> registerDevice() async {
    if (!_push.isAvailable) return null;

    final granted = await _push.requestPermission();
    if (!granted) return null;

    final token = await _push.currentToken();
    if (token == null || token.isEmpty) return null;

    await _save(token);
    return token;
  }

  /// متابعة تجديد الرمز.
  ///
  /// فايربيز بيجدّد الرمز من نفسه. لو مالحقناش التجديد، الإشعارات
  /// بتروح لرمز ميت وإحنا فاكرين إنها وصلت — وده أسوأ من إشعار
  /// مابيوصلش أصلاً، لأنه بيخفي المشكلة.
  StreamSubscription<String> watchTokenRefresh() {
    return _push.onTokenRefresh.listen(_save);
  }

  /// لغة الجهاز.
  ///
  /// اللغة خاصية **الجهاز** مش المستخدم: ممكن يكون عنده موبايل بالعربي
  /// وتابلت بالإنجليزي، والرنة لازم توصل بلغة الجهاز اللي هتظهر عليه.
  String get _deviceLang {
    final locales = WidgetsBinding.instance.platformDispatcher.locales;
    if (locales.isEmpty) return 'ar';
    return locales.first.languageCode.toLowerCase().startsWith('en')
        ? 'en'
        : 'ar';
  }

  Future<void> _save(String token) async {
    if (!hasBackend) return;
    try {
      await _client.rpc('register_push_token', params: {
        'p_token': token,
        'p_platform': _platform,
        'p_lang': _deviceLang,
      },);
    } catch (_) {
      // فشل التسجيل مش خطأ للمستخدم — بيتعاد أول ما التطبيق يفتح تاني
    }
  }

  /// عند تسجيل الخروج.
  ///
  /// **مهم:** من غير ده، إشعارات الحساب القديم بتفضل توصل للجهاز بعد
  /// ما صاحبه خرج — وممكن يشوفها حد تاني.
  Future<void> unregisterDevice() async {
    if (!hasBackend || !_push.isAvailable) return;

    final token = await _push.currentToken();
    if (token == null) return;

    try {
      await _client.rpc('unregister_push_token', params: {'p_token': token});
    } catch (_) {
      // مش قادرين نعمل حاجة — بس الخادم بيمسح الرموز الخاملة بعد 6 شهور
    }
  }

  /// الضغط على الإشعار.
  Stream<Map<String, dynamic>> get onOpened => _push.onOpened;
}

/// المسار اللي الإشعار بيوّدي له.
///
/// بيتحسب من الحمولة اللي القاعدة بتحطها في `payload`.
String? routeForPayload(Map<String, dynamic> payload) {
  final matchId = payload['match_id'] as String?;
  final itemId = payload['item_id'] as String?;

  if (matchId != null && matchId.isNotEmpty) {
    // المطابقة الجديدة بتوّدي لشاشة الاحتفال، والباقي للغرفة
    return payload['kind'] == 'match'
        ? '/match/$matchId/celebrate'
        : '/matches/$matchId';
  }

  if (itemId != null && itemId.isNotEmpty) return '/items/$itemId';

  return '/notifications';
}
