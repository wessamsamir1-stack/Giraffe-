import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/repositories/providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1000), _decideRoute);
  }

  /// وجهة الفتح بتتحدد من حالة الجلسة ومدى اكتمال الإعداد.
  ///
  /// الترتيب مقصود: **قائمة الرغبات إجبارية** قبل الوصول للتطبيق، لأن
  /// من غيرها محرك المطابقة مابيشتغلش والـ deck بيبقى فاضي.
  Future<void> _decideRoute() async {
    if (!mounted) return;

    final auth = ref.read(authRepositoryProvider);

    if (!auth.isSignedIn) {
      if (mounted) context.go(R.onbIntro);
      return;
    }

    final profile = await ref.read(profileRepositoryProvider).myProfile();
    if (!mounted) return;

    if (profile == null) {
      context.go(R.onbProfile);
      return;
    }

    final ready = await ref.read(wishlistRepositoryProvider).isSetupComplete();
    if (!mounted) return;

    context.go(ready ? R.market : R.onbWishlist);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.brand,
      body: Center(
        child: FadeTransition(
          opacity: _controller,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1).animate(
              CurvedAnimation(parent: _controller, curve: GCurve.enter),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const GiraffeMark(size: 108, color: Colors.white),
                const SizedBox(height: GSpace.xl),
                Text(
                  'Giraffe',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                ),
                const SizedBox(height: GSpace.xs),
                Text(
                  context.tr('app.tagline'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.85),
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// علامة الجيراف — حرف G بقرون وبقع.
///
/// نسخة مبسطة مرسومة بالكود لحد ما ينزل ملف الـ SVG النهائي،
/// عشان المشروع يشتغل من غير أي أصول خارجية.
class GiraffeMark extends StatelessWidget {
  const GiraffeMark({super.key, this.size = 72, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _GiraffePainter(color ?? context.colors.brand),
    );
  }
}

class _GiraffePainter extends CustomPainter {
  const _GiraffePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.13
      ..strokeCap = StrokeCap.round;

    final fill = Paint()..color = color;

    // القرون
    final hornY = h * 0.10;
    canvas.drawLine(Offset(w * 0.38, h * 0.22), Offset(w * 0.34, hornY), paint..strokeWidth = w * 0.055);
    canvas.drawLine(Offset(w * 0.60, h * 0.22), Offset(w * 0.64, hornY), paint..strokeWidth = w * 0.055);
    canvas.drawCircle(Offset(w * 0.34, hornY), w * 0.055, fill);
    canvas.drawCircle(Offset(w * 0.64, hornY), w * 0.055, fill);

    // جسم حرف G
    final rect = Rect.fromCircle(
      center: Offset(w * 0.5, h * 0.58),
      radius: w * 0.30,
    );
    final gPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.14
      ..strokeCap = StrokeCap.round;

    // قوس من الأعلى ولف كامل ماعدا فتحة الحرف
    canvas.drawArc(rect, -1.05, 5.05, false, gPaint);

    // الشرطة الأفقية للحرف G
    canvas.drawLine(
      Offset(w * 0.50, h * 0.58),
      Offset(w * 0.80, h * 0.58),
      gPaint..strokeWidth = w * 0.13,
    );
  }

  @override
  bool shouldRepaint(_GiraffePainter old) => old.color != color;
}
