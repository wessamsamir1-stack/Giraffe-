import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/catalog/categories.dart';
import '../../data/models/models.dart';
import '../../widgets/g_button.dart';
import '../../widgets/g_common.dart';

class DeckFiltersScreen extends StatefulWidget {
  const DeckFiltersScreen({super.key});

  @override
  State<DeckFiltersScreen> createState() => _DeckFiltersScreenState();
}

class _DeckFiltersScreenState extends State<DeckFiltersScreen> {
  double _distance = 25;
  double _maxCash = 20000;
  TrustLevel _minTrust = TrustLevel.newbie;
  final Set<String> _categories = {};

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ar = context.s.isArabic;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('deck.filters.title')),
        actions: [
          TextButton(
            onPressed: () => setState(() {
              _distance = 25;
              _maxCash = 20000;
              _minTrust = TrustLevel.newbie;
              _categories.clear();
            }),
            child: Text(context.tr('common.reset')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(GSpace.screenH),
        children: [
          _Label(
            text: context.tr('deck.filters.distance'),
            value: '${_distance.round()} ${context.tr('common.km')}',
          ),
          Slider(
            value: _distance,
            min: 1,
            max: 100,
            divisions: 99,
            activeColor: c.brand,
            onChanged: (v) => setState(() => _distance = v),
          ),

          const SizedBox(height: GSpace.lg),
          _Label(
            text: context.tr('deck.filters.maxCash'),
            value: _maxCash.round().toString(),
          ),
          Slider(
            value: _maxCash,
            max: 100000,
            divisions: 40,
            activeColor: c.brand,
            onChanged: (v) => setState(() => _maxCash = v),
          ),

          const SizedBox(height: GSpace.xl),
          Text(
            context.tr('deck.filters.trust'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: GSpace.md),
          Wrap(
            spacing: GSpace.sm,
            children: [
              for (final level in TrustLevel.values)
                GChip(
                  label: context.tr(level.labelKey),
                  selected: _minTrust == level,
                  onTap: () => setState(() => _minTrust = level),
                ),
            ],
          ),

          const SizedBox(height: GSpace.xl),
          Text(
            context.tr('deck.filters.categories'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: GSpace.md),
          Wrap(
            spacing: GSpace.sm,
            runSpacing: GSpace.sm,
            children: [
              for (final category in Categories.all)
                GChip(
                  label: category.name(ar),
                  icon: category.icon,
                  selected: _categories.contains(category.id),
                  onTap: () => setState(() {
                    if (!_categories.remove(category.id)) {
                      _categories.add(category.id);
                    }
                  }),
                ),
            ],
          ),

          const SizedBox(height: GSpace.xl),
          GNotice(
            icon: Icons.lightbulb_outline_rounded,
            text: ar
                ? 'كل ما ضيّقت الفلاتر، كل ما قلّت الصفقات المعروضة. لو الكروت خلصت بسرعة جرّب توسّع المسافة.'
                : 'Tighter filters mean fewer trades. If you run out fast, widen the distance first.',
          ),

          const SizedBox(height: GSpace.xxl),
          GButton(
            label: context.tr('common.apply'),
            onPressed: () => context.pop(),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.text, required this.value});

  final String text;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.titleMedium),
        ),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: context.colors.brand),
        ),
      ],
    );
  }
}
