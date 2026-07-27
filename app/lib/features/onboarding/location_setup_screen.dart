import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/l10n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/catalog/countries.dart';
import '../../data/repositories/providers.dart';
import '../../widgets/g_button.dart';
import '../../widgets/g_common.dart';

/// اختيار الدولة والمدينة.
///
/// قرار خصوصية: **مش بناخد إحداثيات دقيقة**. المدينة كافية للمطابقة،
/// والمسافة بتتحسب على مستوى المنطقة مش النقطة.
///
/// قرار سيولة: كل مدينة سوق منفصل. مفيش عرض عابر للحدود في المرحلة الأولى
/// لأن فرق القوة الشرائية بين مصر والخليج بيكسر التقييم.
class LocationSetupScreen extends ConsumerStatefulWidget {
  const LocationSetupScreen({super.key});

  @override
  ConsumerState<LocationSetupScreen> createState() =>
      _LocationSetupScreenState();
}

class _LocationSetupScreenState extends ConsumerState<LocationSetupScreen> {
  bool _saving = false;

  /// تزحزح الإحداثيات قبل الحفظ.
  ///
  /// إحنا **مش بناخد الموقع الحقيقي**. بناخد مركز المدينة ونزحزحه
  /// عشوائياً في حدود كيلومتر، وده كفاية تماماً لترتيب الصفقات بالمسافة
  /// ومش كفاية أبداً لاستنتاج عنوان حد.
  (double, double) _jitter(double lat, double lng) {
    final seed = DateTime.now().microsecondsSinceEpoch;
    final angle = (seed % 360) * 3.14159 / 180;
    final dist = ((seed >> 8) % 100) / 100.0;
    final dLat = (dist / 110.574) * math.cos(angle);
    final dLng = (dist / (111.320 * math.cos(lat * 3.14159 / 180))) *
        math.sin(angle);
    return (
      double.parse((lat + dLat).toStringAsFixed(4)),
      double.parse((lng + dLng).toStringAsFixed(4)),
    );
  }

  Future<void> _save() async {
    final draft = ref.read(setupDraftProvider);
    final country = ref.read(countryProvider);
    final city = ref.read(cityProvider);

    setState(() => _saving = true);

    final point = _jitter(city.lat, city.lng);
    final error = await ref.read(profileRepositoryProvider).upsert(
          displayName: draft.displayName,
          username: draft.username,
          bio: draft.bio,
          countryCode: country.code,
          cityId: city.id,
          lat: point.$1,
          lng: point.$2,
          locale: ref.read(localeProvider).languageCode,
        );

    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(error))),
      );
      return;
    }

    ref.invalidate(myProfileProvider);
    if (mounted) context.go(R.onbWishlist);
  }

  @override
  Widget build(BuildContext context) {
    final ar = context.s.isArabic;
    final country = ref.watch(countryProvider);
    final city = ref.watch(cityProvider);

    return Scaffold(
      appBar: AppBar(
        title: const GProgressDots(count: 3, index: 1),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                GSpace.screenH,
                GSpace.lg,
                GSpace.screenH,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('setup.location.title'),
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: GSpace.sm),
                  Text(
                    context.tr('setup.location.body'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: GSpace.xl),

                  // اختيار الدولة
                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: Countries.all.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: GSpace.sm),
                      itemBuilder: (context, i) {
                        final item = Countries.all[i];
                        final selected = item.code == country.code;
                        return GChip(
                          label: '${item.flag}  ${item.name(ar)}',
                          selected: selected,
                          onTap: () {
                            ref.read(countryProvider.notifier).state = item;
                            ref.read(cityProvider.notifier).state =
                                item.cities.first;
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: GSpace.xl),
                  Text(
                    context.tr('setup.city'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: GSpace.sm),
                ],
              ),
            ),

            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: GSpace.screenH,
                  vertical: GSpace.sm,
                ),
                itemCount: country.cities.length,
                separatorBuilder: (_, __) => const SizedBox(height: GSpace.sm),
                itemBuilder: (context, i) {
                  final item = country.cities[i];
                  final selected = item.id == city.id;
                  return _CityRow(
                    label: item.name(ar),
                    selected: selected,
                    onTap: () =>
                        ref.read(cityProvider.notifier).state = item,
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(GSpace.screenH),
              child: GButton(
                label: context.tr('common.continue'),
                loading: _saving,
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CityRow extends StatelessWidget {
  const _CityRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GSurface(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: GSpace.lg,
        vertical: GSpace.md,
      ),
      color: selected ? c.brandSoft : null,
      child: Row(
        children: [
          Icon(
            Icons.location_city_rounded,
            size: GSize.iconMd,
            color: selected ? c.brand : c.textTertiary,
          ),
          const SizedBox(width: GSpace.md),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (selected)
            Icon(Icons.check_circle_rounded, size: 20, color: c.brand),
        ],
      ),
    );
  }
}
