import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/mock/mock_data.dart';
import '../../data/models/models.dart';
import '../../widgets/g_button.dart';
import '../../widgets/g_common.dart';

/// تحديد اللقاء + قائمة التحقق + زر الطوارئ.
///
/// دي أخطر لحظة في رحلة المستخدم كلها: لقاء حقيقي مع غريب،
/// ومفيش أي payment rail نقدر نرجّع منه فلوس.
///
/// عشان كده:
/// - أماكن عامة معتمدة **فقط** — مش أي مكان
/// - زر طوارئ ثابت بيبعت الموقع لجهة اتصال محددة مسبقاً
/// - قائمة تحقق قبل تسليم أي حاجة
class MeetingScreen extends StatefulWidget {
  const MeetingScreen({super.key, required this.matchId});

  final String matchId;

  @override
  State<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingScreen> {
  MeetingPlace? _place;
  DateTime? _date;
  TimeOfDay? _time;
  final Set<int> _checked = {};

  bool get _ready => _place != null && _date != null && _time != null;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ar = context.s.isArabic;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('meet.title')),
        actions: [
          // زر الطوارئ ثابت ومرئي في كل الأوقات
          Padding(
            padding: const EdgeInsetsDirectional.only(end: GSpace.sm),
            child: GestureDetector(
              onTap: () => _confirmSos(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: GSpace.md,
                  vertical: GSpace.sm,
                ),
                decoration: BoxDecoration(
                  color: c.danger,
                  borderRadius: GRadius.brPill,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sos_rounded, size: 16, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      context.tr('meet.sos'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(GSpace.screenH),
        children: [
          GNotice(
            tone: GNoticeTone.danger,
            icon: Icons.health_and_safety_outlined,
            text: context.tr('meet.sosBody'),
          ),

          const SizedBox(height: GSpace.xl),
          Text(
            context.tr('meet.place'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            context.tr('meet.placeHint'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: GSpace.md),
          for (final place in Mock.meetingPlaces)
            Padding(
              padding: const EdgeInsets.only(bottom: GSpace.sm),
              child: _PlaceRow(
                place: place,
                selected: _place?.id == place.id,
                onTap: () => setState(() => _place = place),
              ),
            ),

          const SizedBox(height: GSpace.xl),
          Row(
            children: [
              Expanded(
                child: _PickerBox(
                  label: context.tr('meet.date'),
                  value: _date == null
                      ? '—'
                      : '${_date!.day}/${_date!.month}/${_date!.year}',
                  icon: Icons.event_outlined,
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 30)),
                      initialDate: now,
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                ),
              ),
              const SizedBox(width: GSpace.md),
              Expanded(
                child: _PickerBox(
                  label: context.tr('meet.time'),
                  value: _time == null ? '—' : _time!.format(context),
                  icon: Icons.schedule_rounded,
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (picked != null) setState(() => _time = picked);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: GSpace.xl),
          Text(
            context.tr('meet.checklist'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: GSpace.sm),
          for (var i = 0; i < 4; i++)
            _CheckItem(
              label: context.tr('meet.check${i + 1}'),
              checked: _checked.contains(i),
              onTap: () => setState(() {
                if (!_checked.remove(i)) _checked.add(i);
              }),
            ),

          const SizedBox(height: GSpace.xl),
          GButton(
            label: context.tr('common.confirm'),
            onPressed: _ready
                ? () => context.pushReplacement(R.complete(widget.matchId))
                : null,
          ),
          const SizedBox(height: GSpace.md),
          GButton(
            label: context.tr('meet.noShow'),
            style: GButtonStyle.ghost,
            onPressed: () => context.push(R.dispute(widget.matchId)),
          ),
          const SizedBox(height: GSpace.xl),

          Text(
            ar
                ? 'قواعد الأمان الخمسة'
                : 'Five safety rules',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: GSpace.sm),
          for (var i = 1; i <= 5; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: GSpace.xs),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      size: 15, color: c.success),
                  const SizedBox(width: GSpace.sm),
                  Expanded(
                    child: Text(
                      context.tr('safety.rule$i'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmSos(BuildContext context) async {
    final c = context.colors;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: const RoundedRectangleBorder(borderRadius: GRadius.brXl),
        icon: Icon(Icons.sos_rounded, color: c.danger, size: 34),
        title: Text(
          context.tr('meet.sosConfirm'),
          textAlign: TextAlign.center,
          style: Theme.of(ctx).textTheme.titleLarge,
        ),
        content: Text(
          context.tr('meet.sosBody'),
          textAlign: TextAlign.center,
          style: Theme.of(ctx).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.tr('common.cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: c.danger,
                  content: Text(context.tr('common.soon')),
                ),
              );
            },
            child: Text(
              context.tr('common.confirm'),
              style: TextStyle(color: c.danger),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.place,
    required this.selected,
    required this.onTap,
  });

  final MeetingPlace place;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ar = context.s.isArabic;

    final icon = switch (place.typeEn) {
      'Police station' => Icons.local_police_outlined,
      'Coffee shop' => Icons.local_cafe_outlined,
      'Public station' => Icons.directions_subway_outlined,
      _ => Icons.storefront_outlined,
    };

    return GSurface(
      onTap: onTap,
      color: selected ? c.brandSoft : null,
      padding: const EdgeInsets.all(GSpace.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.success.withOpacity(0.12),
              borderRadius: GRadius.brSm,
            ),
            child: Icon(icon, size: 20, color: c.success),
          ),
          const SizedBox(width: GSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name(ar),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  '${place.type(ar)} · ${place.distanceKm} ${context.tr('common.km')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (selected)
            Icon(Icons.check_circle_rounded, size: 20, color: c.brand),
        ],
      ),
    );
  }
}

class _PickerBox extends StatelessWidget {
  const _PickerBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(GSpace.md),
      child: Row(
        children: [
          Icon(icon, size: 19, color: c.textSecondary),
          const SizedBox(width: GSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall),
                Text(value, style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  const _CheckItem({
    required this.label,
    required this.checked,
    required this.onTap,
  });

  final String label;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: GSpace.sm),
        child: Row(
          children: [
            AnimatedContainer(
              duration: GDuration.fast,
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: checked ? c.success : Colors.transparent,
                borderRadius: GRadius.brXs,
                border: Border.all(
                  color: checked ? c.success : c.borderStrong,
                  width: 1.6,
                ),
              ),
              child: checked
                  ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: GSpace.md),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
            ),
          ],
        ),
      ),
    );
  }
}
