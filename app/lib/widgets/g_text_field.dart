import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/l10n/strings.dart';
import '../core/security/password_policy.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../data/catalog/countries.dart';

/// حقل الإدخال القياسي.
class GTextField extends StatefulWidget {
  const GTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.errorKey,
    this.keyboardType,
    this.textInputAction,
    this.obscure = false,
    this.prefixIcon,
    this.suffix,
    this.maxLines = 1,
    this.maxLength,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.inputFormatters,
    this.helper,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;

  /// مفتاح رسالة الخطأ — بيترجم داخلياً.
  final String? errorKey;

  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscure;
  final IconData? prefixIcon;
  final Widget? suffix;
  final int maxLines;
  final int? maxLength;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final List<TextInputFormatter>? inputFormatters;
  final String? helper;

  @override
  State<GTextField> createState() => _GTextFieldState();
}

class _GTextFieldState extends State<GTextField> {
  late final FocusNode _focus = FocusNode()..addListener(_onFocus);
  bool _focused = false;

  void _onFocus() => setState(() => _focused = _focus.hasFocus);

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasError = widget.errorKey != null;

    final borderColor = hasError
        ? c.danger
        : _focused
            ? c.brand
            : c.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: c.textSecondary,
              ),
        ),
        const SizedBox(height: GSpace.sm),
        AnimatedContainer(
          duration: GDuration.fast,
          decoration: BoxDecoration(
            color: widget.enabled ? c.surface : c.surfaceAlt,
            borderRadius: GRadius.brMd,
            border: Border.all(color: borderColor, width: _focused ? 1.8 : 1.3),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: GSpace.lg,
            vertical: widget.maxLines > 1 ? GSpace.md : 0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.prefixIcon != null) ...[
                Icon(
                  widget.prefixIcon,
                  size: GSize.iconMd,
                  color: _focused ? c.brand : c.textTertiary,
                ),
                const SizedBox(width: GSpace.md),
              ],
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  obscureText: widget.obscure,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  maxLines: widget.maxLines,
                  maxLength: widget.maxLength,
                  autofillHints: widget.autofillHints,
                  inputFormatters: widget.inputFormatters,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  style: Theme.of(context).textTheme.bodyLarge,
                  cursorColor: c.brand,
                  decoration: InputDecoration(
                    isDense: true,
                    counterText: '',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: widget.maxLines > 1 ? 0 : GSpace.lg,
                    ),
                    hintText: widget.hint,
                    hintStyle: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: c.textTertiary),
                  ),
                ),
              ),
              if (widget.suffix != null) widget.suffix!,
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: GSpace.xs),
          Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 14, color: c.danger),
              const SizedBox(width: GSpace.xs),
              Expanded(
                child: Text(
                  context.tr(widget.errorKey!),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: c.danger),
                ),
              ),
            ],
          ),
        ] else if (widget.helper != null) ...[
          const SizedBox(height: GSpace.xs),
          Text(
            widget.helper!,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: c.textTertiary),
          ),
        ],
      ],
    );
  }
}

/// حقل كلمة السر مع مقياس القوة وقائمة الشروط.
class GPasswordField extends StatefulWidget {
  const GPasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.showMeter = true,
    this.email,
    this.displayName,
    this.errorKey,
    this.onChanged,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String label;
  final bool showMeter;
  final String? email;
  final String? displayName;
  final String? errorKey;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;

  @override
  State<GPasswordField> createState() => _GPasswordFieldState();
}

class _GPasswordFieldState extends State<GPasswordField> {
  bool _hidden = true;
  PasswordCheck? _check;

  void _evaluate(String value) {
    setState(() {
      _check = value.isEmpty
          ? null
          : PasswordPolicy.evaluate(
              value,
              email: widget.email,
              displayName: widget.displayName,
            );
    });
    widget.onChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GTextField(
          label: widget.label,
          controller: widget.controller,
          obscure: _hidden,
          errorKey: widget.errorKey,
          prefixIcon: Icons.lock_outline_rounded,
          textInputAction: widget.textInputAction,
          autofillHints: const [AutofillHints.newPassword],
          onChanged: widget.showMeter ? _evaluate : widget.onChanged,
          suffix: GestureDetector(
            onTap: () => setState(() => _hidden = !_hidden),
            behavior: HitTestBehavior.opaque,
            child: Semantics(
              label: context.tr(_hidden ? 'pw.showPassword' : 'pw.hidePassword'),
              child: Padding(
                padding: const EdgeInsets.all(GSpace.xs),
                child: Icon(
                  _hidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: GSize.iconMd,
                  color: c.textTertiary,
                ),
              ),
            ),
          ),
        ),
        if (widget.showMeter && _check != null) ...[
          const SizedBox(height: GSpace.md),
          _StrengthMeter(check: _check!),
          const SizedBox(height: GSpace.md),
          _RuleList(check: _check!),
        ],
      ],
    );
  }
}

class _StrengthMeter extends StatelessWidget {
  const _StrengthMeter({required this.check});

  final PasswordCheck check;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final (color, labelKey) = switch (check.strength) {
      PasswordStrength.veryWeak => (c.danger, 'pw.veryWeak'),
      PasswordStrength.weak => (c.danger, 'pw.weak'),
      PasswordStrength.fair => (c.warning, 'pw.fair'),
      PasswordStrength.strong => (c.success, 'pw.strong'),
      PasswordStrength.veryStrong => (c.success, 'pw.veryStrong'),
    };

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: GRadius.brPill,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: check.score),
              duration: GDuration.base,
              curve: GCurve.standard,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: c.surfaceSunken,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
        ),
        const SizedBox(width: GSpace.md),
        Text(
          context.tr(labelKey),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _RuleList extends StatelessWidget {
  const _RuleList({required this.check});

  final PasswordCheck check;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(
      spacing: GSpace.md,
      runSpacing: GSpace.sm,
      children: [
        for (final rule in check.rules)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                rule.passed
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 15,
                color: rule.passed ? c.success : c.textTertiary,
              ),
              const SizedBox(width: GSpace.xs),
              Text(
                context.tr(rule.key),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: rule.passed ? c.textSecondary : c.textTertiary,
                    ),
              ),
            ],
          ),
      ],
    );
  }
}

/// حقل رقم الموبايل مع اختيار الدولة.
class GPhoneField extends StatelessWidget {
  const GPhoneField({
    super.key,
    required this.controller,
    required this.country,
    required this.onCountryChanged,
    this.errorKey,
  });

  final TextEditingController controller;
  final Country country;
  final ValueChanged<Country> onCountryChanged;
  final String? errorKey;

  @override
  Widget build(BuildContext context) {
    final ar = context.s.isArabic;
    return GTextField(
      label: context.tr('auth.phone'),
      controller: controller,
      errorKey: errorKey,
      keyboardType: TextInputType.phone,
      maxLength: country.phoneDigits + 1,
      autofillHints: const [AutofillHints.telephoneNumber],
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      suffix: _CountryPicker(
        country: country,
        onChanged: onCountryChanged,
        isArabic: ar,
      ),
    );
  }
}

class _CountryPicker extends StatelessWidget {
  const _CountryPicker({
    required this.country,
    required this.onChanged,
    required this.isArabic,
  });

  final Country country;
  final ValueChanged<Country> onChanged;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: () async {
        final picked = await showModalBottomSheet<Country>(
          context: context,
          backgroundColor: c.surface,
          shape: const RoundedRectangleBorder(borderRadius: GRadius.sheet),
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: GSpace.md),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.borderStrong,
                    borderRadius: GRadius.brPill,
                  ),
                ),
                const SizedBox(height: GSpace.lg),
                for (final country in Countries.all)
                  ListTile(
                    leading: Text(
                      country.flag,
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(country.name(isArabic)),
                    trailing: Text(
                      country.dialCode,
                      style: Theme.of(ctx).textTheme.bodyMedium,
                    ),
                    onTap: () => Navigator.of(ctx).pop(country),
                  ),
                const SizedBox(height: GSpace.lg),
              ],
            ),
          ),
        );
        if (picked != null) onChanged(picked);
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: GSpace.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(country.flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: GSpace.xs),
            Text(
              country.dialCode,
              style: Theme.of(context).textTheme.labelMedium,
              textDirection: TextDirection.ltr,
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: c.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// حقل كود التحقق — 6 خانات.
class GOtpField extends StatefulWidget {
  const GOtpField({
    super.key,
    required this.onCompleted,
    this.hasError = false,
    this.enabled = true,
  });

  final ValueChanged<String> onCompleted;
  final bool hasError;
  final bool enabled;

  @override
  State<GOtpField> createState() => _GOtpFieldState();
}

class _GOtpFieldState extends State<GOtpField> {
  static const int _length = 6;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final value = _controller.text;

    return GestureDetector(
      onTap: () => _focus.requestFocus(),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // الحقل الحقيقي مخفي خلف الخانات المرسومة.
          Opacity(
            opacity: 0,
            child: SizedBox(
              height: 1,
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                maxLength: _length,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) {
                  setState(() {});
                  if (v.length == _length) widget.onCompleted(v);
                },
              ),
            ),
          ),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(_length, (i) {
                final filled = i < value.length;
                final active = i == value.length && _focus.hasFocus;
                return AnimatedContainer(
                  duration: GDuration.fast,
                  width: 48,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: GRadius.brMd,
                    border: Border.all(
                      color: widget.hasError
                          ? c.danger
                          : active
                              ? c.brand
                              : filled
                                  ? c.borderStrong
                                  : c.border,
                      width: active || widget.hasError ? 1.8 : 1.3,
                    ),
                  ),
                  child: Text(
                    filled ? value[i] : '',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
