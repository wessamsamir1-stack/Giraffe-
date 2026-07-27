import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../env.dart';

/// تهيئة سوبابيز.
///
/// بترجع `true` لو الخادم اشتغل، و`false` لو مفيش إعدادات أو حصل خطأ —
/// وفي الحالتين التطبيق بيكمل شغل: من غير خادم بيقع على البيانات
/// التجريبية بدل ما يقف.
class SupabaseInit {
  const SupabaseInit._();

  static bool _ready = false;

  static bool get isReady => _ready;

  static Future<bool> ensureInitialized() async {
    if (_ready) return true;
    if (!Env.hasBackend) {
      debugPrint('Giraffe: مفيش إعدادات سوبابيز — التشغيل على بيانات تجريبية');
      return false;
    }

    try {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        anonKey: Env.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
      _ready = true;
      return true;
    } catch (error, stack) {
      debugPrint('Giraffe: فشل الاتصال بسوبابيز — $error');
      debugPrintStack(stackTrace: stack);
      return false;
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
}
