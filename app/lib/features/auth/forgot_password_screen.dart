import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/security/validators.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/repositories/providers.dart';
import '../../widgets/g_button.dart';
import '../../widgets/g_common.dart';
import '../../widgets/g_text_field.dart';

/// استعادة كلمة السر.
///
/// قاعدة أمنية: الرسالة بعد الإرسال **واحدة دايماً** سواء البريد
/// مسجّل عندنا أو لأ — عشان مانسمحش بتعداد الحسابات.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  String? _error;
  bool _sent = false;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final error = Validators.email(_email.text);
    setState(() => _error = error);
    if (error != null) return;

    setState(() => _loading = true);
    await ref.read(authRepositoryProvider).requestPasswordReset(_email.text);
    if (!mounted) return;
    // النتيجة واحدة دايماً سواء البريد مسجّل أو لأ — منع تعداد الحسابات
    setState(() {
      _loading = false;
      _sent = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('forgot.title'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            GSpace.screenH,
            GSpace.xl,
            GSpace.screenH,
            GSpace.xxxl,
          ),
          children: [
            if (_sent) ...[
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: c.success.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mark_email_read_outlined,
                  size: 34,
                  color: c.success,
                ),
              ),
              const SizedBox(height: GSpace.xl),
              Text(
                context.tr('forgot.sent'),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: GSpace.xxxl),
              GButton(
                label: context.tr('common.back'),
                onPressed: () => context.pop(),
              ),
            ] else ...[
              Text(
                context.tr('forgot.body'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: GSpace.xxl),
              GTextField(
                label: context.tr('auth.email'),
                controller: _email,
                hint: context.tr('auth.emailHint'),
                errorKey: _error,
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: GSpace.xxl),
              GButton(
                label: context.tr('common.continue'),
                loading: _loading,
                onPressed: _submit,
              ),
              const SizedBox(height: GSpace.xl),
              GNotice(
                icon: Icons.shield_outlined,
                text: context.tr('forgot.sent'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
