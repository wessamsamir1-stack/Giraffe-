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
import '../../widgets/g_button.dart';
import '../../widgets/g_common.dart';
import '../../widgets/item_card.dart';

class ItemDetailScreen extends ConsumerStatefulWidget {
  const ItemDetailScreen({super.key, required this.itemId});

  final String itemId;

  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen> {
  final _gallery = PageController();
  int _page = 0;

  @override
  void dispose() {
    _gallery.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ar = context.s.isArabic;

    final async = ref.watch(itemProvider(widget.itemId));
    final item = async.valueOrNull;

    if (item == null) {
      return Scaffold(
        appBar: AppBar(),
        body: async.hasError
            ? GEmptyState(
                icon: Icons.cloud_off_rounded,
                title: context.tr('common.error'),
                body: context.tr('common.errorBody'),
                actionLabel: context.tr('common.retry'),
                onAction: () => ref.invalidate(itemProvider(widget.itemId)),
              )
            : const Center(child: CircularProgressIndicator()),
      );
    }

    final ownerAsync = ref.watch(ownerProvider(item.ownerId));
    final owner = ownerAsync.valueOrNull;
    final category = Categories.byId(item.categoryId);
    final isMine = item.ownerId == ref.watch(myUserIdProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: c.surface,
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: () {},
              ),
              if (!isMine)
                IconButton(
                  icon: const Icon(Icons.flag_outlined),
                  onPressed: () => context.push(R.report('item', item.id)),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _gallery,
                    itemCount: item.photoCount,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (context, i) => GImagePlaceholder(
                      seed: item.imageSeed + i,
                      icon: category.icon,
                      radius: BorderRadius.zero,
                    ),
                  ),
                  PositionedDirectional(
                    bottom: GSpace.lg,
                    start: 0,
                    end: 0,
                    child: Center(
                      child: GProgressDots(
                        count: item.photoCount,
                        index: _page,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(GSpace.screenH),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    ItemStatusChip(status: item.status, dense: false),
                  ],
                ),
                const SizedBox(height: GSpace.md),
                PriceRange(item: item, showSource: true),

                const SizedBox(height: GSpace.lg),
                Wrap(
                  spacing: GSpace.sm,
                  runSpacing: GSpace.sm,
                  children: [
                    GChip(label: category.name(ar), icon: category.icon),
                    GChip(label: context.tr(item.condition.labelKey)),
                    if (item.brand.isNotEmpty) GChip(label: item.brand),
                    GChip(
                      label: item.country.cities
                          .firstWhere(
                            (city) => city.id == item.cityId,
                            orElse: () => item.country.cities.first,
                          )
                          .name(ar),
                      icon: Icons.location_on_outlined,
                    ),
                  ],
                ),

                const SizedBox(height: GSpace.xl),
                if (item.description.isNotEmpty) ...[
                  Text(
                    context.tr('item.description'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: GSpace.sm),
                  Text(
                    item.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: GSpace.xl),
                ],

                // بيقايض بإيه
                Text(
                  context.tr('item.tradeFor'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: GSpace.sm),
                Wrap(
                  spacing: GSpace.sm,
                  runSpacing: GSpace.sm,
                  children: [
                    for (final id in item.wantedCategoryIds)
                      GChip(
                        label: Categories.byId(id).name(ar),
                        icon: Categories.byId(id).icon,
                        color: c.brand,
                        background: c.brandSoft,
                      ),
                  ],
                ),

                const SizedBox(height: GSpace.xl),
                Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.favorite_rounded,
                        value: '${item.interestedCount}',
                        label: context.trf('item.interested', {'n': ''}).trim(),
                      ),
                    ),
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.bookmark_rounded,
                        value: '${item.wishlistCount}',
                        label: context.tr('wish.title'),
                      ),
                    ),
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.photo_library_outlined,
                        value: '${item.photoCount}',
                        label: context.tr('add.photos.title'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: GSpace.xl),
                // المالك
                if (owner != null)
                GSurface(
                  onTap: isMine
                      ? null
                      : () => context.push(R.publicProfile(owner.username)),
                  child: Row(
                    children: [
                      GAvatar(
                        name: owner.displayName,
                        seed: owner.avatarSeed,
                        size: GSize.avatarMd,
                      ),
                      const SizedBox(width: GSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              owner.displayName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  size: 14,
                                  color: c.warning,
                                ),
                                Text(
                                  ' ${owner.rating} · ${owner.completedTrades} ${context.tr('profile.trades')}',
                                  style:
                                      Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      TrustBadge(level: owner.trustLevel),
                    ],
                  ),
                ),

                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),

      bottomNavigationBar: isMine
          ? null
          : Container(
              padding: const EdgeInsets.all(GSpace.screenH),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    GIconButton(
                      icon: Icons.bookmark_border_rounded,
                      size: GSize.buttonHeight,
                      bordered: true,
                      onPressed: () {},
                    ),
                    const SizedBox(width: GSpace.md),
                    Expanded(
                      child: GButton(
                        label: context.tr('item.openTrade'),
                        icon: Icons.swap_horiz_rounded,
                        onPressed: () => context.push(R.deck),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Icon(icon, size: 18, color: c.textTertiary),
        const SizedBox(height: GSpace.xs),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
