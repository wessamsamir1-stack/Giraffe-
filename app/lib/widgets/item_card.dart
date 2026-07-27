import 'package:flutter/material.dart';

import '../core/l10n/strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../data/catalog/categories.dart';
import '../data/models/models.dart';
import 'g_common.dart';

/// نطاق القيمة التقديري.
///
/// قاعدة ثابتة: **ممنوع عرض رقم واحد قاطع**.
/// لو ثقة النموذج أقل من 60% ما نعرضش تقدير خالص.
class PriceRange extends StatelessWidget {
  const PriceRange({
    super.key,
    required this.item,
    this.compact = false,
    this.showSource = false,
  });

  final Item item;
  final bool compact;
  final bool showSource;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ar = context.s.isArabic;
    final currency = item.country.currency;

    if (!item.hasReliableEstimate) {
      return Text(
        context.tr('price.lowConfidence'),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: c.textTertiary,
              fontStyle: FontStyle.italic,
            ),
      );
    }

    final range = compact
        ? '${currency.formatCompact(item.valueMin, ar: ar)} – ${currency.formatCompact(item.valueMax, ar: ar)}'
        : '${currency.formatCompact(item.valueMin, ar: ar)} – ${currency.format(item.valueMax, ar: ar)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          range,
          style: (compact
                  ? Theme.of(context).textTheme.titleSmall
                  : Theme.of(context).textTheme.titleLarge)
              ?.copyWith(color: c.textPrimary),
          textDirection: TextDirection.ltr,
        ),
        if (showSource) ...[
          const SizedBox(height: 2),
          Text(
            context.trf('price.basedOn', {
              'n': item.comparableCount,
              'market': item.country.name(ar),
            }),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: GSpace.xs),
          Text(
            context.tr('price.disclaimer'),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: c.textTertiary, fontSize: 11.5),
          ),
        ],
      ],
    );
  }
}

/// شارة حالة المنتج.
class ItemStatusChip extends StatelessWidget {
  const ItemStatusChip({super.key, required this.status, this.dense = true});

  final ItemStatus status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = switch (status) {
      ItemStatus.available => c.success,
      ItemStatus.reserved => c.warning,
      ItemStatus.negotiating => c.info,
      ItemStatus.pending => c.warning,
      ItemStatus.rejected => c.danger,
      _ => c.textTertiary,
    };

    return GChip(
      label: context.tr(status.labelKey),
      color: color,
      background: color.withOpacity(0.12),
      dense: dense,
    );
  }
}

/// كارت المنتج في السوق المفتوح — شبكة عمودين.
class ItemCard extends StatelessWidget {
  const ItemCard({super.key, required this.item, this.onTap, this.showStatus = false});

  final Item item;
  final VoidCallback? onTap;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ar = context.s.isArabic;
    final category = Categories.byId(item.categoryId);

    return GSurface(
      onTap: onTap,
      padding: EdgeInsets.zero,
      radius: GRadius.brLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1.08,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(GRadius.lg),
                  ),
                  child: GImagePlaceholder(
                    seed: item.imageSeed,
                    icon: category.icon,
                    radius: BorderRadius.zero,
                  ),
                ),
              ),
              if (showStatus)
                PositionedDirectional(
                  top: GSpace.sm,
                  start: GSpace.sm,
                  child: ItemStatusChip(status: item.status),
                ),
              if (item.isService)
                PositionedDirectional(
                  top: GSpace.sm,
                  end: GSpace.sm,
                  child: GChip(
                    label: context.tr('market.services'),
                    icon: Icons.swap_horiz_rounded,
                    color: c.onBrand,
                    background: c.brand,
                    dense: true,
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(GSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: GSpace.xs),
                PriceRange(item: item, compact: true),
                const SizedBox(height: GSpace.sm),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 13,
                      color: c.textTertiary,
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        item.country.cities
                            .firstWhere(
                              (city) => city.id == item.cityId,
                              orElse: () => item.country.cities.first,
                            )
                            .name(ar),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Icon(
                      Icons.favorite_outline_rounded,
                      size: 13,
                      color: c.textTertiary,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${item.wishlistCount}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// كارت المنتج الأفقي — للقوائم والاقتراحات.
class ItemRow extends StatelessWidget {
  const ItemRow({
    super.key,
    required this.item,
    this.onTap,
    this.trailing,
    this.showStatus = true,
  });

  final Item item;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final ar = context.s.isArabic;
    final category = Categories.byId(item.categoryId);

    return GSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(GSpace.md),
      child: Row(
        children: [
          SizedBox(
            width: 68,
            height: 68,
            child: GImagePlaceholder(
              seed: item.imageSeed,
              icon: category.icon,
              radius: GRadius.brMd,
            ),
          ),
          const SizedBox(width: GSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                PriceRange(item: item, compact: true),
                if (showStatus) ...[
                  const SizedBox(height: GSpace.sm),
                  ItemStatusChip(status: item.status),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// مربع القسم في شبكة الأقسام.
class CategoryTile extends StatelessWidget {
  const CategoryTile({
    super.key,
    required this.category,
    this.onTap,
    this.count,
  });

  final Category category;
  final VoidCallback? onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ar = context.s.isArabic;

    return GSurface(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        vertical: GSpace.lg,
        horizontal: GSpace.sm,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: c.brand.withOpacity(0.10),
              borderRadius: GRadius.brMd,
            ),
            child: Icon(category.icon, size: 24, color: c.brand),
          ),
          const SizedBox(height: GSpace.sm),
          Text(
            category.name(ar),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          if (count != null) ...[
            const SizedBox(height: 2),
            Text(
              '$count',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
