// =============================================================================
// Giraffe — اختبارات الثوابت
//
// الاختبارات دي مش بتغطي كل حاجة. دي بتغطي **اللي بيفشل في صمت**.
//
// الفرق مهم: لو زر مابيشتغلش، أول مستخدم هيبلّغ. لكن لو دالة تطبيع النص
// في الدارت اختلفت عن اللي في القاعدة، البحث هيرجّع نتايج غلط لشهور
// ومحدش هيربط السبب بالنتيجة.
// =============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:giraffe/data/catalog/countries.dart';
import 'package:giraffe/data/models/models.dart';
import 'package:giraffe/data/repositories/items_repository.dart';

void main() {
  // ===========================================================================
  group('تطبيع النص العربي — لازم يطابق public.normalize_ar', () {
    // الحالات دي **منقولة حرفياً** من القسم 2 في supabase/tests/10_smoke.sql
    // عن قصد. لو حالة اتغيرت هناك، لازم تتغير هنا — والعكس.
    //
    // الدالة مكتوبة تلات مرات: بوستجرس، دارت، تايبسكريبت. تلاتتهم لازم
    // يوافقوا، وإلا المستخدم يكتب «آيفون» ومايلاقيش «ايفون».

    String norm(String s) => ItemsRepository.normalizeAr(s);

    test('الهمزات كلها بترجع ألف', () {
      expect(norm('آيفون'), 'ايفون');
      expect(norm('إيفون'), 'ايفون');
      expect(norm('أيفون'), 'ايفون');
      expect(norm('ٱيفون'), 'ايفون');
    });

    test('التطويل والتاء المربوطة', () {
      expect(norm('شنطـــة'), 'شنطه');
    });

    test('إزالة التشكيل', () {
      expect(norm('كامِيرَا'), 'كاميرا');
    });

    test('الألف المقصورة والياء الهمزية', () {
      expect(norm('مصطفى'), 'مصطفي');
      expect(norm('رئيس'), 'رييس');
    });

    test('الواو الهمزية', () {
      expect(norm('مؤتمر'), 'موتمر');
    });

    test('المسافات بتتوحّد والأطراف بتتشال', () {
      expect(norm('  ايفون    برو  '), 'ايفون برو');
    });

    test('التطبيع ثابت — تطبيق المطبَّع مرة تانية مايغيرش حاجة', () {
      // خاصية مهمة: القاعدة بتخزّن العمود المطبَّع، والتطبيق بيطبّع كلمة
      // البحث. لو الدالة مش ثابتة، الاتنين مايتطابقوش.
      const samples = ['آيفون 15 برو', 'شنطـــة جلد', 'كامِيرَا كانون', 'مصطفى'];
      for (final s in samples) {
        expect(norm(norm(s)), norm(s), reason: s);
      }
    });
  });

  // ===========================================================================
  group('تحويل التعدادات للقاعدة — EnumWire', () {
    // camelCase في الدارت ← snake_case في بوستجرس.
    //
    // ده بيتستعمل في **كل** كتابة للقاعدة. لو التحويل غلط، بوستجرس
    // بيرفض القيمة ككل — أو أسوأ، بيقبل قيمة تانية صحيحة نحوياً.

    test('الحالات المركّبة بتتحول صح', () {
      expect(ItemCondition.brandNew.wire, 'brand_new');
      expect(ItemCondition.likeNew.wire, 'like_new');
      expect(ItemCondition.forParts.wire, 'for_parts');
    });

    test('الحالات المفردة مابتتغيرش', () {
      expect(ItemCondition.good.wire, 'good');
      expect(ItemCondition.fair.wire, 'fair');
    });

    test('حالات المنتج', () {
      expect(ItemStatus.available.wire, 'available');
      expect(ItemStatus.pending.wire, 'pending');
      expect(ItemStatus.rejected.wire, 'rejected');
      expect(ItemStatus.draft.wire, 'draft');
    });

    test('كل قيم ItemCondition بترجع snake_case صالح', () {
      // مفيش حروف كبيرة ومفيش شرطة في البداية أو النهاية
      for (final c in ItemCondition.values) {
        expect(c.wire, matches(r'^[a-z]+(_[a-z]+)*$'), reason: c.name);
      }
    });

    test('كل قيم ItemStatus بترجع snake_case صالح', () {
      for (final s in ItemStatus.values) {
        expect(s.wire, matches(r'^[a-z]+(_[a-z]+)*$'), reason: s.name);
      }
    });

    test('التحويل عكسي — القراءة بترجّع نفس القيمة', () {
      // الكتابة بـ wire والقراءة بـ parse. لو الاتنين مش متعاكسين،
      // المنتج بيتكتب بحالة ويترجع بحالة تانية.
      for (final c in ItemCondition.values) {
        expect(ItemConditionX.parse(c.wire), c, reason: c.name);
      }
    });
  });

  // ===========================================================================
  group('العملات — عدد الخانات العشرية', () {
    // الدينار الكويتي 3 خانات، والباقي 2. لو ده غلط، التقدير بيتعرض
    // بعامل 10 — والمستخدم بياخد قرار مقايضة على رقم غلط.
    //
    // نفس التأكيد موجود في القسم 15 من اختبارات القاعدة.

    test('الدينار الكويتي 3 خانات', () {
      expect(Countries.byCode('KW').currency.decimals, 3);
    });

    test('الجنيه المصري خانتان', () {
      expect(Countries.byCode('EG').currency.decimals, 2);
    });

    test('كل الدول عندها عملة بخانات منطقية', () {
      for (final country in Countries.all) {
        expect(
          country.currency.decimals,
          inInclusiveRange(0, 3),
          reason: country.code,
        );
      }
    });

    test('أكواد العملات كلها 3 حروف كبيرة', () {
      for (final country in Countries.all) {
        expect(country.currency.code, matches(r'^[A-Z]{3}$'),
            reason: country.code,);
      }
    });
  });

  // ===========================================================================
  group('كتالوج الدول والمدن', () {
    test('مصر موجودة ومعاها القاهرة والجيزة', () {
      final eg = Countries.byCode('EG');
      final cityIds = eg.cities.map((c) => c.id).toList();
      expect(cityIds, contains('cairo'));
      expect(cityIds, contains('giza'));
    });

    test('كل دولة عندها مدينة واحدة على الأقل', () {
      // من غير مدينة، المستخدم مايقدرش يكمّل الإعداد — والسوق بيبقى فاضي
      // لأن الترشيح بيبدأ بالمدينة.
      for (final country in Countries.all) {
        expect(country.cities, isNotEmpty, reason: country.code);
      }
    });

    test('معرّفات المدن فريدة على مستوى التطبيق كله', () {
      // المعرّفات دي مفاتيح أجنبية في القاعدة. التكرار بيخلي منتج
      // يتربط بمدينة غلط.
      final all = <String>[];
      for (final country in Countries.all) {
        all.addAll(country.cities.map((c) => c.id));
      }
      expect(all.toSet().length, all.length);
    });
  });
}
