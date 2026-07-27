import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/l10n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/repositories/providers.dart';
import '../../widgets/g_common.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ar = context.s.isArabic;
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);
    final country = ref.watch(countryProvider);
    final city = ref.watch(cityProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('settings.title'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: GSpace.xxxl),
        children: [
          GSettingsGroup(
            title: context.tr('settings.preferences'),
            children: [
              GSettingsTile(
                icon: Icons.translate_rounded,
                label: context.tr('settings.language'),
                value: locale.languageCode == 'ar' ? 'العربية' : 'English',
                onTap: () => ref.read(localeProvider.notifier).state =
                    locale.languageCode == 'ar'
                        ? const Locale('en')
                        : const Locale('ar'),
              ),
              GSettingsTile(
                icon: Icons.dark_mode_outlined,
                label: context.tr('settings.theme'),
                value: context.tr(switch (themeMode) {
                  ThemeMode.light => 'settings.themeLight',
                  ThemeMode.dark => 'settings.themeDark',
                  ThemeMode.system => 'settings.themeSystem',
                },),
                onTap: () => _pickTheme(context, ref),
              ),
              GSettingsTile(
                icon: Icons.public_rounded,
                label: context.tr('settings.country'),
                value: '${country.flag} ${city.name(ar)}',
                onTap: () => context.push(R.onbLocation),
              ),
              GSettingsTile(
                icon: Icons.payments_outlined,
                label: context.tr('settings.currency'),
                value: country.currency.code,
              ),
              GSettingsTile(
                icon: Icons.notifications_none_rounded,
                label: context.tr('settings.notifications'),
                onTap: () => context.push(R.settingsNotifications),
              ),
            ],
          ),

          GSettingsGroup(
            title: context.tr('settings.safety'),
            children: [
              GSettingsTile(
                icon: Icons.lock_outline_rounded,
                label: context.tr('settings.security'),
                onTap: () => context.push(R.settingsSecurity),
              ),
              GSettingsTile(
                icon: Icons.emergency_outlined,
                label: context.tr('settings.emergency'),
                onTap: () => context.push(R.settingsEmergency),
              ),
              GSettingsTile(
                icon: Icons.block_rounded,
                label: context.tr('settings.blocked'),
                onTap: () {},
              ),
              GSettingsTile(
                icon: Icons.health_and_safety_outlined,
                label: context.tr('settings.safetyCenter'),
                onTap: () => context.push(R.safety),
              ),
            ],
          ),

          // -------------------------------------------------------------------
          // لوحة المراجعة — بتظهر للطاقم بس.
          //
          // الإخفاء ده **تحسين عرض مش حماية**: القاعدة هي اللي بترفض
          // أي نداء من غير الطاقم، حتى لو حد وصل للمسار بأي طريقة.
          // -------------------------------------------------------------------
          if (ref.watch(amIStaffProvider).valueOrNull ?? false)
            GSettingsGroup(
              title: context.tr('mod.title'),
              children: [
                GSettingsTile(
                  icon: Icons.rule_rounded,
                  label: context.tr('mod.title'),
                  onTap: () => context.push(R.modQueue),
                ),
              ],
            ),

          GSettingsGroup(
            title: context.tr('settings.support'),
            children: [
              GSettingsTile(
                icon: Icons.help_outline_rounded,
                label: context.tr('settings.help'),
                onTap: () {},
              ),
              GSettingsTile(
                icon: Icons.description_outlined,
                label: context.tr('settings.terms'),
                onTap: () {},
              ),
              GSettingsTile(
                icon: Icons.privacy_tip_outlined,
                label: context.tr('settings.privacy'),
                onTap: () {},
              ),
              GSettingsTile(
                icon: Icons.info_outline_rounded,
                label: context.tr('settings.version'),
                value: '0.1.0',
              ),
            ],
          ),

          GSettingsGroup(
            title: context.tr('settings.account'),
            children: [
              GSettingsTile(
                icon: Icons.logout_rounded,
                label: context.tr('auth.signOut'),
                danger: true,
                trailing: const SizedBox.shrink(),
                onTap: () => _signOut(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// تسجيل الخروج.
  ///
  /// الترتيب مهم: **بنشيل رمز الجهاز الأول**، وبعدين نقفل الجلسة.
  ///
  /// لو عكسنا، النداء اللي بيشيل الرمز بيبقى من غير جلسة فبيفشل —
  /// وإشعارات الحساب القديم بتفضل توصل للجهاز بعد ما صاحبه خرج،
  /// وممكن يشوفها حد تاني.
  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(pushRepositoryProvider).unregisterDevice();
    await ref.read(authRepositoryProvider).signOut();
    if (context.mounted) context.go(R.auth);
  }

  Future<void> _pickTheme(BuildContext context, WidgetRef ref) async {
    final c = context.colors;
    final current = ref.read(themeModeProvider);

    final picked = await showModalBottomSheet<ThemeMode>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: GRadius.sheet),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: GSpace.lg),
            Text(
              context.tr('settings.theme'),
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: GSpace.md),
            for (final mode in ThemeMode.values)
              ListTile(
                leading: Icon(switch (mode) {
                  ThemeMode.light => Icons.light_mode_outlined,
                  ThemeMode.dark => Icons.dark_mode_outlined,
                  ThemeMode.system => Icons.brightness_auto_outlined,
                },),
                title: Text(context.tr(switch (mode) {
                  ThemeMode.light => 'settings.themeLight',
                  ThemeMode.dark => 'settings.themeDark',
                  ThemeMode.system => 'settings.themeSystem',
                },),),
                trailing: mode == current
                    ? Icon(Icons.check_rounded, color: c.brand)
                    : null,
                onTap: () => Navigator.of(ctx).pop(mode),
              ),
            const SizedBox(height: GSpace.lg),
          ],
        ),
      ),
    );

    if (picked != null) {
      ref.read(themeModeProvider.notifier).state = picked;
    }
  }
}
