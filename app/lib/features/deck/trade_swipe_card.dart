import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/catalog/categories.dart';
import '../../data/models/models.dart';
import '../../widgets/g_common.dart';

/// كارت الصفقة.
///
/// الفرق الجوهري عن أي سوق إلكتروني: الكارت مش بيعرض منتج —
/// بيعرض **صفقة كاملة**: منتجهم مقابل منتجك زائد الفرق النقدي.
///
/// عشان كده السؤال المطروح على المستخدم مش "المنتج ده عاجبك؟"
/// لكن "الصفقة دي تناسبك؟" — وده اللي بيدّي معنى لنسبة التوافق.
class TradeSwipeCard extends StatelessWidget {
  const TradeSwipeCard({
    super.key,
    required this.candidate,
    this.onTapDetails,
  });

  final TradeCandidate candidate;
  final VoidCallback? onTapDetails;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ar = context.s.isArabic;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final category = Categories.byId(candidate.theirItem.categoryId);
    final currency = candidate.theirItem.country.currency;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: GRadius.brXxl,
        border: Border.all(color: c.border, width: 1.2),
        boxShadow: GShadow.lifted(isDark),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ----------------------------------------------------- الصورة
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                GImagePlaceholder(
                  seed: candidate.theirItem.imageSeed,
                  icon: category.icon,
                  radius: BorderRadius.zero,
                ),

                // تدرّج سفلي عشان النص يبان
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.center,
                        colors: [
                          Colors.black.withOpacity(0.55),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // نسبة التوافق
                PositionedDirectional(
                  top: GSpace.lg,
                  start: GSpace.lg,
                  child: _CompatBadge(value: candidate.compatibility),
                ),

                // المسافة
                PositionedDirectional(
                  top: GSpace.lg,
                  end: GSpace.lg,
                  child: GChip(
                    label:
                        '${candidate.distanceKm.toStringAsFixed(1)} ${context.tr('common.km')}',
                    icon: Icons.near_me_rounded,
                    color: Colors.white,
                    background: Colors.black.withOpacity(0.42),
                    dense: true,
                  ),
                ),

                // اسم المنتج والمالك
                PositionedDirectional(
                  bottom: GSpace.lg,
                  start: GSpace.lg,
                  end: GSpace.lg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        candidate.theirItem.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: GSpace.sm),
                      Row(
                        children: [
                          GAvatar(
                            name: candidate.theirOwner.displayName,
                            seed: candidate.theirOwner.avatarSeed,
                            size: 28,
                          ),
                          const SizedBox(width: GSpace.sm),
                          Flexible(
                            child: Text(
                              candidate.theirOwner.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: GSpace.sm),
                          TrustBadge(
                            level: candidate.theirOwner.trustLevel,
                            dense: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ----------------------------------------------------- الصفقة
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(GSpace.lg),
            color: c.surface,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _Side(
                        labelKey: 'offer.get',
                        title: candidate.theirItem.title,
                        icon: category.icon,
                        highlight: true,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: GSpace.sm,
                      ),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: c.brandSoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.swap_horiz_rounded,
                          size: 19,
                          color: c.brand,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _Side(
                        labelKey: 'offer.give',
                        title: candidate.myItem.title,
                        icon: Categories.byId(candidate.myItem.categoryId).icon,
                      ),
                    ),
                  ],
                ),
                if (candidate.cashDelta != 0) ...[
                  const SizedBox(height: GSpace.md),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: GSpace.md,
                      vertical: GSpace.sm,
                    ),
                    decoration: BoxDecoration(
                      color: candidate.cashDelta > 0
                          ? c.warning.withOpacity(0.10)
                          : c.success.withOpacity(0.10),
                      borderRadius: GRadius.brSm,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          candidate.cashDelta > 0
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          size: 15,
                          color: candidate.cashDelta > 0 ? c.warning : c.success,
                        ),
                        const SizedBox(width: GSpace.xs),
                        Text(
                          '${context.tr(candidate.cashDelta > 0 ? 'deck.youPay' : 'deck.youGet')}  '
                          '${currency.formatCompact(candidate.cashDelta.abs(), ar: ar)}',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: candidate.cashDelta > 0
                                    ? c.warning
                                    : c.success,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: GSpace.md),
                GestureDetector(
                  onTap: onTapDetails,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 15,
                        color: c.textTertiary,
                      ),
                      const SizedBox(width: GSpace.xs),
                      Text(
                        context.tr('deck.info'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({
    required this.labelKey,
    required this.title,
    required this.icon,
    this.highlight = false,
  });

  final String labelKey;
  final String title;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(labelKey),
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: c.textTertiary),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            Icon(
              icon,
              size: 15,
              color: highlight ? c.brand : c.textSecondary,
            ),
            const SizedBox(width: GSpace.xs),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CompatBadge extends StatelessWidget {
  const _CompatBadge({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = value >= 85
        ? c.success
        : value >= 70
            ? c.brand
            : c.warning;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: GSpace.md,
        vertical: GSpace.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: GRadius.brPill,
        boxShadow: GShadow.soft(false),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, size: 16, color: color),
          const SizedBox(width: 3),
          Text(
            '$value%',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: GSpace.xs),
          Text(
            context.tr('deck.compat'),
            style: const TextStyle(
              color: Color(0xFF636363),
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// طابع الحركة اللي بيظهر أثناء السحب.
class SwipeStamp extends StatelessWidget {
  const SwipeStamp({super.key, required this.intent, required this.opacity});

  final SwipeIntent intent;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final (color, labelKey, icon) = switch (intent) {
      SwipeIntent.skip => (
          AppPalette.swipeSkip,
          'deck.skip',
          Icons.close_rounded,
        ),
      SwipeIntent.interested => (
          AppPalette.swipeInterested,
          'deck.interested',
          Icons.favorite_rounded,
        ),
      SwipeIntent.dream => (
          AppPalette.swipeDream,
          'deck.dream',
          Icons.star_rounded,
        ),
    };

    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: GSpace.lg,
          vertical: GSpace.md,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: GRadius.brMd,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: GSpace.sm),
            Text(
              context.tr(labelKey),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
