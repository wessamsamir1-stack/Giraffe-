import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/catalog/categories.dart';
import '../../data/mock/mock_data.dart';
import '../../widgets/g_button.dart';
import '../../widgets/g_common.dart';

/// قائمة الرغبات.
///
/// مش feature جانبي — دي **مدخل محرك المطابقة**.
/// كل صفقة بتظهر في الـ deck اتولدت من هنا.
class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ar = context.s.isArabic;
    final items = Mock.wishlist;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('wish.title')),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: GSpace.lg),
            child: Center(
              child: Text(
                context.trf('wish.limit', {
                  'n': items.length,
                  'max': kMaxWishlistItems,
                }),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
      body: items.isEmpty
          ? GEmptyState(
              icon: Icons.favorite_outline_rounded,
              tone: GEmptyTone.brand,
              title: context.tr('wish.empty.title'),
              body: context.tr('wish.empty.body'),
              actionLabel: context.tr('wish.add'),
              onAction: () {},
            )
          : ListView(
              padding: const EdgeInsets.all(GSpace.screenH),
              children: [
                GNotice(
                  icon: Icons.auto_awesome_rounded,
                  text: ar
                      ? 'كل ما ضيفت رغبة، كل ما زادت الصفقات اللي هنعرضها عليك. دي أهم قائمة في حسابك.'
                      : 'Every wish you add widens the trades we can show you. This is the most important list in your account.',
                ),
                const SizedBox(height: GSpace.lg),

                for (final wish in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: GSpace.md),
                    child: _WishRow(
                      categoryId: wish.categoryId,
                      subCategoryId: wish.subCategoryId,
                      keyword: wish.keyword,
                      maxValue: wish.maxValue,
                    ),
                  ),

                const SizedBox(height: GSpace.md),
                GButton(
                  label: context.tr('wish.add'),
                  icon: Icons.add_rounded,
                  style: GButtonStyle.ghost,
                  onPressed: items.length >= kMaxWishlistItems ? null : () {},
                ),
              ],
            ),
    );
  }
}

class _WishRow extends StatelessWidget {
  const _WishRow({
    required this.categoryId,
    required this.subCategoryId,
    required this.keyword,
    required this.maxValue,
  });

  final String categoryId;
  final String? subCategoryId;
  final String keyword;
  final double? maxValue;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ar = context.s.isArabic;
    final category = Categories.byId(categoryId);

    final matchingSubs = subCategoryId == null
        ? const <SubCategory>[]
        : category.subs.where((s) => s.id == subCategoryId).toList();
    final sub = matchingSubs.isEmpty ? null : matchingSubs.first;

    return GSurface(
      padding: const EdgeInsets.all(GSpace.md),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: c.brand.withOpacity(0.10),
              borderRadius: GRadius.brSm,
            ),
            child: Icon(category.icon, size: 21, color: c.brand),
          ),
          const SizedBox(width: GSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  keyword.isNotEmpty ? keyword : category.name(ar),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    category.name(ar),
                    if (sub != null) sub.name(ar),
                    if (maxValue != null)
                      '${context.tr('wish.maxValue')}: ${maxValue!.round()}',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.notifications_active_outlined,
              size: 19,
              color: c.success,
            ),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 19, color: c.textTertiary),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
