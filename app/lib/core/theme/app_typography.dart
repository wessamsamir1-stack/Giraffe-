import 'package:flutter/material.dart';

/// الخطوط.
///
/// IBM Plex Sans Arabic للغتين. الخط ده فيه لاتيني كامل (IBM Plex Sans)
/// مرسوم يتناسق مع العربي — نفس السُمك ونفس ارتفاع الحروف.
///
/// كان فيه خطّين (Inter للإنجليزي)، بس التطبيق مليان جمل عربي فيها
/// أرقام وأسماء منتجات إنجليزي («آيفون 15 برو 256 جيجا»). بخطّين، كل
/// كلمة إنجليزي جوّه الجملة كانت بتتغيّر شكلها وارتفاعها — والعين بتلقط
/// ده كـ«حاجة مش متظبطة» حتى لو مش عارفة تسمّيها.
class GFonts {
  const GFonts._();

  static const String family = 'IBMPlexSansArabic';

  static String forLocale(Locale locale) => family;
}

/// سلّم النصوص.
///
/// القاعدة: عناوين ثقيلة جداً، ونصوص عادية بوزن متوسط.
/// التباين في الوزن هو اللي بيدي الإحساس الفاخر مش كتر الأحجام.
class GText {
  const GText._();

  static TextTheme build({
    required String fontFamily,
    required Color primary,
    required Color secondary,
  }) {
    TextStyle s(
      double size,
      FontWeight weight, {
      double? height,
      double? spacing,
      Color? color,
    }) {
      return TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: weight,
        height: height ?? 1.35,
        letterSpacing: spacing,
        color: color ?? primary,
      );
    }

    return TextTheme(
      // العناوين الضخمة — شاشات الترحيب والاحتفال
      displayLarge: s(40, FontWeight.w800, height: 1.15, spacing: -0.8),
      displayMedium: s(34, FontWeight.w800, height: 1.18, spacing: -0.6),
      displaySmall: s(28, FontWeight.w700, height: 1.2, spacing: -0.4),

      // عناوين الشاشات
      headlineLarge: s(26, FontWeight.w700, height: 1.25, spacing: -0.3),
      headlineMedium: s(22, FontWeight.w700, height: 1.3, spacing: -0.2),
      headlineSmall: s(19, FontWeight.w700, height: 1.3),

      // عناوين الأقسام والكروت
      titleLarge: s(17, FontWeight.w600, height: 1.35),
      titleMedium: s(15, FontWeight.w600, height: 1.4),
      titleSmall: s(13.5, FontWeight.w600, height: 1.4),

      // النصوص
      bodyLarge: s(16, FontWeight.w400, height: 1.55),
      bodyMedium: s(14.5, FontWeight.w400, height: 1.55, color: secondary),
      bodySmall: s(13, FontWeight.w400, height: 1.5, color: secondary),

      // التسميات والأزرار
      labelLarge: s(15, FontWeight.w600, height: 1.2),
      labelMedium: s(13, FontWeight.w600, height: 1.2),
      labelSmall: s(11.5, FontWeight.w600, height: 1.2, spacing: 0.2),
    );
  }
}

extension GTextContext on BuildContext {
  TextTheme get text => Theme.of(this).textTheme;
}
