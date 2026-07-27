import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/models/models.dart';
import '../../data/repositories/providers.dart';
import '../../widgets/g_button.dart';
import '../../widgets/g_common.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(myProfileProvider);
    final me = async.valueOrNull;

    if (me == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(context.tr('profile.title')),
          automaticallyImplyLeading: false,
        ),
        body: async.hasError
            ? GEmptyState(
                icon: Icons.cloud_off_rounded,
                title: context.tr('common.error'),
                body: context.tr('common.errorBody'),
                actionLabel: context.tr('common.retry'),
                onAction: () => ref.invalidate(myProfileProvider),
              )
            : const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('profile.title')),
        automaticallyImplyLeading: false,
        actions: [
          _BellWithBadge(
            count: ref.watch(unreadCountProvider).valueOrNull ?? 0,
            onTap: () => context.push(R.notifications),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(R.settings),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: GSpace.xxxl),
        children: [
          Padding(
            padding: const EdgeInsets.all(GSpace.screenH),
            child: Column(
              children: [
                GAvatar(
                  name: me.displayName,
                  seed: me.avatarSeed,
                  size: GSize.avatarXl,
                  ring: true,
                ),
                const SizedBox(height: GSpace.md),
                Text(
                  me.displayName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  '@${me.username}',
                  style: Theme.of(context).textTheme.bodySmall,
                  textDirection: TextDirection.ltr,
                ),
                const SizedBox(height: GSpace.sm),
                TrustBadge(level: me.trustLevel),

                if (me.bio.isNotEmpty) ...[
                  const SizedBox(height: GSpace.md),
                  Text(
                    me.bio,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],

                const SizedBox(height: GSpace.lg),
                Row(
                  children: [
                    Expanded(
                      child: GButton(
                        label: context.tr('profile.edit'),
                        style: GButtonStyle.ghost,
                        size: GButtonSize.small,
                        onPressed: () => context.push(R.editProfile),
                      ),
                    ),
                    const SizedBox(width: GSpace.sm),
                    Expanded(
                      child: GButton(
                        label: context.tr('profile.viewPublic'),
                        style: GButtonStyle.ghost,
                        size: GButtonSize.small,
                        onPressed: () =>
                            context.push(R.publicProfile(me.username)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // الأرقام
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: GSpace.screenH),
            child: GSurface(
              child: Row(
                children: [
                  Expanded(
                    child: _Stat(
                      value: '${me.completedTrades}',
                      label: context.tr('profile.trades'),
                    ),
                  ),
                  _Sep(),
                  Expanded(
                    child: _Stat(
                      value: me.rating.toStringAsFixed(1),
                      label: context.tr('profile.rating'),
                      icon: Icons.star_rounded,
                      iconColor: c.warning,
                    ),
                  ),
                  _Sep(),
                  Expanded(
                    child: _Stat(
                      value: '${me.responseHours}h',
                      label: context.tr('profile.responseTime'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // شرح مستوى الثقة — الشفافية بتمنع الشكاوى
          Padding(
            padding: const EdgeInsets.all(GSpace.screenH),
            child: GSurface(
              color: c.brandSoft,
              bordered: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 18, color: c.brand),
                      const SizedBox(width: GSpace.sm),
                      Text(
                        context.tr('trust.explainTitle'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: GSpace.sm),
                  Text(
                    context.tr('trust.explainBody'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: GSpace.md),
                  for (final level in [
                    TrustLevel.verified,
                    TrustLevel.trusted,
                    TrustLevel.elite,
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: GSpace.xs),
                      child: Row(
                        children: [
                          TrustBadge(level: level, dense: true),
                          const SizedBox(width: GSpace.sm),
                          Expanded(
                            child: Text(
                              context.tr(switch (level) {
                                TrustLevel.verified => 'trust.reqVerified',
                                TrustLevel.trusted => 'trust.reqTrusted',
                                _ => 'trust.reqElite',
                              },),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          GSettingsGroup(
            title: context.tr('profile.title'),
            children: [
              GSettingsTile(
                icon: Icons.star_outline_rounded,
                label: context.tr('profile.reviews'),
                value: '${me.ratingCount}',
                onTap: () => context.push(R.reviews),
              ),
              GSettingsTile(
                icon: Icons.history_rounded,
                label: context.tr('profile.history'),
                onTap: () => context.push(R.tradeHistory),
              ),
              GSettingsTile(
                icon: Icons.favorite_outline_rounded,
                label: context.tr('wish.title'),
                onTap: () => context.push(R.wishlist),
              ),
              GSettingsTile(
                icon: Icons.health_and_safety_outlined,
                label: context.tr('settings.safetyCenter'),
                onTap: () => context.push(R.safety),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.all(GSpace.screenH),
            child: Text(
              '${context.tr('profile.memberSince')} ${me.memberSinceYear}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// جرس الإشعارات بعدّاد غير المقروء.
class _BellWithBadge extends StatelessWidget {
  const _BellWithBadge({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded),
          onPressed: onTap,
        ),
        if (count > 0)
          PositionedDirectional(
            top: 8,
            end: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: c.danger,
                borderRadius: GRadius.brPill,
                border: Border.all(color: c.background, width: 1.4),
              ),
              child: Text(
                count > 9 ? '9+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    this.icon,
    this.iconColor,
  });

  final String value;
  final String label;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 2),
            ],
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _Sep extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      color: context.colors.border,
    );
  }
}
