import 'package:flutter/material.dart';

/// ألوان Giraffe — مصدر الحقيقة الوحيد للألوان في التطبيق.
///
/// ممنوع كتابة أي لون مباشر داخل الشاشات.
/// كل لون هنا له نسخة فاتحة ونسخة داكنة عبر [GColors.of].
class AppPalette {
  const AppPalette._();

  // ---------------------------------------------------------------- Brand
  static const Color orange50 = Color(0xFFFFF4EA);
  static const Color orange100 = Color(0xFFFFE3CC);
  static const Color orange200 = Color(0xFFFFC79A);
  static const Color orange300 = Color(0xFFFBA85F);
  static const Color orange400 = Color(0xFFF8933B);
  static const Color orange500 = Color(0xFFF58220); // اللون الأساسي
  static const Color orange600 = Color(0xFFDC6F12);
  static const Color orange700 = Color(0xFFB2570C);
  static const Color orange800 = Color(0xFF83400A);
  static const Color orange900 = Color(0xFF4E2606);

  // ---------------------------------------------------------------- Neutral
  static const Color white = Color(0xFFFFFFFF);
  static const Color gray50 = Color(0xFFFAFAFA);
  static const Color gray100 = Color(0xFFF3F3F3);
  static const Color gray200 = Color(0xFFE7E7E7);
  static const Color gray300 = Color(0xFFD5D5D5);
  static const Color gray400 = Color(0xFFB0B0B0);
  static const Color gray500 = Color(0xFF8A8A8A);
  static const Color gray600 = Color(0xFF636363);
  static const Color gray700 = Color(0xFF454545);
  static const Color gray800 = Color(0xFF2A2A2A);
  static const Color gray900 = Color(0xFF1A1A1A);
  static const Color black = Color(0xFF121212);
  static const Color trueBlack = Color(0xFF0A0A0A);

  // ---------------------------------------------------------------- Semantic
  static const Color success = Color(0xFF28C76F);
  static const Color successSoft = Color(0xFFE6F9EF);
  static const Color warning = Color(0xFFFFB020);
  static const Color warningSoft = Color(0xFFFFF6E5);
  static const Color danger = Color(0xFFFF4D4F);
  static const Color dangerSoft = Color(0xFFFFECEC);
  static const Color info = Color(0xFF2F80ED);
  static const Color infoSoft = Color(0xFFE9F1FD);

  // ------------------------------------------------------- Trust levels
  static const Color trustNew = gray500;
  static const Color trustVerified = info;
  static const Color trustTrusted = success;
  static const Color trustElite = Color(0xFF9B51E0);

  // ------------------------------------------------------- Swipe intents
  static const Color swipeSkip = gray500;
  static const Color swipeInterested = success;
  static const Color swipeDream = Color(0xFF9B51E0);
}

/// مجموعة الألوان الفعّالة حسب الوضع (فاتح / داكن).
@immutable
class GColors extends ThemeExtension<GColors> {
  const GColors({
    required this.brand,
    required this.brandSoft,
    required this.onBrand,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceSunken,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textInverse,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.overlay,
    required this.shimmerBase,
    required this.shimmerHighlight,
  });

  final Color brand;
  final Color brandSoft;
  final Color onBrand;

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color surfaceSunken;

  final Color border;
  final Color borderStrong;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textInverse;

  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  final Color overlay;
  final Color shimmerBase;
  final Color shimmerHighlight;

  static const GColors light = GColors(
    brand: AppPalette.orange500,
    brandSoft: AppPalette.orange50,
    onBrand: AppPalette.white,
    background: AppPalette.gray50,
    surface: AppPalette.white,
    surfaceAlt: AppPalette.gray100,
    surfaceSunken: AppPalette.gray200,
    border: AppPalette.gray200,
    borderStrong: AppPalette.gray300,
    textPrimary: AppPalette.black,
    textSecondary: AppPalette.gray600,
    textTertiary: AppPalette.gray500,
    textInverse: AppPalette.white,
    success: AppPalette.success,
    warning: AppPalette.warning,
    danger: AppPalette.danger,
    info: AppPalette.info,
    overlay: Color(0x66000000),
    shimmerBase: AppPalette.gray200,
    shimmerHighlight: AppPalette.gray100,
  );

  static const GColors dark = GColors(
    brand: AppPalette.orange400,
    brandSoft: Color(0xFF2A1B0C),
    onBrand: AppPalette.black,
    background: AppPalette.trueBlack,
    surface: AppPalette.gray900,
    surfaceAlt: AppPalette.gray800,
    surfaceSunken: Color(0xFF141414),
    border: Color(0xFF2E2E2E),
    borderStrong: Color(0xFF3D3D3D),
    textPrimary: Color(0xFFF5F5F5),
    textSecondary: AppPalette.gray400,
    textTertiary: AppPalette.gray500,
    textInverse: AppPalette.black,
    success: AppPalette.success,
    warning: AppPalette.warning,
    danger: Color(0xFFFF6B6D),
    info: Color(0xFF5B9BF3),
    overlay: Color(0x99000000),
    shimmerBase: AppPalette.gray800,
    shimmerHighlight: Color(0xFF303030),
  );

  @override
  GColors copyWith({
    Color? brand,
    Color? brandSoft,
    Color? onBrand,
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? surfaceSunken,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textInverse,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? overlay,
    Color? shimmerBase,
    Color? shimmerHighlight,
  }) {
    return GColors(
      brand: brand ?? this.brand,
      brandSoft: brandSoft ?? this.brandSoft,
      onBrand: onBrand ?? this.onBrand,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textInverse: textInverse ?? this.textInverse,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      overlay: overlay ?? this.overlay,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
    );
  }

  @override
  GColors lerp(ThemeExtension<GColors>? other, double t) {
    if (other is! GColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return GColors(
      brand: c(brand, other.brand),
      brandSoft: c(brandSoft, other.brandSoft),
      onBrand: c(onBrand, other.onBrand),
      background: c(background, other.background),
      surface: c(surface, other.surface),
      surfaceAlt: c(surfaceAlt, other.surfaceAlt),
      surfaceSunken: c(surfaceSunken, other.surfaceSunken),
      border: c(border, other.border),
      borderStrong: c(borderStrong, other.borderStrong),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textTertiary: c(textTertiary, other.textTertiary),
      textInverse: c(textInverse, other.textInverse),
      success: c(success, other.success),
      warning: c(warning, other.warning),
      danger: c(danger, other.danger),
      info: c(info, other.info),
      overlay: c(overlay, other.overlay),
      shimmerBase: c(shimmerBase, other.shimmerBase),
      shimmerHighlight: c(shimmerHighlight, other.shimmerHighlight),
    );
  }
}

extension GColorsContext on BuildContext {
  /// اختصار الوصول للألوان: `context.colors.brand`
  GColors get colors => Theme.of(this).extension<GColors>() ?? GColors.light;
}
