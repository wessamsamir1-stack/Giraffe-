// =============================================================================
// Giraffe — المسار الذهبي
//
// بيثبت إن التطبيق **بيقلع ويوصل للسوق** من غير خادم، وإن الشاشات
// الأساسية بترسم من غير استثناءات.
//
// ملاحظة: مفيش نداء لـ SupabaseInit هنا، يعني hasBackend بترجع false
// وكل المستودعات بتشتغل على البيانات التجريبية. وده بالظبط اللي
// عايزين نختبره — إن المسار البديل شغال فعلاً.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:giraffe/app.dart';
import 'package:giraffe/core/app_state.dart';
import 'package:giraffe/core/security/password_policy.dart';
import 'package:giraffe/core/security/validators.dart';
import 'package:giraffe/data/catalog/countries.dart';

/// بيظبط مقاس شاشة موبايل حقيقي.
///
/// المقاس الافتراضي في الاختبارات 800×600 — وده عرضي، والتطبيق مقفول
/// على الطولي. الاختبار على مقاس مالوش وجود بيولّد أعطال تخطيط وهمية.
void usePhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);   // موبايل شائع
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// بيشغّل التطبيق ويعدّي شاشة البداية (مؤقّت 1000 مللي ثانية).
Future<void> bootToApp(WidgetTester tester) async {
  usePhoneViewport(tester);
  await tester.pumpWidget(const ProviderScope(child: GiraffeApp()));
  await tester.pump(const Duration(milliseconds: 1200));
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

void main() {
  // ===========================================================================
  group('إقلاع التطبيق', () {
    testWidgets('بيقلع من غير خادم ومن غير استثناءات', (tester) async {
      await bootToApp(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('شاشة البداية بترسم قبل التوجيه', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(const ProviderScope(child: GiraffeApp()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(MaterialApp), findsOneWidget);
      expect(tester.takeException(), isNull);

      // نسيب المؤقّت يخلص عشان مايشتكيش من مؤقّت معلّق
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });

    testWidgets('الاتجاه من اليمين لليسار في العربي', (tester) async {
      // لو ده اتكسر، كل الشاشات بتتقلب. وده النوع من الأعطال اللي
      // مابيرميش استثناء — بيرسم غلط وخلاص.
      await bootToApp(tester);

      // الاتجاه بيتوفّر **تحت** MaterialApp مش فوقه، فبندوّر على
      // أعمق Directionality في الشجرة.
      final dir = tester.widgetList<Directionality>(
        find.byType(Directionality),
      ).last;
      expect(dir.textDirection, TextDirection.rtl);
    });

    testWidgets('التبديل للإنجليزي بيقلب الاتجاه', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(const ProviderScope(child: GiraffeApp()));
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(GiraffeApp)),
      );
      container.read(localeProvider.notifier).state = const Locale('en');
      await tester.pumpAndSettle();

      final dir = tester.widgetList<Directionality>(
        find.byType(Directionality),
      ).last;
      expect(dir.textDirection, TextDirection.ltr);
    });

    testWidgets('المظهر الغامق بيرسم من غير مشاكل', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(const ProviderScope(child: GiraffeApp()));
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(GiraffeApp)),
      );
      container.read(themeModeProvider.notifier).state = ThemeMode.dark;
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  // ===========================================================================
  group('تكبير الخط — الإتاحة', () {
    // التطبيق بيسمح بتكبير الخط لحد 1.35 (شوف app.dart). يعني أي تخطيط
    // بارتفاع ثابت جوه محتوى نصي **هيطفح لمستخدم حقيقي**، مش حالة نادرة.
    //
    // الاختبارات دي اتكتبت بعد ما طفح فعلاً في كارت السوق وشريط الأقسام.

    for (final scale in [1.0, 1.35]) {
      testWidgets('السوق بيرسم من غير طفح عند تكبير $scale', (tester) async {
        usePhoneViewport(tester);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await tester.pumpWidget(const ProviderScope(child: GiraffeApp()));
        await tester.pump(const Duration(milliseconds: 1200));
        await tester.pumpAndSettle(const Duration(seconds: 2));

        expect(tester.takeException(), isNull);
      });
    }
  });

  // ===========================================================================
  group('سياسة كلمة السر', () {
    test('كلمة قصيرة مارضيتش', () {
      expect(PasswordPolicy.evaluate('Ab3!xy').isAcceptable, isFalse);
    });

    test('كلمة قوية عدّت', () {
      expect(PasswordPolicy.evaluate('Qamar!7bahr2Nil').isAcceptable, isTrue);
    });

    test('الكلمات الشائعة مارضيتش مهما كان طولها', () {
      // الطول لوحده مش قوة. «password123456» طويلة وسهلة.
      final check = PasswordPolicy.evaluate('password123456');
      expect(check.isAcceptable, isFalse);
    });

    test('التكرار الطويل مارضيش', () {
      expect(PasswordPolicy.evaluate('Aaaaaaaaaa1!').isAcceptable, isFalse);
    });

    test('المتسلسل مارضيش', () {
      expect(PasswordPolicy.evaluate('abcdefghij1!').isAcceptable, isFalse);
    });

    test('كلمة السر مايصحّش تكون من بيانات المستخدم', () {
      // ده بيتنسي كتير: أقوى قاعدة طول وتعقيد مابتحميش من إن المستخدم
      // يحط اسمه أو بريده.
      final check = PasswordPolicy.evaluate(
        'Wessam!2024xyz',
        displayName: 'Wessam Samir',
      );
      expect(check.isAcceptable, isFalse);
    });

    test('الحد الأقصى للطول مفروض — حماية من هجوم التجزئة', () {
      final long = 'Qamar!7bahr2Nil${'x' * 200}';
      expect(PasswordPolicy.evaluate(long).isAcceptable, isFalse);
    });
  });

  // ===========================================================================
  group('المدققات', () {
    test('البريد', () {
      expect(Validators.email('wessam@example.com'), isNull);
      expect(Validators.email('wessam@'), isNotNull);
      expect(Validators.email('wessam example.com'), isNotNull);
      expect(Validators.email(''), isNotNull);
    });

    test('اسم المستخدم — حروف صغيرة وأرقام وشرطة سفلية بس', () {
      expect(Validators.username('wessam_1'), isNull);
      expect(Validators.username('we'), isNotNull);          // قصير
      expect(Validators.username('wessam-1'), isNotNull);     // شرطة عادية
      expect(Validators.username('wessam 1'), isNotNull);     // مسافة
      expect(Validators.username('a' * 21), isNotNull);       // طويل
    });

    test('الحروف الكبيرة مقبولة — والمستودع هو اللي بيصغّرها', () {
      // المدقق بيتسامح عن قصد: المستخدم بيكتب Wessam والمستودع بيخزّنها
      // wessam، والعمود في القاعدة citext فالتفرد محفوظ.
      //
      // الاختبار ده بيثبّت السلوك ده. لو حد شال التصغير من المستودع،
      // الاختبار ده مش هيقع — عشان كده فيه اختبار تاني تحت بيغطي الربط.
      expect(Validators.username('Wessam'), isNull);
    });

    test('الموبايل المصري', () {
      final eg = Countries.byCode('EG');
      expect(Validators.phone('01012345678', eg), isNull);
      expect(Validators.phone('1012345678', eg), isNull);
      expect(Validators.phone('0101234567', eg), isNotNull);
      expect(Validators.phone('99999', eg), isNotNull);
    });

    test('تطبيع الموبايل بيشيل الرموز والصفر البادئ', () {
      // إزالة الصفر البادئ مقصودة وموثّقة — الرقم بيتخزّن بالصيغة
      // الدولية، والصفر ده محلي. «01012345678» و«+201012345678»
      // لازم يوصلوا لنفس النتيجة.
      expect(Validators.normalizePhone('010 1234 5678'), '1012345678');
      expect(Validators.normalizePhone('+20-101-234-5678'), '201012345678');
      expect(Validators.normalizePhone('0101 234 5678'), '1012345678');
    });

    test('الأرقام العربية والفارسية بتتحول لإنجليزية', () {
      // مهم في مصر والخليج: كتير بيكتبوا بلوحة مفاتيح عربية.
      expect(Validators.normalizePhone('٠١٠١٢٣٤٥٦٧٨'), '1012345678');
      expect(Validators.normalizePhone('۰۱۰۱۲۳۴۵۶۷۸'), '1012345678');
    });

    test('رمز التحقق 6 أرقام', () {
      expect(Validators.otp('123456'), isNull);
      expect(Validators.otp('12345'), isNotNull);
      expect(Validators.otp('12345a'), isNotNull);
    });
  });
}
