import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/mock/mock_data.dart';
import '../../widgets/g_button.dart';
import '../../widgets/g_common.dart';

/// إتمام الصفقة بتأكيد الطرفين.
///
/// الصفقة ما بتتسجلش مكتملة إلا لما **الاتنين** يمسحوا كود بعض.
/// ده اللي بيمنع تسجيل صفقات وهمية لرفع مستوى الثقة.
class CompleteTradeScreen extends StatefulWidget {
  const CompleteTradeScreen({super.key, required this.matchId});

  final String matchId;

  @override
  State<CompleteTradeScreen> createState() => _CompleteTradeScreenState();
}

class _CompleteTradeScreenState extends State<CompleteTradeScreen> {
  bool _scanned = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final match = Mock.match(widget.matchId);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('complete.title'))),
      body: ListView(
        padding: const EdgeInsets.all(GSpace.screenH),
        children: [
          Text(
            context.tr('complete.body'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: GSpace.xxl),

          Center(
            child: Column(
              children: [
                Text(
                  context.tr('complete.myCode'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: GSpace.md),
                Container(
                  padding: const EdgeInsets.all(GSpace.lg),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: GRadius.brXl,
                    border: Border.all(color: c.border, width: 1.4),
                  ),
                  child: const _QrPlaceholder(size: 168),
                ),
              ],
            ),
          ),

          const SizedBox(height: GSpace.xxl),
          GButton(
            label: context.tr('complete.scan'),
            icon: Icons.qr_code_scanner_rounded,
            onPressed: () => setState(() => _scanned = true),
          ),

          const SizedBox(height: GSpace.xl),
          if (_scanned)
            GNotice(
              tone: GNoticeTone.success,
              icon: Icons.hourglass_top_rounded,
              text: context.trf('complete.waiting', {
                'name': match.other.displayName,
              }),
            ),

          const SizedBox(height: GSpace.xxl),
          GButton(
            label: context.tr('rate.title'),
            style: GButtonStyle.ghost,
            onPressed: _scanned
                ? () => context.pushReplacement(R.rate(widget.matchId))
                : null,
          ),
        ],
      ),
    );
  }
}

/// رسم مبدئي لكود QR — بيتستبدل بمكتبة توليد حقيقية عند الربط.
class _QrPlaceholder extends StatelessWidget {
  const _QrPlaceholder({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _QrPainter(),
    );
  }
}

class _QrPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const modules = 21;
    final cell = size.width / modules;
    final paint = Paint()..color = const Color(0xFF121212);

    // نمط ثابت مشتق من الإحداثيات — مش عشوائي عشان مايرفرفش عند إعادة الرسم.
    for (var y = 0; y < modules; y++) {
      for (var x = 0; x < modules; x++) {
        final inFinder = (x < 7 && y < 7) ||
            (x >= modules - 7 && y < 7) ||
            (x < 7 && y >= modules - 7);
        final on = inFinder
            ? (x % 6 == 0 || y % 6 == 0 || (x > 1 && x < 5 && y > 1 && y < 5))
            : ((x * 7 + y * 13 + x * y) % 3 == 0);
        if (on) {
          canvas.drawRect(
            Rect.fromLTWH(x * cell, y * cell, cell * 0.92, cell * 0.92),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter oldDelegate) => false;
}
