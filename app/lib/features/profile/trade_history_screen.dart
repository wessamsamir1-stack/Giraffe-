import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/catalog/categories.dart';
import '../../data/models/models.dart';
import '../../data/repositories/providers.dart';
import '../../widgets/g_common.dart';

class TradeHistoryScreen extends ConsumerWidget {
  const TradeHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;

    // السجل = النشط + المؤرشف مع بعض
    final active = ref.watch(matchesProvider(false)).valueOrNull ?? const [];
    final archived = ref.watch(matchesProvider(true)).valueOrNull ?? const [];
    final history = [...active, ...archived];

    if (history.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('profile.history'))),
        body: GEmptyState(
          icon: Icons.history_rounded,
          title: context.tr('matches.empty.title'),
          body: context.tr('matches.empty.body'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('profile.history'))),
      body: ListView.separated(
        padding: const EdgeInsets.all(GSpace.screenH),
        itemCount: history.length,
        separatorBuilder: (_, __) => const SizedBox(height: GSpace.md),
        itemBuilder: (context, i) {
          final match = history[i];
          final done = match.stage == TradeStage.completed;

          return GSurface(
            onTap: () => context.push(R.room(match.id)),
            padding: const EdgeInsets.all(GSpace.md),
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: GImagePlaceholder(
                        seed: match.myItem.imageSeed,
                        icon: Categories.byId(match.myItem.categoryId).icon,
                        radius: GRadius.brSm,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: GSpace.sm,
                      ),
                      child: Icon(
                        Icons.swap_horiz_rounded,
                        size: 18,
                        color: c.brand,
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: GImagePlaceholder(
                        seed: match.theirItem.imageSeed,
                        icon: Categories.byId(match.theirItem.categoryId).icon,
                        radius: GRadius.brSm,
                      ),
                    ),
                    const SizedBox(width: GSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            match.other.displayName,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            match.lastActivity,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    GChip(
                      label: context.tr(match.stage.labelKey),
                      color: done ? c.success : c.textSecondary,
                      background:
                          (done ? c.success : c.textSecondary).withOpacity(0.12),
                      dense: true,
                    ),
                  ],
                ),
                const SizedBox(height: GSpace.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${match.myItem.title}  ↔  ${match.theirItem.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
