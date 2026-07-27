import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/security/attempt_guard.dart';
import '../../core/security/validators.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/repositories/providers.dart';
import '../../widgets/g_button.dart';
import '../../widgets/g_common.dart';
import '../../widgets/g_text_field.dart';

/// شاشة تسجيل الدخول.
///
/// قاعدة أمنية مطبقة هنا: **ممنوع كشف وجود الحساب**.
/// رسالة الخطأ واحدة سواء البريد غلط أو كلمة السر غلط
/// (`auth.err.generic`)، عشان مانسمحش بتعداد الحسابات.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _guard = AttemptGuard();

  String? _formError;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _guard.addListener(_onGuard);
  }

  void _onGuard() => setState(() {});

  @override
  void dispose() {
    _guard.removeListener(_onGuard);
    _guard.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_guard.isLocked) return;

    final emailError = Validators.email(_email.text);
    final passwordEmpty = _password.text.isEmpty;

    if (emailError != null || passwordEmpty) {
      setState(() => _formError = 'auth.err.generic');
      _guard.recordFailure();
      return;
    }

    setState(() {
      _loading = true;
      _formError = null;
    });

    final result = await ref.read(authRepositoryProvider).signIn(
          email: _email.text,
          password: _password.text,
        );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.isOk) {
      _guard.recordFailure();
      // رسالة موحّدة دايماً — ممنوع نكشف إذا كان الحساب موجود
      setState(() => _formError = 'auth.err.generic');
      return;
    }

    _guard.recordSuccess();
    if (mounted) context.go(R.splash);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('auth.signInTitle'))),
      body: SafeArea(
        child: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              GSpace.screenH,
              GSpace.lg,
              GSpace.screenH,
              GSpace.xxxl,
            ),
            children: [
              GTextField(
                label: context.tr('auth.email'),
                controller: _email,
                hint: context.tr('auth.emailHint'),
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                onChanged: (_) => setState(() => _formError = null),
              ),
              const SizedBox(height: GSpace.xl),

              GPasswordField(
                label: context.tr('auth.password'),
                controller: _password,
                showMeter: false,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() => _formError = null),
              ),

              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () => context.push(R.forgot),
                  child: Text(
                    context.tr('auth.forgot'),
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: c.brand),
                  ),
                ),
              ),

              if (_formError != null) ...[
                const SizedBox(height: GSpace.sm),
                GNotice(
                  tone: GNoticeTone.danger,
                  icon: Icons.error_outline_rounded,
                  text: context.tr(_formError!),
                ),
              ],

              if (_guard.failedAttempts > 0 && !_guard.isLocked) ...[
                const SizedBox(height: GSpace.md),
                Text(
                  context.trf('otp.attemptsLeft', {'n': _guard.attemptsLeft}),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: c.warning),
                ),
              ],

              if (_guard.isLocked) ...[
                const SizedBox(height: GSpace.md),
                GNotice(
                  tone: GNoticeTone.danger,
                  icon: Icons.timer_outlined,
                  text: context.trf('auth.err.tooManyAttempts', {
                    'n': _guard.lockSecondsLeft,
                  }),
                ),
              ],

              const SizedBox(height: GSpace.xxl),
              GButton(
                label: context.tr('auth.signIn'),
                loading: _loading,
                onPressed: _guard.isLocked ? null : _submit,
              ),

              const SizedBox(height: GSpace.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    context.tr('auth.noAccount'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: GSpace.xs),
                  GestureDetector(
                    onTap: () => context.pushReplacement(R.signUp),
                    child: Text(
                      context.tr('auth.signUp'),
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: c.brand),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
