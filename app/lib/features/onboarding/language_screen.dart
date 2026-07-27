import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/l10n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../widgets/g_button.dart';
import '../../widgets/g_common.dart';

class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: GSpace.screenH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: GSpace.lg),
              Text(
                context.tr('onb.language.title'),
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: GSpace.sm),
              Text(
                context.tr('onb.language.body'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: GSpace.xxxl),
              _LanguageOption(
                title: 'العربية',
                subtitle: 'Arabic',
                selected: locale.languageCode == 'ar',
                onTap: () => ref.read(localeProvider.notifier).state =
                    const Locale('ar'),
              ),
              const SizedBox(height: GSpace.md),
              _LanguageOption(
                title: 'English',
                subtitle: 'الإنجليزية',
                selected: locale.languageCode == 'en',
                onTap: () => ref.read(localeProvider.notifier).state =
                    const Locale('en'),
              ),
              const Spacer(),
              GButton(
                label: context.tr('common.continue'),
                onPressed: () => context.go(R.auth),
              ),
              const SizedBox(height: GSpace.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GSurface(
      onTap: onTap,
      color: selected ? c.brandSoft : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          AnimatedContainer(
            duration: GDuration.fast,
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? c.brand : Colors.transparent,
              border: Border.all(
                color: selected ? c.brand : c.borderStrong,
                width: 1.8,
              ),
            ),
            child: selected
                ? Icon(Icons.check_rounded, size: 15, color: c.onBrand)
                : null,
          ),
        ],
      ),
    );
  }
}
