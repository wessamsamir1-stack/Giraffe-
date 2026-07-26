import 'package:flutter/material.dart';
import 'app_colors.dart';

/// المسافات — سلّم بمضاعفات الأربعة.
class GSpace {
  const GSpace._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
  static const double giant = 56;

  /// الهامش الأفقي القياسي للشاشات.
  static const double screenH = 20;
}

/// أنصاف الأقطار — التطبيق كله دائري الحواف.
class GRadius {
  const GRadius._();

  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double xxl = 32;
  static const double pill = 999;

  static const BorderRadius brXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius brXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius brXxl = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius brPill = BorderRadius.all(Radius.circular(pill));

  /// حواف علوية فقط — للـ bottom sheets.
  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(xxl),
  );
}

/// الظلال — ناعمة ومنخفضة التباين. ممنوع الظل الحاد.
class GShadow {
  const GShadow._();

  static List<BoxShadow> soft(bool isDark) => [
        BoxShadow(
          color: isDark ? const Color(0x66000000) : const Color(0x0D000000),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> card(bool isDark) => [
        BoxShadow(
          color: isDark ? const Color(0x80000000) : const Color(0x12000000),
          blurRadius: 24,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> lifted(bool isDark) => [
        BoxShadow(
          color: isDark ? const Color(0x99000000) : const Color(0x1F000000),
          blurRadius: 40,
          offset: const Offset(0, 14),
        ),
      ];

  static List<BoxShadow> brand() => [
        BoxShadow(
          color: AppPalette.orange500.withOpacity(0.32),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];
}

/// مدد الحركة — كلها قصيرة. أي حركة فوق 400 مللي بتحس بالبطء.
class GDuration {
  const GDuration._();

  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration base = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 360);
  static const Duration celebrate = Duration(milliseconds: 700);
}

/// منحنيات الحركة.
class GCurve {
  const GCurve._();

  static const Curve standard = Curves.easeOutCubic;
  static const Curve enter = Curves.easeOutBack;
  static const Curve exit = Curves.easeInCubic;
  static const Curve spring = Curves.elasticOut;
}

/// أحجام ثابتة متكررة.
class GSize {
  const GSize._();

  static const double buttonHeight = 54;
  static const double buttonHeightSm = 42;
  static const double fieldHeight = 56;
  static const double avatarSm = 32;
  static const double avatarMd = 44;
  static const double avatarLg = 72;
  static const double avatarXl = 104;
  static const double navBarHeight = 66;
  static const double iconSm = 18;
  static const double iconMd = 22;
  static const double iconLg = 28;

  /// أقل مساحة لمس مقبولة — قاعدة إتاحة غير قابلة للتفاوض.
  static const double minTapTarget = 48;
}
