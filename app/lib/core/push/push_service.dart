import 'dart:async';

import 'package:flutter/foundation.dart';

/// خدمة الإشعارات الفورية.
///
/// -----------------------------------------------------------------------------
/// ليه في طبقة تجريد هنا؟
///
/// `firebase_messaging` بيتطلب مشروع فايربيز وملف `google-services.json`.
/// ومن غير الملف ده **بناء أندرويد بيفشل من أصله** — مش بيشتغل من غير
/// إشعارات، بيفشل التصريف نفسه.
///
/// فلو ربطنا المكتبة دلوقتي، كل واحد يستنسخ المشروع يلاقيه مش بيتبني
/// لحد ما يعمل حساب فايربيز. وده تمن غالي لميزة واحدة.
///
/// الطبقة دي بتخلي الباقي كله جاهز ومختبَر: تسجيل الرمز، والصلاحية،
/// والتوجيه عند الضغط. اللي ناقص هو **تنفيذ واحد** بيجيب الرمز من
/// فايربيز، والخطوات مكتوبة في `docs/13-push.md`.
/// -----------------------------------------------------------------------------
abstract class PushService {
  /// هل الخدمة متاحة أصلاً على الجهاز ده؟
  bool get isAvailable;

  /// طلب الصلاحية من المستخدم.
  ///
  /// بترجّع `true` لو المستخدم وافق.
  Future<bool> requestPermission();

  /// رمز الجهاز الحالي، أو `null` لو مفيش.
  Future<String?> currentToken();

  /// بيرن مع كل تجديد للرمز.
  ///
  /// فايربيز بيجدّد الرمز من نفسه، ولو مالحقناش التجديد الإشعارات
  /// بتروح لرمز ميت وإحنا فاكرين إنها وصلت.
  Stream<String> get onTokenRefresh;

  /// الضغط على الإشعار — بيرجّع الحمولة للتوجيه.
  Stream<Map<String, dynamic>> get onOpened;
}

/// التنفيذ الافتراضي — **مابيعملش حاجة**.
///
/// ده المستعمل دلوقتي. التطبيق بيشتغل عادي، والإشعارات بتفضل تتجمّع
/// في التطبيق نفسه (شاشة الإشعارات) من غير رنّات.
class NoopPushService implements PushService {
  const NoopPushService();

  @override
  bool get isAvailable => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<String?> currentToken() async => null;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get onOpened => const Stream.empty();
}

/// تنفيذ تجريبي للاختبارات والتشغيل من غير خادم.
@visibleForTesting
class FakePushService implements PushService {
  FakePushService({this.granted = true, this.token = 'fake-token-1'});

  final bool granted;
  final String token;

  final _refresh = StreamController<String>.broadcast();
  final _opened = StreamController<Map<String, dynamic>>.broadcast();

  bool permissionAsked = false;

  @override
  bool get isAvailable => true;

  @override
  Future<bool> requestPermission() async {
    permissionAsked = true;
    return granted;
  }

  @override
  Future<String?> currentToken() async => granted ? token : null;

  @override
  Stream<String> get onTokenRefresh => _refresh.stream;

  @override
  Stream<Map<String, dynamic>> get onOpened => _opened.stream;

  void emitRefresh(String next) => _refresh.add(next);
  void emitOpened(Map<String, dynamic> payload) => _opened.add(payload);

  void dispose() {
    _refresh.close();
    _opened.close();
  }
}
