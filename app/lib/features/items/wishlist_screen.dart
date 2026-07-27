import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_state.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/catalog/categories.dart';
import '../../data/models/models.dart';
import '../../data/repositories/providers.dart';
import '../../widgets/g_button.dart';
import '../../widgets/g_common.dart';

/// قائمة الرغبات.
///
/// مش feature جانبي — دي **مدخل محرك المطابقة**.
/// كل صفقة بتظهر في الـ deck اتولدت من هنا.
class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  /// إضافة رغبة من قائمة الأقسام.
  Future<void> _addWish(BuildContext context, WidgetRef ref) async {
    final ar = context.s.isArabic;
    final c = context.colors;

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: c.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: GRadius.sheet),
      builder: (ctx) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.8,
          child: Column(
            children: [
              const SizedBox(height: GSpace.lg),
              Text(
                context.tr('wish.add'),
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: GSpace.md),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(GSpace.lg),
                  children: [
                    for (final category in Categories.all)
                      ListTile(
                        leading: Icon(category.icon, color: c.brand),
                        title: Text(category.name(ar)),
                        onTap: () => Navigator.of(ctx).pop(category.id),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (picked == null) return;

    final error = await ref
        .read(wishlistRepositoryProvider)
        .add(WishItem(id: '', categoryId: picked));

    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(error))),
      );
      return;
    }
    ref.invalidate(myWishlistProvider);
    ref.invalidate(deckProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ar = context.s.isArabic;
    final async = ref.watch(myWishlistProvider);
    final items = async.valueOrNull ?? const <WishItem>[];

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
              onAction: () => _addWish(context, ref),
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
                      notify: wish.notify,
                      onToggleNotify: () async {
                        await ref
                            .read(wishlistRepositoryProvider)
                            .setNotify(wish.id, !wish.notify);
                        ref.invalidate(myWishlistProvider);
                      },
                      onRemove: () async {
                        await ref
                            .read(wishlistRepositoryProvider)
                            .remove(wish.id);
                        ref.invalidate(myWishlistProvider);
                        ref.invalidate(deckProvider);
                      },
                    ),
                  ),

                const SizedBox(height: GSpace.md),
                GButton(
                  label: context.tr('wish.add'),
                  icon: Icons.add_rounded,
                  style: GButtonStyle.ghost,
                  onPressed: items.length >= kMaxWishlistItems
                      ? null
                      : () => _addWish(context, ref),
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
    required this.notify,
    required this.onToggleNotify,
    required this.onRemove,
  });

  final String categoryId;
  final String? subCategoryId;
  final String keyword;
  final double? maxValue;
  final bool notify;
  final VoidCallback onToggleNotify;
  final VoidCallback onRemove;

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
              notify
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_off_outlined,
              size: 19,
              color: notify ? c.success : c.textTertiary,
            ),
            onPressed: onToggleNotify,
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 19, color: c.textTertiary),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
