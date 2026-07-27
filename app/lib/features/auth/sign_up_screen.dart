import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/l10n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/security/attempt_guard.dart';
import '../../core/security/password_policy.dart';
import '../../core/security/validators.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/repositories/providers.dart';
import '../../widgets/g_button.dart';
import '../../widgets/g_common.dart';
import '../../widgets/g_text_field.dart';

/// شاشة إنشاء الحساب.
///
/// طبقات الأمان المطبقة هنا:
///
/// 1. سياسة كلمة سر بـ 7 شروط ومقياس قوة حي
/// 2. منع كلمات السر الشائعة والمتسلسلة والمحتوية على بيانات شخصية
/// 3. تباطؤ تصاعدي بعد المحاولات الفاشلة
/// 4. تأكيد صريح للسن والشروط — مطلوب قانونياً
/// 5. رسائل خطأ عامة عشان ما نكشفش إذا كان البريد مسجل أو لأ
///
/// كل ده **تجربة استخدام**. التحقق الحقيقي بيتكرر على الخادم بالكامل.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _guard = AttemptGuard();

  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;

  bool _acceptedTerms = false;
  bool _confirmedAge = false;
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
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _canSubmit => _acceptedTerms && _confirmedAge && !_guard.isLocked;

  Future<void> _submit() async {
    final nameError = Validators.displayName(_name.text);
    final emailError = Validators.email(_email.text);

    final check = PasswordPolicy.evaluate(
      _password.text,
      email: _email.text,
      displayName: _name.text,
    );

    final passwordError = check.isAcceptable ? null : 'auth.err.weakPassword';
    final confirmError =
        _password.text == _confirm.text ? null : 'pw.mismatch';

    setState(() {
      _nameError = nameError;
      _emailError = emailError;
      _passwordError = passwordError;
      _confirmError = confirmError;
    });

    if (nameError != null ||
        emailError != null ||
        passwordError != null ||
        confirmError != null) {
      _guard.recordFailure();
      return;
    }

    setState(() => _loading = true);

    final result = await ref.read(authRepositoryProvider).signUp(
          email: _email.text,
          password: _password.text,
          displayName: _name.text,
        );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.isOk) {
      _guard.recordFailure();
      setState(() => _emailError = result.error);
      return;
    }

    _guard.recordSuccess();
    ref.read(authStageProvider.notifier).state = AuthStage.needsProfile;

    if (mounted) {
      context.push(
        '${R.otp}?type=email&target=${Uri.encodeComponent(_email.text)}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('auth.signUpTitle'))),
      body: SafeArea(
        child: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              GSpace.screenH,
              GSpace.sm,
              GSpace.screenH,
              GSpace.xxxl,
            ),
            children: [
              GTextField(
                label: context.tr('setup.displayName'),
                controller: _name,
                errorKey: _nameError,
                prefixIcon: Icons.person_outline_rounded,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                maxLength: 40,
                onChanged: (_) => setState(() => _nameError = null),
              ),
              const SizedBox(height: GSpace.xl),

              GTextField(
                label: context.tr('auth.email'),
                controller: _email,
                hint: context.tr('auth.emailHint'),
                errorKey: _emailError,
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                onChanged: (_) => setState(() => _emailError = null),
              ),
              const SizedBox(height: GSpace.xl),

              GPasswordField(
                label: context.tr('auth.password'),
                controller: _password,
                email: _email.text,
                displayName: _name.text,
                errorKey: _passwordError,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() => _passwordError = null),
              ),
              const SizedBox(height: GSpace.xl),

              GPasswordField(
                label: context.tr('auth.passwordConfirm'),
                controller: _confirm,
                showMeter: false,
                errorKey: _confirmError,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() => _confirmError = null),
              ),
              const SizedBox(height: GSpace.xxl),

              _CheckRow(
                value: _confirmedAge,
                onChanged: (v) => setState(() => _confirmedAge = v),
                label: context.tr('auth.age'),
              ),
              const SizedBox(height: GSpace.md),
              _CheckRow(
                value: _acceptedTerms,
                onChanged: (v) => setState(() => _acceptedTerms = v),
                label: context.tr('auth.terms'),
              ),

              if (_guard.isLocked) ...[
                const SizedBox(height: GSpace.lg),
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
                label: context.tr('auth.signUp'),
                loading: _loading,
                onPressed: _canSubmit ? _submit : null,
              ),

              const SizedBox(height: GSpace.lg),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      context.tr('auth.hasAccount'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: GSpace.xs),
                    GestureDetector(
                      onTap: () => context.pushReplacement(R.signIn),
                      child: Text(
                        context.tr('auth.signIn'),
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: c.brand),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: GDuration.fast,
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: value ? c.brand : Colors.transparent,
              borderRadius: GRadius.brXs,
              border: Border.all(
                color: value ? c.brand : c.borderStrong,
                width: 1.6,
              ),
            ),
            child: value
                ? Icon(Icons.check_rounded, size: 15, color: c.onBrand)
                : null,
          ),
          const SizedBox(width: GSpace.md),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: c.textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
