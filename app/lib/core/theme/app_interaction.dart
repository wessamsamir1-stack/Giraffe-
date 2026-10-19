import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_dimens.dart';

/// هل إحنا على منصة بتتبع أسلوب أبل؟
///
/// مابنسألش `Theme.of(context).platform` هنا عشان الدالة دي بتتندَه
/// من مكانات مالهاش `context`، وعشان الإجابة ثابتة طول عمر التطبيق.
bool get isApplePlatform {
  if (kIsWeb) return false;
  return Platform.isIOS || Platform.isMacOS;
}

/// اللمس — الطبقة اللي كانت ناقصة.
///
/// -----------------------------------------------------------------------
/// ليه الموضوع ده مهم
///
/// أكتر حاجة بتخلي تطبيق يحس إنه «صفحة ويب» مش تطبيق هي إن اللمسة
/// مابترجعش حاجة. المستخدم بيدوس، والشاشة ساكتة لحد ما الصفحة الجديدة
/// تظهر. الفرق بين ١٠٠ مللي فاضية ودي بالذات هو كل الفرق.
///
/// -----------------------------------------------------------------------
/// ليه مش `InkWell` وخلاص
///
/// الـ ripple بتاع ماتيريال أسلوب أندرويد. على الآيفون هو **غلط صريح** —
/// مفيش تطبيق أصلي على iOS بيعمل موجة حبر من مكان الإصبع.
///
/// فالويدجت دي بتعمل الاتنين:
///   - الانكماش والاهتزاز: على كل المنصات، ده الإحساس المشترك.
///   - الـ ripple: على أندرويد بس.
class GPressable extends StatefulWidget {
  const GPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.radius = GRadius.brLg,
    this.scale = 0.975,
    this.haptic = GHaptic.selection,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// لازم يطابق نصف قطر العنصر، وإلا الـ ripple هيخرج بره الحواف.
  final BorderRadius radius;

  /// نسبة الانكماش. أقل من 0.95 بيحس إنه لعبة، وفوق 0.99 مش محسوس.
  final double scale;

  final GHaptic haptic;
  final HitTestBehavior behavior;

  @override
  State<GPressable> createState() => _GPressableState();
}

class _GPressableState extends State<GPressable> {
  bool _down = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _setDown(bool v) {
    if (!_enabled || _down == v) return;
    setState(() => _down = v);
  }

  void _handleTap() {
    widget.haptic.fire();
    widget.onTap?.call();
  }

  void _handleLongPress() {
    GHaptic.impactMedium.fire();
    widget.onLongPress?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return widget.child;

    Widget content = AnimatedScale(
      scale: _down ? widget.scale : 1,
      duration: GDuration.instant,
      curve: GCurve.standard,
      child: widget.child,
    );

    // الـ ripple على أندرويد بس — وتحت المحتوى مش فوقه، عشان
    // مايغطيش الصور.
    if (!isApplePlatform) {
      content = Material(
        type: MaterialType.transparency,
        borderRadius: widget.radius,
        child: InkWell(
          onTap: _handleTap,
          onLongPress: widget.onLongPress == null ? null : _handleLongPress,
          onHighlightChanged: _setDown,
          borderRadius: widget.radius,
          child: content,
        ),
      );
      return content;
    }

    return GestureDetector(
      behavior: widget.behavior,
      onTap: _handleTap,
      onLongPress: widget.onLongPress == null ? null : _handleLongPress,
      onTapDown: (_) => _setDown(true),
      onTapUp: (_) => _setDown(false),
      onTapCancel: () => _setDown(false),
      child: content,
    );
  }
}

/// الاهتزاز — مسمّى بالمعنى مش بالشدّة.
///
/// السبب: الشدة الصح بتختلف بين المنصتين، والكود اللي بينده
/// مالوش دعوة بده. اللي بيهمه هو «ده اختيار» ولا «ده نجح» ولا «ده غلط».
enum GHaptic {
  /// مفيش — للعناصر اللي بتتلمس كتير أوي (عناصر القوايم الطويلة).
  none,

  /// اختيار — تبويب، شريحة، صف في قايمة.
  selection,

  /// تأكيد خفيف — إعجاب، حفظ.
  impactLight,

  /// حدث حقيقي — تطابق، إتمام مقايضة.
  impactMedium,

  /// تحذير — رفض، خطأ.
  heavy;

  void fire() {
    // على الويب مفيش اهتزاز، ومحاولة النداء بتطلع تحذير في الـ console
    // كل مرة. فساكتين.
    if (kIsWeb) return;

    switch (this) {
      case GHaptic.none:
        return;
      case GHaptic.selection:
        HapticFeedback.selectionClick();
      case GHaptic.impactLight:
        HapticFeedback.lightImpact();
      case GHaptic.impactMedium:
        HapticFeedback.mediumImpact();
      case GHaptic.heavy:
        HapticFeedback.heavyImpact();
    }
  }
}

/// سلوك التمرير.
///
/// فلاتر بيدي ارتداد (bouncing) على iOS وتوهّج على أندرويد. وده صح
/// على الموبايل، بس على الويب بيدي تمرير ماتيريال الجاف + شريط تمرير
/// ظاهر — واللي بيفضح إن ده تطبيق ويب على طول.
///
/// إحنا بنوحّد الارتداد على كل المنصات: ده الإحساس اللي الناس
/// مستنياه من تطبيق موبايل، حتى وهو شغال في متصفح.
class GScrollBehavior extends MaterialScrollBehavior {
  const GScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;

  /// السحب بالماوس كمان — عشان النسخة على المتصفح تتسحب بالمؤشر
  /// زي ما بتتسحب بالصباع.
  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };
}

/// انتقالات الصفحات.
///
/// الافتراضي في ماتيريال 3 هو `Zoom` على كل المنصات — وده على iOS
/// بيلغي سحب الرجوع من حرف الشاشة، وهي حركة أساسية هناك.
const pageTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.android: ZoomPageTransitionsBuilder(),
    TargetPlatform.windows: ZoomPageTransitionsBuilder(),
    TargetPlatform.linux: ZoomPageTransitionsBuilder(),
    // على الويب بنستخدم انتقال أبل كمان: الحركة الجانبية بتقرأ
    // كـ«دخلت أعمق»، والتلاشي بيقرأ كـ«الصفحة اتبدلت».
    TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
  },
);
