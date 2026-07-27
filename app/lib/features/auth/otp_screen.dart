import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/security/attempt_guard.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../widgets/g_button.dart';
import '../../widgets/g_common.dart';
import '../../widgets/g_text_field.dart';

/// شاشة كود التحقق.
///
/// الحمايات المطبقة:
/// - 5 محاولات ثم قفل تصاعدي
/// - إعادة الإرسال بمهلة تتضاعف: 60 ← 120 ← 240 ثانية
/// - الكود بيتقرأ تلقائياً من الرسالة عبر `AutofillHints.oneTimeCode`
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.target, this.isEmail = false});

  final String target;
  final bool isEmail;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _guard = AttemptGuard();
  final _cooldown = ResendCooldown();

  bool _hasError = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _guard.addListener(_refresh);
    _cooldown.addListener(_refresh);
    _cooldown.start();
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _guard.removeListener(_refresh);
    _cooldown.removeListener(_refresh);
    _guard.dispose();
    _cooldown.dispose();
    super.dispose();
  }

  Future<void> _verify(String code) async {
    if (_guard.isLocked) return;

    setState(() {
      _loading = true;
      _hasError = false;
    });
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    // في النسخة المبدئية أي كود بيعدي ماعدا 000000 عشان نجرب حالة الخطأ.
    final ok = code != '000000';
    setState(() {
      _loading = false;
      _hasError = !ok;
    });

    if (ok) {
      _guard.recordSuccess();
      context.go(R.onbProfile);
    } else {
      _guard.recordFailure();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(widget.isEmail ? 'verify.emailTitle' : 'verify.phoneTitle'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            GSpace.screenH,
            GSpace.xl,
            GSpace.screenH,
            GSpace.xxxl,
          ),
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: c.brandSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.isEmail
                    ? Icons.mark_email_unread_outlined
                    : Icons.sms_outlined,
                size: 34,
                color: c.brand,
              ),
            ),
            const SizedBox(height: GSpace.xl),
            Text(
              context.tr('otp.title'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: GSpace.sm),
            Text(
              context.tr(widget.isEmail ? 'otp.bodyEmail' : 'otp.bodyPhone'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: GSpace.xs),
            Text(
              widget.target,
              style: Theme.of(context).textTheme.titleMedium,
              textDirection: TextDirection.ltr,
            ),

            const SizedBox(height: GSpace.xxxl),
            GOtpField(
              onCompleted: _verify,
              hasError: _hasError,
              enabled: !_guard.isLocked && !_loading,
            ),

            if (_hasError && !_guard.isLocked) ...[
              const SizedBox(height: GSpace.lg),
              Text(
                context.trf('otp.attemptsLeft', {'n': _guard.attemptsLeft}),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: c.danger),
              ),
            ],

            if (_guard.isLocked) ...[
              const SizedBox(height: GSpace.lg),
              GNotice(
                tone: GNoticeTone.danger,
                icon: Icons.lock_clock_outlined,
                text: context.trf('otp.locked', {
                  'n': (_guard.lockSecondsLeft / 60).ceil(),
                }),
              ),
            ],

            const SizedBox(height: GSpace.xxl),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              Center(
                child: _cooldown.canResend
                    ? TextButton(
                        onPressed: _cooldown.start,
                        child: Text(
                          context.tr('otp.resend'),
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: c.brand),
                        ),
                      )
                    : Text(
                        context.trf('otp.resendIn', {
                          'n': _cooldown.secondsLeft,
                        }),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
              ),

            const SizedBox(height: GSpace.xxl),
            if (!widget.isEmail)
              GNotice(
                icon: Icons.shield_outlined,
                text: context.tr('verify.phoneWhy'),
              ),

            const SizedBox(height: GSpace.xl),
            GButton(
              label: context.tr('common.back'),
              style: GButtonStyle.ghost,
              onPressed: () => context.pop(),
            ),
          ],
        ),
      ),
    );
  }
}
