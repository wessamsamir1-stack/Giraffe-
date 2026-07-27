import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../widgets/g_button.dart';
import '../../widgets/g_common.dart';

/// إعدادات الأمان.
///
/// ملاحظة على الأولويات: التحقق بخطوتين والقفل بالبصمة **مؤجلين**
/// للمرحلة التانية عن عمد. الخطر الحقيقي في تطبيق مقايضة مش اختراق
/// الحساب — الخطر هو النصب في اللقاء الحقيقي.
///
/// الطبقات دي بتتفعل لما يبقى في التطبيق فلوس فعلاً.
class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  bool _twoFactor = false;
  bool _biometric = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ar = context.s.isArabic;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('settings.security'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: GSpace.xxxl),
        children: [
          Padding(
            padding: const EdgeInsets.all(GSpace.screenH),
            child: GNotice(
              tone: GNoticeTone.success,
              icon: Icons.verified_user_outlined,
              text: ar
                  ? 'حسابك محمي بكلمة سر قوية وبريد موثّق ورقم موبايل موثّق.'
                  : 'Your account is protected by a strong password, a verified email and a verified phone.',
            ),
          ),

          GSettingsGroup(
            title: context.tr('settings.account'),
            children: [
              GSettingsTile(
                icon: Icons.password_rounded,
                label: context.tr('sec.changePassword'),
                onTap: () {},
              ),
              GSettingsTile(
                icon: Icons.devices_rounded,
                label: context.tr('sec.sessions'),
                value: '2',
                onTap: () {},
              ),
              GSettingsTile(
                icon: Icons.logout_rounded,
                label: context.tr('auth.signOutAll'),
                onTap: () {},
              ),
            ],
          ),

          GSettingsGroup(
            title: context.tr('settings.safety'),
            children: [
              GSettingsTile(
                icon: Icons.security_rounded,
                label: context.tr('sec.twoFactor'),
                trailing: Switch(
                  value: _twoFactor,
                  activeColor: c.brand,
                  onChanged: (v) => setState(() => _twoFactor = v),
                ),
              ),
              GSettingsTile(
                icon: Icons.fingerprint_rounded,
                label: context.tr('sec.biometric'),
                trailing: Switch(
                  value: _biometric,
                  activeColor: c.brand,
                  onChanged: (v) => setState(() => _biometric = v),
                ),
              ),
            ],
          ),

          GSettingsGroup(
            title: context.tr('settings.privacy'),
            children: [
              GSettingsTile(
                icon: Icons.download_outlined,
                label: context.tr('sec.exportData'),
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: GSpace.xxl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: GSpace.screenH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('sec.deleteBody'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: GSpace.md),
                GButton(
                  label: context.tr('sec.deleteAccount'),
                  style: GButtonStyle.danger,
                  onPressed: () => _confirmDelete(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final c = context.colors;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: const RoundedRectangleBorder(borderRadius: GRadius.brXl),
        title: Text(context.tr('sec.deleteAccount')),
        content: Text(context.tr('sec.deleteBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.tr('common.cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/auth');
            },
            child: Text(
              context.tr('common.delete'),
              style: TextStyle(color: c.danger),
            ),
          ),
        ],
      ),
    );
  }
}
