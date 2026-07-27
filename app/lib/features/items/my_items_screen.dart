import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/models/models.dart';
import '../../data/repositories/providers.dart';
import '../../widgets/g_common.dart';
import '../../widgets/item_card.dart';

class MyItemsScreen extends ConsumerWidget {
  const MyItemsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(myItemsProvider);

    return switch (async) {
      AsyncLoading() => _shell(context, ref, const _ItemsSkeleton()),
      AsyncError() => _shell(
          context,
          ref,
          GEmptyState(
            icon: Icons.cloud_off_rounded,
            title: context.tr('common.error'),
            body: context.tr('common.errorBody'),
            actionLabel: context.tr('common.retry'),
            onAction: () => ref.invalidate(myItemsProvider),
          ),
        ),
      _ => _shell(context, ref, _body(context, c, async.value ?? const [])),
    };
  }

  Widget _shell(BuildContext context, WidgetRef ref, Widget child) {

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('items.title')),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_outline_rounded),
            tooltip: context.tr('wish.title'),
            onPressed: () => context.push(R.wishlist),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myItemsProvider),
        child: child,
      ),
    );
  }

  Widget _body(BuildContext context, GColors c, List<Item> items) {
    return items.isEmpty
          ? GEmptyState(
              icon: Icons.inventory_2_outlined,
              tone: GEmptyTone.brand,
              title: context.tr('items.empty.title'),
              body: context.tr('items.empty.body'),
              actionLabel: context.tr('items.add'),
              onAction: () => context.push(R.addItem),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                GSpace.screenH,
                GSpace.md,
                GSpace.screenH,
                100,
              ),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StatBox(
                        value: '${items.length}',
                        label: context.tr('items.title'),
                        icon: Icons.inventory_2_rounded,
                      ),
                    ),
                    const SizedBox(width: GSpace.md),
                    Expanded(
                      child: _StatBox(
                        value: '${items.fold<int>(0, (a, b) => a + b.interestedCount)}',
                        label: context.tr('deck.interested'),
                        icon: Icons.favorite_rounded,
                        color: c.danger,
                      ),
                    ),
                    const SizedBox(width: GSpace.md),
                    Expanded(
                      child: _StatBox(
                        value: '${items.fold<int>(0, (a, b) => a + b.wishlistCount)}',
                        label: context.tr('wish.title'),
                        icon: Icons.bookmark_rounded,
                        color: c.info,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: GSpace.xl),
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: GSpace.md),
                    child: ItemRow(
                      item: item,
                      onTap: () => context.push(R.item(item.id)),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: c.textTertiary,
                      ),
                    ),
                  ),
              ],
            );
  }
}

class _ItemsSkeleton extends StatelessWidget {
  const _ItemsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(GSpace.screenH),
      children: [
        const GSkeleton(height: 74, radius: GRadius.brLg),
        const SizedBox(height: GSpace.xl),
        for (var i = 0; i < 3; i++)
          const Padding(
            padding: EdgeInsets.only(bottom: GSpace.md),
            child: GSkeleton(height: 92, radius: GRadius.brLg),
          ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.value,
    required this.label,
    required this.icon,
    this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = color ?? c.brand;

    return GSurface(
      padding: const EdgeInsets.symmetric(
        vertical: GSpace.md,
        horizontal: GSpace.sm,
      ),
      child: Column(
        children: [
          Icon(icon, size: 19, color: tone),
          const SizedBox(height: GSpace.xs),
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
