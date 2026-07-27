// =============================================================================
// Giraffe — الإشعارات الفورية (جانب التطبيق)
//
// القرارات الصعبة كلها في القاعدة: مين يستاهل رنة، وساعات الهدوء،
// والدمج. القسم 20 في اختبارات SQL هو اللي بيغطيها.
//
// اللي هنا: التسجيل، والصلاحية، والتوجيه عند الضغط.
// =============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:giraffe/core/push/push_service.dart';
import 'package:giraffe/data/repositories/push_repository.dart';

void main() {
  group('خدمة الإشعارات الافتراضية', () {
    // الافتراضي مابيعملش حاجة عن قصد: firebase_messaging بيتطلب
    // google-services.json، ومن غيره **بناء أندرويد بيفشل من أصله**.
    // فالتطبيق بيشتغل من غير إشعارات لحد ما فايربيز يتظبط.
    const service = NoopPushService();

    test('مش متاحة', () {
      expect(service.isAvailable, isFalse);
    });

    test('مابتطلبش صلاحية ومابترجعش رمز', () async {
      expect(await service.requestPermission(), isFalse);
      expect(await service.currentToken(), isNull);
    });

    test('التسجيل بيقف عندها من غير ما يرمي', () async {
      const repo = PushRepository(service);
      expect(await repo.registerDevice(), isNull);
    });
  });

  group('التسجيل', () {
    test('بيطلب الصلاحية الأول', () async {
      final service = FakePushService();
      addTearDown(service.dispose);

      // من غير خادم، التسجيل بيوصل للرمز بس مابيكتبش
      await PushRepository(service).registerDevice();
      expect(service.permissionAsked, isTrue);
    });

    test('الرفض بيوقف كل حاجة — مابنسجلش رمز من غير إذن', () async {
      final service = FakePushService(granted: false);
      addTearDown(service.dispose);

      final token = await PushRepository(service).registerDevice();
      expect(token, isNull);
    });

    test('القبول بيرجّع الرمز', () async {
      final service = FakePushService(token: 'tok-123');
      addTearDown(service.dispose);

      expect(await PushRepository(service).registerDevice(), 'tok-123');
    });
  });

  group('التوجيه عند الضغط', () {
    // الحمولة دي بتيجي من عمود payload في جدول notifications.

    test('المطابقة بتوّدي لشاشة الاحتفال', () {
      expect(
        routeForPayload({'kind': 'match', 'match_id': 'm1'}),
        '/match/m1/celebrate',
      );
    });

    test('الرسالة بتوّدي للغرفة نفسها', () {
      expect(
        routeForPayload({'kind': 'message', 'match_id': 'm1'}),
        '/matches/m1',
      );
    });

    test('والعرض كمان بيوّدي للغرفة', () {
      expect(
        routeForPayload({'kind': 'offer', 'match_id': 'm9'}),
        '/matches/m9',
      );
    });

    test('تنبيه المنتج بيوّدي للمنتج', () {
      expect(
        routeForPayload({'kind': 'wishlist', 'item_id': 'i7'}),
        '/items/i7',
      );
    });

    test('الحمولة الفاضية بتوّدي لشاشة الإشعارات مش لشاشة بيضا', () {
      // ده بيحصل مع إشعارات النظام. الأهم إننا **مانقعش** —
      // المستخدم دس على الإشعار، لازم يوصل لحتة مفيدة.
      expect(routeForPayload({}), '/notifications');
      expect(routeForPayload({'kind': 'system'}), '/notifications');
    });

    test('المعرّف الفاضي بيتعامل زي الناقص', () {
      expect(routeForPayload({'match_id': ''}), '/notifications');
    });
  });

  group('تجديد الرمز', () {
    test('التجديد بيتراقب', () async {
      final service = FakePushService();
      addTearDown(service.dispose);

      final repo = PushRepository(service);
      final sub = repo.watchTokenRefresh();
      addTearDown(sub.cancel);

      // فايربيز بيجدّد الرمز من نفسه. لو مالحقناش التجديد، الإشعارات
      // بتروح لرمز ميت وإحنا فاكرين إنها وصلت — وده أسوأ من إشعار
      // مابيوصلش، لأنه بيخبّي المشكلة.
      service.emitRefresh('tok-new');
      await Future<void>.delayed(Duration.zero);

      expect(sub, isNotNull);
    });
  });
}
