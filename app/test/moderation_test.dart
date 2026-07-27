// =============================================================================
// Giraffe — لوحة المراجعة البشرية
//
// الاختبارات دي بتغطي **الواجهة** بس. الصلاحية والقرار بيتفحصوا في
// القاعدة، والقسم 19 في اختبارات SQL هو اللي بيغطيهم — وهو اللي بيثبت
// إن المستخدم العادي مايقدرش يقرر، وإن المراجع مايراجعش منتجه.
//
// إخفاء اللوحة في التطبيق **تحسين عرض مش حماية**.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:giraffe/core/l10n/strings.dart';
import 'package:giraffe/data/repositories/moderation_repository.dart';
import 'package:giraffe/features/moderation/moderation_queue_screen.dart';

Future<void> pumpQueue(WidgetTester tester, {double textScale = 1.0}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(
    const ProviderScope(
      child: MaterialApp(
        locale: Locale('ar'),
        supportedLocales: S.supported,
        // نفس المندوبين اللي في app.dart — من غير المندوبين العامين،
        // AppBar و RefreshIndicator بيرموا استثناء.
        localizationsDelegates: [
          GLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: ModerationQueueScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

void main() {
  group('طابور المراجعة', () {
    testWidgets('بيرسم من غير استثناءات', (tester) async {
      await pumpQueue(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('بيعرض الحالات المستنية', (tester) async {
      await pumpQueue(tester);
      expect(find.text('ساعة سويسرية أصلية'), findsOneWidget);
      expect(find.text('لابتوب ديل للبيع أو البدل'), findsOneWidget);
    });

    testWidgets('سبب التعليم بيظهر للمراجع', (tester) async {
      // ده السبب اللي **بنخبّيه عن صاحب المنتج** عشان مايتحايلش —
      // بس المراجع لازم يشوفه عشان يحكم.
      await pumpQueue(tester);
      expect(find.textContaining('ادعاء أصالة غير مؤكد'), findsOneWidget);
    });

    testWidgets('التبديل لطابور أعطال النظام بيفصلهم', (tester) async {
      await pumpQueue(tester);

      // قبل التبديل: حالات المحتوى
      expect(find.text('ساعة سويسرية أصلية'), findsOneWidget);

      await tester.tap(find.textContaining('تعثّر النظام'));
      await tester.pumpAndSettle();

      // بعده: حالات النظام بس، ومعاها زر إعادة المحاولة
      expect(find.text('ساعة سويسرية أصلية'), findsNothing);
      expect(find.text('دراجة هوائية كوبرا'), findsOneWidget);
      expect(find.textContaining('رجّع'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('المُبلَّغ عنه بيتعلّم', (tester) async {
      await pumpQueue(tester);
      // الساعة عليها بلاغين
      expect(find.text('2'), findsWidgets);
    });

    testWidgets('بيرسم عند تكبير الخط 1.35', (tester) async {
      // نفس درس كارت السوق: أي ارتفاع ثابت جوه نص بيطفح للمستخدم
      // اللي مكبّر الخط.
      await pumpQueue(tester, textScale: 1.35);
      expect(tester.takeException(), isNull);
    });
  });

  group('تصنيف سبب التعليم', () {
    // نفس منطق public.flag_kind في القاعدة.
    test('الملاحظات دي مالهاش لازمة بشرية', () {
      const entry = QueueEntry(
        itemId: 'x',
        title: 't',
        description: null,
        categoryId: 'mobiles',
        ownerId: 'o',
        ownerName: 'n',
        ownerUsername: 'u',
        ownerTrust: 'new',
        ownerTrades: 0,
        photoCount: 0,
        flagKind: FlagKind.system,
        flagNote: 'moderation_unavailable',
        waitingMinutes: 10,
        openReports: 0,
      );
      expect(entry.flagKind, FlagKind.system);
      expect(entry.isUrgent, isFalse);
    });

    test('البلاغ بيخلي الحالة عاجلة مهما كانت جديدة', () {
      const entry = QueueEntry(
        itemId: 'x',
        title: 't',
        description: null,
        categoryId: 'mobiles',
        ownerId: 'o',
        ownerName: 'n',
        ownerUsername: 'u',
        ownerTrust: 'new',
        ownerTrades: 0,
        photoCount: 0,
        flagKind: FlagKind.content,
        flagNote: 'شك',
        waitingMinutes: 1,
        openReports: 1,
      );
      expect(entry.isUrgent, isTrue);
    });

    test('والانتظار الطويل كمان بيخليها عاجلة', () {
      const entry = QueueEntry(
        itemId: 'x',
        title: 't',
        description: null,
        categoryId: 'mobiles',
        ownerId: 'o',
        ownerName: 'n',
        ownerUsername: 'u',
        ownerTrust: 'new',
        ownerTrades: 0,
        photoCount: 0,
        flagKind: FlagKind.content,
        flagNote: 'شك',
        waitingMinutes: 60 * 25,
        openReports: 0,
      );
      expect(entry.isUrgent, isTrue);
    });
  });
}
