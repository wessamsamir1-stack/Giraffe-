import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/l10n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/catalog/categories.dart';
import '../../widgets/g_button.dart';
import '../../widgets/g_common.dart';

/// ⭐ أهم شاشة في التطبيق كله.
///
/// من غير قائمة رغبات، محرك المطابقة ما بيشتغلش والـ deck بيبقى عشوائي.
/// وعشان كده الشاشة دي **إجبارية بدون تخطي**، والزر مقفول لحد ما
/// المستخدم يختار 3 أقسام على الأقل.
class WishlistBuilderScreen extends StatefulWidget {
  const WishlistBuilderScreen({super.key});

  @override
  State<WishlistBuilderScreen> createState() => _WishlistBuilderScreenState();
}

class _WishlistBuilderScreenState extends State<WishlistBuilderScreen> {
  final Set<String> _selected = {};

  bool get _canContinue => _selected.length >= kMinWishlistItems;

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else if (_selected.length < kMaxWishlistItems) {
        _selected.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ar = context.s.isArabic;

    return Scaffold(
      appBar: AppBar(
        title: const GProgressDots(count: 3, index: 2),
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
                GSpace.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('setup.wishlist.title'),
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: GSpace.sm),
                  Text(
                    context.tr('setup.wishlist.body'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),

            // شريط التقدم — بيوضح للمستخدم إنه قرب يخلص
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: GSpace.screenH),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: GRadius.brPill,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(
                          begin: 0,
                          end: (_selected.length / kMinWishlistItems)
                              .clamp(0.0, 1.0),
                        ),
                        duration: GDuration.base,
                        curve: GCurve.standard,
                        builder: (context, value, _) => LinearProgressIndicator(
                          value: value,
                          minHeight: 6,
                          backgroundColor: c.surfaceSunken,
                          valueColor: AlwaysStoppedAnimation(
                            _canContinue ? c.success : c.brand,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: GSpace.md),
                  Text(
                    context.trf('setup.wishlist.counter', {
                      'n': _selected.length,
                    }),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: _canContinue ? c.success : c.textSecondary,
                        ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: GSpace.lg),

            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: GSpace.screenH,
                  vertical: GSpace.sm,
                ),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: GSpace.md,
                  mainAxisSpacing: GSpace.md,
                  childAspectRatio: 0.92,
                ),
                itemCount: Categories.all.length,
                itemBuilder: (context, i) {
                  final category = Categories.all[i];
                  final selected = _selected.contains(category.id);
                  return _WishTile(
                    label: category.name(ar),
                    icon: category.icon,
                    selected: selected,
                    onTap: () => _toggle(category.id),
                  );
                },
              ),
            ),

            Container(
              padding: const EdgeInsets.all(GSpace.screenH),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: GButton(
                label: context.tr('common.continue'),
                onPressed: _canContinue ? () => context.go(R.market) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WishTile extends StatelessWidget {
  const _WishTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: GDuration.fast,
        curve: GCurve.standard,
        decoration: BoxDecoration(
          color: selected ? c.brandSoft : c.surface,
          borderRadius: GRadius.brLg,
          border: Border.all(
            color: selected ? c.brand : c.border,
            width: selected ? 1.8 : 1.2,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: GSpace.sm),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 28,
                      color: selected ? c.brand : c.textSecondary,
                    ),
                    const SizedBox(height: GSpace.sm),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: selected ? c.brand : c.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            if (selected)
              PositionedDirectional(
                top: GSpace.sm,
                end: GSpace.sm,
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 17,
                  color: c.brand,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
