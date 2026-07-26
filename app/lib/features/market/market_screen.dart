import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/l10n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/catalog/categories.dart';
import '../../data/mock/mock_data.dart';
import '../../widgets/g_button.dart';
import '../../widgets/g_common.dart';
import '../../widgets/item_card.dart';

/// السوق المفتوح — التبويب الأول.
///
/// الغرض: البحث المقصود. المستخدم اللي عارف هو عايز إيه بالظبط
/// مايتحبسش في السحب العشوائي.
class MarketScreen extends ConsumerWidget {
  const MarketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final ar = context.s.isArabic;
    final city = ref.watch(cityProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Header(cityName: city.name(ar))),

            // الأقسام المميزة
            SliverToBoxAdapter(
              child: GSectionHeader(
                title: context.tr('market.categories'),
                actionLabel: context.tr('common.seeAll'),
                onAction: () => context.push(R.allCategories),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 104,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: GSpace.screenH,
                  ),
                  itemCount: Categories.featured.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: GSpace.md),
                  itemBuilder: (context, i) {
                    if (i == Categories.featured.length) {
                      return _MoreCategoriesTile(
                        onTap: () => context.push(R.allCategories),
                      );
                    }
                    final category = Categories.featured[i];
                    return SizedBox(
                      width: 92,
                      child: CategoryTile(
                        category: category,
                        onTap: () => context.push(R.category(category.id)),
                      ),
                    );
                  },
                ),
              ),
            ),

            // من قائمة رغباتك
            SliverToBoxAdapter(
              child: GSectionHeader(
                title: context.tr('market.wishlistMatches'),
                subtitle: context.tr('wish.notify'),
                icon: Icons.favorite_rounded,
                actionLabel: context.tr('common.seeAll'),
                onAction: () => context.push(R.wishlist),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 268,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: GSpace.screenH,
                  ),
                  itemCount: 3,
                  separatorBuilder: (_, __) => const SizedBox(width: GSpace.md),
                  itemBuilder: (context, i) {
                    final item = Mock.marketItems[i];
                    return SizedBox(
                      width: 176,
                      child: ItemCard(
                        item: item,
                        onTap: () => context.push(R.item(item.id)),
                      ),
                    );
                  },
                ),
              ),
            ),

            // خدمات مقابل خدمات
            SliverToBoxAdapter(
              child: GSectionHeader(
                title: context.tr('market.services'),
                subtitle: ar
                    ? 'قايض مهارتك بمهارة — من غير شحن ولا مخاطر منتج'
                    : 'Trade a skill for a skill — no shipping, no product risk',
                icon: Icons.swap_horiz_rounded,
                actionLabel: context.tr('common.seeAll'),
                onAction: () => context.push(R.category('services')),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: GSpace.screenH,
                ),
                child: ItemRow(
                  item: Mock.designService,
                  showStatus: false,
                  onTap: () => context.push(R.item(Mock.designService.id)),
                ),
              ),
            ),

            // الأحدث
            SliverToBoxAdapter(
              child: GSectionHeader(
                title: context.tr('market.newest'),
                icon: Icons.auto_awesome_rounded,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                GSpace.screenH,
                0,
                GSpace.screenH,
                GSpace.xxxl,
              ),
              sliver: SliverGrid(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: GSpace.md,
                  mainAxisSpacing: GSpace.md,
                  childAspectRatio: 0.66,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final item = Mock.marketItems[i];
                    return ItemCard(
                      item: item,
                      onTap: () => context.push(R.item(item.id)),
                    );
                  },
                  childCount: Mock.marketItems.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.cityName});

  final String cityName;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        GSpace.screenH,
        GSpace.md,
        GSpace.screenH,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('market.title'),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 14,
                          color: c.brand,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          cityName,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              GIconButton(
                icon: Icons.notifications_none_rounded,
                bordered: true,
                onPressed: () => context.push(R.notifications),
              ),
            ],
          ),
          const SizedBox(height: GSpace.lg),

          // البحث
          GestureDetector(
            onTap: () => context.push(R.search),
            child: Container(
              height: GSize.fieldHeight,
              padding: const EdgeInsets.symmetric(horizontal: GSpace.lg),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: GRadius.brMd,
                border: Border.all(color: c.border, width: 1.3),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    size: GSize.iconMd,
                    color: c.textTertiary,
                  ),
                  const SizedBox(width: GSpace.md),
                  Expanded(
                    child: Text(
                      context.tr('market.searchHint'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: c.textTertiary),
                    ),
                  ),
                  Icon(
                    Icons.tune_rounded,
                    size: GSize.iconMd,
                    color: c.brand,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreCategoriesTile extends StatelessWidget {
  const _MoreCategoriesTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: 92,
      child: GSurface(
        onTap: onTap,
        padding: const EdgeInsets.all(GSpace.sm),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: GRadius.brMd,
              ),
              child: Icon(Icons.grid_view_rounded, size: 22, color: c.textSecondary),
            ),
            const SizedBox(height: GSpace.sm),
            Text(
              context.tr('market.allCategories'),
              textAlign: TextAlign.center,
              maxLines: 2,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}
