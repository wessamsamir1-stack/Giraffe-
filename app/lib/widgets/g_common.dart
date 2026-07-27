import 'package:flutter/material.dart';

import '../core/l10n/strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../data/models/models.dart';
import 'g_button.dart';

/// سطح مرتفع — البديل الموحّد للـ Card.
class GSurface extends StatelessWidget {
  const GSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(GSpace.lg),
    this.radius = GRadius.brLg,
    this.color,
    this.bordered = true,
    this.elevated = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius radius;
  final Color? color;
  final bool bordered;
  final bool elevated;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: radius,
        border: bordered ? Border.all(color: c.border, width: 1.2) : null,
        boxShadow: elevated ? GShadow.card(isDark) : null,
      ),
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: content,
      ),
    );
  }
}

/// شريحة صغيرة — للحالات والتصنيفات والفلاتر.
class GChip extends StatelessWidget {
  const GChip({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.background,
    this.selected = false,
    this.onTap,
    this.dense = false,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final Color? background;
  final bool selected;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final fg = selected ? c.onBrand : (color ?? c.textSecondary);
    final bg = selected ? c.brand : (background ?? c.surfaceAlt);

    final chip = AnimatedContainer(
      duration: GDuration.fast,
      padding: EdgeInsets.symmetric(
        horizontal: dense ? GSpace.sm : GSpace.md,
        vertical: dense ? GSpace.xs : GSpace.sm,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: GRadius.brPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 13 : 15, color: fg),
            const SizedBox(width: GSpace.xs),
          ],
          // Flexible مش Text عادي.
          //
          // الشريحة بتتحط أحياناً جوه Expanded أو صف ضيق، ووقتها النص
          // مايقدرش يقصّر فالصف بيطفح. mainAxisSize.min لوحده مابيحلش
          // ده — هو بيقلل الحجم المطلوب، مش بيخلي المحتوى يتقلّص.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (dense
                      ? Theme.of(context).textTheme.labelSmall
                      : Theme.of(context).textTheme.labelMedium)
                  ?.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return chip;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: chip);
  }
}

/// شارة مستوى الثقة.
class TrustBadge extends StatelessWidget {
  const TrustBadge({super.key, required this.level, this.dense = false});

  final TrustLevel level;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (level) {
      TrustLevel.newbie => (AppPalette.trustNew, Icons.person_outline_rounded),
      TrustLevel.verified => (AppPalette.trustVerified, Icons.verified_rounded),
      TrustLevel.trusted => (AppPalette.trustTrusted, Icons.shield_rounded),
      TrustLevel.elite => (AppPalette.trustElite, Icons.workspace_premium_rounded),
    };

    return GChip(
      label: context.tr(level.labelKey),
      icon: icon,
      color: color,
      background: color.withOpacity(0.12),
      dense: dense,
    );
  }
}

/// صورة المستخدم — بديل ملوّن لحد ما يتربط التخزين.
class GAvatar extends StatelessWidget {
  const GAvatar({
    super.key,
    required this.name,
    this.seed = 0,
    this.size = GSize.avatarMd,
    this.ring = false,
  });

  final String name;
  final int seed;
  final double size;
  final bool ring;

  static const List<Color> _palette = [
    Color(0xFFF58220),
    Color(0xFF2F80ED),
    Color(0xFF9B51E0),
    Color(0xFF28C76F),
    Color(0xFFEB5757),
    Color(0xFF00B8D9),
    Color(0xFFFFB020),
    Color(0xFF6C5CE7),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _palette[seed % _palette.length];
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '؟' : trimmed.substring(0, 1);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        shape: BoxShape.circle,
        border: ring
            ? Border.all(color: context.colors.brand, width: 2.2)
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}

/// عنوان قسم مع زر "عرض الكل".
class GSectionHeader extends StatelessWidget {
  const GSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: GSpace.screenH,
        vertical: GSpace.md,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: GSize.iconMd, color: c.brand),
            const SizedBox(width: GSpace.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: GSpace.xs,
                  vertical: GSpace.sm,
                ),
                child: Text(
                  actionLabel!,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: c.brand),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// الحالة الفاضية — ممنوع أي شاشة تبقى بيضا من غير رسالة وزر.
class GEmptyState extends StatelessWidget {
  const GEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.tone = GEmptyTone.neutral,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final GEmptyTone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final accent = switch (tone) {
      GEmptyTone.neutral => c.textTertiary,
      GEmptyTone.brand => c.brand,
      GEmptyTone.danger => c.danger,
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(GSpace.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 42, color: accent),
            ),
            const SizedBox(height: GSpace.xl),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: GSpace.sm),
            Text(
              body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: GSpace.xxl),
              GButton(
                label: actionLabel!,
                onPressed: onAction,
                expanded: false,
              ),
            ],
            if (secondaryLabel != null) ...[
              const SizedBox(height: GSpace.md),
              GButton(
                label: secondaryLabel!,
                onPressed: onSecondary,
                style: GButtonStyle.ghost,
                expanded: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum GEmptyTone { neutral, brand, danger }

/// عنصر هيكلي أثناء التحميل.
class GSkeleton extends StatefulWidget {
  const GSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius = GRadius.brSm,
  });

  final double? width;
  final double height;
  final BorderRadius radius;

  @override
  State<GSkeleton> createState() => _GSkeletonState();
}

class _GSkeletonState extends State<GSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(c.shimmerBase, c.shimmerHighlight, _controller.value),
          borderRadius: widget.radius,
        ),
      ),
    );
  }
}

/// شريط تقدم بنقاط — للـ onboarding.
class GProgressDots extends StatelessWidget {
  const GProgressDots({super.key, required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: GDuration.base,
          curve: GCurve.standard,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 22 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: active ? c.brand : c.borderStrong,
            borderRadius: GRadius.brPill,
          ),
        );
      }),
    );
  }
}

/// صف إعداد داخل قوائم الإعدادات.
class GSettingsTile extends StatelessWidget {
  const GSettingsTile({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
    this.trailing,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = danger ? c.danger : c.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: GSpace.lg,
            vertical: GSpace.md,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (danger ? c.danger : c.textSecondary).withOpacity(0.10),
                  borderRadius: GRadius.brSm,
                ),
                child: Icon(icon, size: 19, color: danger ? c.danger : c.textSecondary),
              ),
              const SizedBox(width: GSpace.md),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: color),
                ),
              ),
              if (value != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: GSpace.sm),
                  child: Text(
                    value!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              trailing ??
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: c.textTertiary,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// مجموعة إعدادات.
class GSettingsGroup extends StatelessWidget {
  const GSettingsGroup({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            GSpace.screenH,
            GSpace.xl,
            GSpace.screenH,
            GSpace.sm,
          ),
          child: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: c.textTertiary),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: GSpace.lg),
          child: GSurface(
            padding: const EdgeInsets.symmetric(vertical: GSpace.xs),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}

/// تنبيه بارز — للأمان والملاحظات المهمة.
class GNotice extends StatelessWidget {
  const GNotice({
    super.key,
    required this.text,
    this.icon = Icons.info_outline_rounded,
    this.tone = GNoticeTone.info,
  });

  final String text;
  final IconData icon;
  final GNoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = switch (tone) {
      GNoticeTone.info => c.info,
      GNoticeTone.warning => c.warning,
      GNoticeTone.danger => c.danger,
      GNoticeTone.success => c.success,
    };

    return Container(
      padding: const EdgeInsets.all(GSpace.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: GRadius.brMd,
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: GSize.iconSm, color: color),
          const SizedBox(width: GSpace.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

enum GNoticeTone { info, warning, danger, success }

/// صورة نائبة بتدرّج — لحد ما يتربط تخزين الصور.
class GImagePlaceholder extends StatelessWidget {
  const GImagePlaceholder({
    super.key,
    required this.seed,
    this.icon,
    this.radius = GRadius.brLg,
  });

  final int seed;
  final IconData? icon;
  final BorderRadius radius;

  static const List<List<Color>> _gradients = [
    [Color(0xFFFFE3CC), Color(0xFFFFC79A)],
    [Color(0xFFDCE9FF), Color(0xFFB9D2FF)],
    [Color(0xFFE9DCFF), Color(0xFFCDB6FF)],
    [Color(0xFFD8F5E4), Color(0xFFAEE9C7)],
    [Color(0xFFFFE0E0), Color(0xFFFFBDBD)],
    [Color(0xFFD5F4F8), Color(0xFFA8E7EF)],
  ];

  @override
  Widget build(BuildContext context) {
    final pair = _gradients[seed % _gradients.length];
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          colors: pair,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          icon ?? Icons.image_outlined,
          size: 34,
          color: Colors.black.withOpacity(0.18),
        ),
      ),
    );
  }
}
