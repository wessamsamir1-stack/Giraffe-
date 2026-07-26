import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/catalog/categories.dart';
import '../../data/mock/mock_data.dart';
import '../../widgets/g_common.dart';
import '../../widgets/item_card.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  String? _sub;
  int _sortIndex = 0;

  static const _sortKeys = [
    'market.sortBestMatch',
    'market.sortNewest',
    'market.sortNearest',
    'market.sortValueDesc',
    'market.sortValueAsc',
  ];

  @override
  Widget build(BuildContext context) {
    final ar = context.s.isArabic;
    final category = Categories.byId(widget.categoryId);

    final items = Mock.marketItems
        .where((i) => i.categoryId == widget.categoryId)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(category.name(ar)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => context.push(R.search),
          ),
        ],
      ),
      body: Column(
        children: [
          // الأقسام الفرعية
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: GSpace.screenH),
              itemCount: category.subs.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: GSpace.sm),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return GChip(
                    label: ar ? 'الكل' : 'All',
                    selected: _sub == null,
                    onTap: () => setState(() => _sub = null),
                  );
                }
                final sub = category.subs[i - 1];
                return GChip(
                  label: sub.name(ar),
                  selected: _sub == sub.id,
                  onTap: () => setState(() => _sub = sub.id),
                );
              },
            ),
          ),

          // شريط النتائج والترتيب
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: GSpace.screenH,
              vertical: GSpace.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.trf('market.resultsCount', {'n': items.length}),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                GChip(
                  label: context.tr(_sortKeys[_sortIndex]),
                  icon: Icons.swap_vert_rounded,
                  onTap: () => _pickSort(context),
                ),
              ],
            ),
          ),

          Expanded(
            child: items.isEmpty
                ? GEmptyState(
                    icon: category.icon,
                    tone: GEmptyTone.brand,
                    title: context.tr('market.emptyCategory'),
                    body: context.tr('market.emptyCategoryBody'),
                    actionLabel: context.tr('items.add'),
                    onAction: () => context.push(R.addItem),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      GSpace.screenH,
                      0,
                      GSpace.screenH,
                      GSpace.xxxl,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: GSpace.md,
                      mainAxisSpacing: GSpace.md,
                      childAspectRatio: 0.66,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, i) => ItemCard(
                      item: items[i],
                      onTap: () => context.push(R.item(items[i].id)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickSort(BuildContext context) async {
    final c = context.colors;
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: GRadius.sheet),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: GSpace.lg),
            Text(
              context.tr('common.sort'),
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: GSpace.md),
            for (var i = 0; i < _sortKeys.length; i++)
              ListTile(
                title: Text(context.tr(_sortKeys[i])),
                trailing: i == _sortIndex
                    ? Icon(Icons.check_rounded, color: c.brand)
                    : null,
                onTap: () => Navigator.of(ctx).pop(i),
              ),
            const SizedBox(height: GSpace.lg),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _sortIndex = picked);
  }
}
