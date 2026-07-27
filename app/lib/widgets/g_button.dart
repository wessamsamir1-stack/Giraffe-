import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';

enum GButtonStyle { primary, secondary, ghost, danger, success }

enum GButtonSize { large, small }

/// الزر الأساسي في التطبيق.
///
/// مبني يدوي بدل ElevatedButton عشان نتحكم في الشكل بالكامل ونفضل
/// مستقلين عن تغيّرات Material بين إصدارات فلاتر.
class GButton extends StatefulWidget {
  const GButton({
    super.key,
    required this.label,
    this.onPressed,
    this.style = GButtonStyle.primary,
    this.size = GButtonSize.large,
    this.icon,
    this.trailingIcon,
    this.expanded = true,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final GButtonStyle style;
  final GButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool expanded;
  final bool loading;

  @override
  State<GButton> createState() => _GButtonState();
}

class _GButtonState extends State<GButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    late Color bg;
    late Color fg;
    Color? borderColor;
    List<BoxShadow>? shadow;

    switch (widget.style) {
      case GButtonStyle.primary:
        bg = c.brand;
        fg = c.onBrand;
        shadow = GShadow.brand();
      case GButtonStyle.secondary:
        bg = c.surfaceAlt;
        fg = c.textPrimary;
      case GButtonStyle.ghost:
        bg = Colors.transparent;
        fg = c.textPrimary;
        borderColor = c.border;
      case GButtonStyle.danger:
        bg = c.danger;
        fg = Colors.white;
      case GButtonStyle.success:
        bg = c.success;
        fg = Colors.white;
    }

    if (!_enabled) {
      bg = widget.style == GButtonStyle.ghost ? Colors.transparent : c.surfaceSunken;
      fg = c.textTertiary;
      shadow = null;
      borderColor = widget.style == GButtonStyle.ghost ? c.border : null;
    }

    final height = widget.size == GButtonSize.large
        ? GSize.buttonHeight
        : GSize.buttonHeightSm;

    final textStyle = (widget.size == GButtonSize.large
            ? Theme.of(context).textTheme.labelLarge
            : Theme.of(context).textTheme.labelMedium)
        ?.copyWith(color: fg);

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
        onTap: _enabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: GDuration.instant,
          curve: GCurve.standard,
          child: AnimatedContainer(
            duration: GDuration.fast,
            height: height,
            width: widget.expanded ? double.infinity : null,
            padding: EdgeInsets.symmetric(
              horizontal: widget.expanded ? GSpace.lg : GSpace.xl,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: GRadius.brLg,
              border: borderColor != null
                  ? Border.all(color: borderColor, width: 1.4)
                  : null,
              boxShadow: _pressed ? null : shadow,
            ),
            child: Center(
              child: widget.loading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(fg),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, size: GSize.iconMd, color: fg),
                          const SizedBox(width: GSpace.sm),
                        ],
                        Flexible(
                          child: Text(
                            widget.label,
                            style: textStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.trailingIcon != null) ...[
                          const SizedBox(width: GSpace.sm),
                          Icon(widget.trailingIcon, size: GSize.iconMd, color: fg),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// زر تسجيل الدخول بمزود خارجي.
class GSocialButton extends StatelessWidget {
  const GSocialButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.iconColor,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surface,
      borderRadius: GRadius.brLg,
      child: InkWell(
        onTap: onPressed,
        borderRadius: GRadius.brLg,
        child: Container(
          height: GSize.buttonHeight,
          padding: const EdgeInsets.symmetric(horizontal: GSpace.lg),
          decoration: BoxDecoration(
            borderRadius: GRadius.brLg,
            border: Border.all(color: c.border, width: 1.4),
          ),
          child: Row(
            children: [
              Icon(icon, size: GSize.iconLg, color: iconColor ?? c.textPrimary),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(width: GSize.iconLg),
            ],
          ),
        ),
      ),
    );
  }
}

/// زر أيقونة دائري.
class GIconButton extends StatelessWidget {
  const GIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 44,
    this.background,
    this.foreground,
    this.tooltip,
    this.bordered = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color? background;
  final Color? foreground;
  final String? tooltip;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final child = Material(
      color: background ?? c.surface,
      shape: CircleBorder(
        side: bordered
            ? BorderSide(color: c.border, width: 1.2)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: size * 0.46,
            color: foreground ?? c.textPrimary,
          ),
        ),
      ),
    );
    return tooltip == null ? child : Tooltip(message: tooltip!, child: child);
  }
}
