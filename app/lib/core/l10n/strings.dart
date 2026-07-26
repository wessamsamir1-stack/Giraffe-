import 'package:flutter/widgets.dart';

import 'strings_ar.dart';
import 'strings_en.dart';

/// نظام الترجمة.
///
/// مبني على خرائط بسيطة بدل توليد الكود، عشان يفضل المشروع سهل التشغيل
/// من غير أي خطوة بناء إضافية. لو المفتاح مش موجود بيرجع المفتاح نفسه
/// عشان النقص يبان في التطوير بدل ما يختفي.
class S {
  const S(this.locale);

  final Locale locale;

  static const List<Locale> supported = [Locale('ar'), Locale('en')];

  static S of(BuildContext context) => S(Localizations.localeOf(context));

  bool get isArabic => locale.languageCode == 'ar';

  Map<String, String> get _map => isArabic ? kAr : kEn;

  String t(String key) => _map[key] ?? kAr[key] ?? key;

  /// استبدال متغيرات داخل النص: `{n}`
  String tf(String key, Map<String, Object?> args) {
    var out = t(key);
    args.forEach((k, v) => out = out.replaceAll('{$k}', '$v'));
    return out;
  }
}

extension SContext on BuildContext {
  S get s => S.of(this);

  /// اختصار: `context.tr('deck.title')`
  String tr(String key) => S.of(this).t(key);

  String trf(String key, Map<String, Object?> args) => S.of(this).tf(key, args);

  bool get isRtl => Directionality.of(this) == TextDirection.rtl;
}

/// مندوب الترجمة — بيخلي فلاتر يعرف إن اللغتين مدعومتين.
class GLocalizationsDelegate extends LocalizationsDelegate<S> {
  const GLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      S.supported.any((l) => l.languageCode == locale.languageCode);

  @override
  Future<S> load(Locale locale) async => S(locale);

  @override
  bool shouldReload(GLocalizationsDelegate old) => false;
}
