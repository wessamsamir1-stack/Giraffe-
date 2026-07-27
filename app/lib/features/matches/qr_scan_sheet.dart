import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../widgets/g_button.dart';
import '../../widgets/g_common.dart';
import 'trade_code.dart';

/// ماسح كود الإتمام.
///
/// -----------------------------------------------------------------------------
/// الكاميرا **مش المسار الوحيد**، ولا حتى المضمون.
///
/// اللقاء بيحصل في مكان عام: نور واطي، زحمة، شاشة مكسورة، صلاحية
/// مرفوضة، جهاز قديم كاميرته بايظة. كل دول بيحصلوا فعلاً.
///
/// فالماسح ده **تسريع** للمسار المكتوب مش بديل عنه. وأي فشل هنا
/// بيرجّع المستخدم للكتابة اليدوية بضغطة — مش بيسيبه في شاشة سودا.
/// -----------------------------------------------------------------------------
class QrScanSheet extends StatefulWidget {
  const QrScanSheet({super.key, required this.matchId});

  /// الغرفة الحالية — بنقارن بيها الكود الممسوح.
  final String matchId;

  @override
  State<QrScanSheet> createState() => _QrScanSheetState();
}

class _QrScanSheetState extends State<QrScanSheet> {
  final _controller = MobileScannerController(
    // الكود المتوقع QR بس — تضييق الأنواع بيسرّع الكشف وبيقلل
    // الالتقاط الغلط من باركود منتج في المحل.
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  /// **الحارس اللي مالوش غنى.**
  ///
  /// الماسح بيرن كل إطار. من غير القفل ده، مسحة واحدة بتبعت عشرات
  /// النداءات — وبتحرق سقف المحاولات الخمسة في أقل من ثانية.
  bool _handled = false;

  bool _torch = false;
  String? _softError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;

    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .where((v) => v != null && v.isNotEmpty)
        .cast<String>()
        .toList();

    if (raw.isEmpty) return;

    final result = parseTradeCode(raw.first, expectedMatchId: widget.matchId);

    switch (result) {
      case ScanOk(:final code):
        _handled = true;
        _controller.stop();
        Navigator.of(context).pop(code);

      // -----------------------------------------------------------------------
      // الأخطاء دي **مابتقفلش الشاشة**. المستخدم واقف قدام الطرف
      // التاني وبيحاول — نوريه المشكلة ونسيبه يجرب تاني.
      // -----------------------------------------------------------------------
      case ScanWrongRoom():
        _softFail(context.tr('scan.err.wrongRoom'));
      case ScanNeedsUpdate():
        _softFail(context.tr('scan.err.needsUpdate'));
      case ScanNotOurs():
        _softFail(context.tr('scan.err.notOurs'));
    }
  }

  void _softFail(String message) {
    if (_softError == message) return;   // مانرفرفش بنفس الرسالة كل إطار
    setState(() => _softError = message);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(GSpace.screenH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('scan.title'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                // النور — اللقاءات بالليل شائعة، ومن غيره الماسح
                // بيبقى بلا فايدة في نص الحالات
                IconButton(
                  onPressed: () async {
                    await _controller.toggleTorch();
                    if (mounted) setState(() => _torch = !_torch);
                  },
                  icon: Icon(
                    _torch ? Icons.flashlight_on_rounded
                           : Icons.flashlight_off_rounded,
                    color: _torch ? c.brand : c.textSecondary,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: GSpace.md),

            ClipRRect(
              borderRadius: GRadius.brXl,
              child: AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: _controller,
                      onDetect: _onDetect,
                      // -------------------------------------------------------
                      // الصلاحية مرفوضة أو الكاميرا مش شغالة.
                      //
                      // ده مش طريق مسدود — بنقول السبب وبنرجّعه للكتابة.
                      // -------------------------------------------------------
                      errorBuilder: (context, error, child) => Container(
                        color: c.surfaceAlt,
                        padding: const EdgeInsets.all(GSpace.lg),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.no_photography_rounded,
                                  size: 34, color: c.textTertiary,),
                              const SizedBox(height: GSpace.md),
                              Text(
                                context.tr('scan.err.camera'),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: GSpace.lg),
                              GButton(
                                label: context.tr('scan.typeInstead'),
                                style: GButtonStyle.secondary,
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // إطار التصويب
                    IgnorePointer(
                      child: Center(
                        child: Container(
                          width: 190,
                          height: 190,
                          decoration: BoxDecoration(
                            border: Border.all(color: c.brand, width: 3),
                            borderRadius: GRadius.brLg,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: GSpace.md),

            if (_softError != null)
              GNotice(
                tone: GNoticeTone.warning,
                icon: Icons.error_outline_rounded,
                text: _softError!,
              )
            else
              Text(
                context.tr('scan.hint'),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: c.textTertiary),
              ),

            const SizedBox(height: GSpace.md),
            GButton(
              label: context.tr('scan.typeInstead'),
              style: GButtonStyle.ghost,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
