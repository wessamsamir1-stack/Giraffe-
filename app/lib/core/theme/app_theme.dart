import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_dimens.dart';
import 'app_interaction.dart';
import 'app_typography.dart';

/// بناء ثيم التطبيق.
///
/// ملاحظة مقصودة: الثيم بسيط عمداً ومفيهوش أنماط أزرار أو كروت.
/// كل المكوّنات مبنية يدوي في `lib/widgets` عشان يبقى عندنا تحكم كامل
/// في الشكل ومنبقاش مرتبطين بتغيّرات Material بين إصدارات فلاتر.
class AppTheme {
  const AppTheme._();

  static ThemeData light(Locale locale) => _build(
        colors: GColors.light,
        brightness: Brightness.light,
        locale: locale,
      );

  static ThemeData dark(Locale locale) => _build(
        colors: GColors.dark,
        brightness: Brightness.dark,
        locale: locale,
      );

  static ThemeData _build({
    required GColors colors,
    required Brightness brightness,
    required Locale locale,
  }) {
    final isDark = brightness == Brightness.dark;
    final family = GFonts.forLocale(locale);

    final textTheme = GText.build(
      fontFamily: family,
      primary: colors.textPrimary,
      secondary: colors.textSecondary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: family,
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.surface,
      // على iOS مفيش موجة حبر. أي حاجة بتعمل ripple هناك بتحس
      // إنها مستوردة من أندرويد.
      splashFactory:
          isApplePlatform ? NoSplash.splashFactory : InkSparkle.splashFactory,
      pageTransitionsTheme: pageTransitions,
      textTheme: textTheme,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: colors.brand,
        onPrimary: colors.onBrand,
        secondary: colors.brand,
        onSecondary: colors.onBrand,
        error: colors.danger,
        onError: Colors.white,
        surface: colors.surface,
        onSurface: colors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      dividerColor: colors.border,
      // الفواصل على أبل شعرة فعلاً — بكسل واحد فيزيائي مش منطقي.
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: isApplePlatform ? 0.5 : 1,
        space: isApplePlatform ? 0.5 : 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: colors.surface,
        shape: const RoundedRectangleBorder(borderRadius: GRadius.sheet),
        clipBehavior: Clip.antiAlias,
        showDragHandle: true,
        dragHandleColor: colors.border,
        dragHandleSize: const Size(36, 4),
        elevation: 0,
        modalElevation: 0,
      ),
      iconTheme: IconThemeData(color: colors.textSecondary),
      extensions: <ThemeExtension<dynamic>>[colors],
    );
  }
}
