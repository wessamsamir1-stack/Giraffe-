// =============================================================================
// Giraffe — تنسيق الأسعار
//
// نطاق السعر هو أكتر سطر بيتشاف في التطبيق — على كل كارت. وكان بيطلع
// «ج.م – 44000 ج.م 38000»: العملة مكررة، والاتجاه ملخبط، ومفيش فواصل.
// الاختبارات دي بتمسك الشكل الصح عشان مايرجعش.
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:giraffe/data/catalog/countries.dart';

void main() {
  const egp = Currency(code: 'EGP', symbolAr: 'ج.م', symbolEn: 'EGP', decimals: 2);

  // علامات العزل غير مرئية — بنشيلها عشان نقارن اللي العين بتشوفه.
  String visible(String s) => s.replaceAll(RegExp('[\u2066-\u2069]'), '');

  group('فواصل الآلاف', () {
    test('أرقام صغيرة من غير فواصل', () {
      expect(Currency.grouped(0), '0');
      expect(Currency.grouped(950), '950');
    });

    test('آلاف وملايين', () {
      expect(Currency.grouped(38000), '38,000');
      expect(Currency.grouped(1250000), '1,250,000');
    });

    test('الكسور بتتقرّب', () {
      expect(Currency.grouped(38000.6), '38,001');
    });

    test('السالب', () {
      expect(Currency.grouped(-4500), '-4,500');
    });
  });

  group('النطاق', () {
    test('العملة مرة واحدة في الآخر', () {
      final s = visible(egp.formatRange(38000, 44000, ar: true));
      expect(s, '38,000 – 44,000 ج.م');
      expect('ج.م'.allMatches(s).length, 1);
    });

    test('الإنجليزي', () {
      expect(visible(egp.formatRange(38000, 44000, ar: false)), '38,000 – 44,000 EGP');
    });

    test('الأرقام معزولة LTR عشان الأقل يفضل قبل الأكثر جوّه جملة عربي', () {
      final s = egp.formatRange(38000, 44000, ar: true);
      expect(s.startsWith('\u2066'), isTrue);
      expect(s.indexOf('\u2069'), greaterThan(s.indexOf('44,000')));
    });
  });
}
