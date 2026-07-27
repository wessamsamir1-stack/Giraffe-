// =============================================================================
// Giraffe — صيغة كود الإتمام في الـ QR
//
// الدالة دي هي اللي بتفرّق بين «كود غلط» و«كود صفقة تانية». الفرق
// مهم للمستخدم: الأولى معناها حصل غلط، والتانية معناها إنتوا في
// غرفتين مختلفتين — وده اللي بيحصل فعلاً لما يكون عند الواحد أكتر
// من صفقة مفتوحة.
//
// ملاحظة: **مفيش تحقق أمني هنا.** التحقق كله في الخادم — القسم 18
// في اختبارات SQL. اللي هنا بيحسّن الرسالة بس.
// =============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:giraffe/features/matches/trade_code.dart';

void main() {
  const room = 'aaaaaaaa-0000-0000-0000-000000000001';
  const other = 'bbbbbbbb-0000-0000-0000-000000000002';

  group('البناء والقراءة', () {
    test('الكود بيتبني ويترجع زي ما هو', () {
      final payload = encodeTradeCode(matchId: room, code: 'UGT4TNAY');
      final result = parseTradeCode(payload, expectedMatchId: room);

      expect(result, isA<ScanOk>());
      expect((result as ScanOk).code, 'UGT4TNAY');
    });

    test('الصيغة فيها البادئة ورقم الغرفة والكود', () {
      expect(
        encodeTradeCode(matchId: room, code: 'ABCD2345'),
        'GRF1:$room:ABCD2345',
      );
    });
  });

  group('كود صفقة تانية', () {
    test('بيتقرا كغرفة غلط مش كود غلط', () {
      // ده الفرق اللي الاختبار ده موجود عشانه. لو رجّعنا «كود غلط»
      // المستخدم هيفضل يجرب ويحرق سقف المحاولات على حاجة صح أصلاً.
      final payload = encodeTradeCode(matchId: other, code: 'UGT4TNAY');
      expect(
        parseTradeCode(payload, expectedMatchId: room),
        isA<ScanWrongRoom>(),
      );
    });
  });

  group('حاجات مش بتاعتنا', () {
    test('باركود منتج عادي', () {
      expect(parseTradeCode('6221031492015', expectedMatchId: room),
          isA<ScanNotOurs>(),);
    });

    test('رابط', () {
      expect(parseTradeCode('https://example.com/x', expectedMatchId: room),
          isA<ScanNotOurs>(),);
    });

    test('نص فاضي', () {
      expect(parseTradeCode('', expectedMatchId: room), isA<ScanNotOurs>());
    });

    test('الكود لوحده من غير الصيغة', () {
      // الشكل القديم. مابنقبلوش عشان مانعرفش هو لأنهي غرفة.
      expect(parseTradeCode('UGT4TNAY', expectedMatchId: room),
          isA<ScanNotOurs>(),);
    });

    test('كود أقصر من اللازم', () {
      expect(parseTradeCode('GRF1:$room:AB', expectedMatchId: room),
          isA<ScanNotOurs>(),);
    });
  });

  group('إصدار أحدث', () {
    test('بيقول للمستخدم يحدّث بدل ما يفشل بصمت', () {
      // رقم الإصدار موجود من دلوقتي عشان لو غيّرنا الصيغة، النسخة
      // القديمة تعرف تقول السبب بدل ما تقول «مش كود بتاعنا».
      expect(
        parseTradeCode('GRF2:$room:UGT4TNAY', expectedMatchId: room),
        isA<ScanNeedsUpdate>(),
      );
    });
  });

  group('التسامح في القراءة', () {
    test('المسافات على الأطراف بتتشال', () {
      final result = parseTradeCode(
        '  ${encodeTradeCode(matchId: room, code: 'UGT4TNAY')}  ',
        expectedMatchId: room,
      );
      expect(result, isA<ScanOk>());
    });

    test('الحروف الصغيرة بتتحول لكبيرة', () {
      final result =
          parseTradeCode('GRF1:$room:ugt4tnay', expectedMatchId: room);
      expect((result as ScanOk).code, 'UGT4TNAY');
    });

    test('البادئة الصغيرة كمان', () {
      expect(
        parseTradeCode('grf1:$room:UGT4TNAY', expectedMatchId: room),
        isA<ScanOk>(),
      );
    });
  });
}
