import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

/// الهيكل الرئيسي — 5 تبويبات.
///
/// كان 4 في التخطيط الأصلي، وبقى 5 بعد إضافة **السوق المفتوح**.
///
/// التقسيم المقصود:
/// - السوق  = البحث المقصود (المستخدم عارف هو عايز إيه)
/// - اسحب   = الاكتشاف (المستخدم مش عارف هو عايز إيه)
///
/// الاتنين مكمّلين لبعض — السحب لوحده بيخفي المخزون، والسوق لوحده
/// بيحوّلنا لموقع إعلانات مبوبة عادي.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _items = [
    (icon: Icons.storefront_outlined, active: Icons.storefront_rounded, key: 'tab.market'),
    (icon: Icons.style_outlined, active: Icons.style_rounded, key: 'tab.deck'),
    (icon: Icons.forum_outlined, active: Icons.forum_rounded, key: 'tab.matches'),
    (icon: Icons.inventory_2_outlined, active: Icons.inventory_2_rounded, key: 'tab.items'),
    (icon: Icons.person_outline_rounded, active: Icons.person_rounded, key: 'tab.profile'),
  ];

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: navigationShell,
      floatingActionButton: navigationShell.currentIndex == 3
          ? FloatingActionButton.extended(
              onPressed: () => context.push(R.addItem),
              backgroundColor: c.brand,
              foregroundColor: c.onBrand,
              icon: const Icon(Icons.add_rounded),
              label: Text(context.tr('items.add')),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.border)),
          boxShadow: GShadow.soft(isDark),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: GSize.navBarHeight,
            child: Row(
              children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(
                    child: _NavItem(
                      icon: _items[i].icon,
                      activeIcon: _items[i].active,
                      label: context.tr(_items[i].key),
                      selected: navigationShell.currentIndex == i,
                      badge: i == 2 ? 2 : null,
                      onTap: () => _onTap(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = selected ? c.brand : c.textTertiary;

    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedScale(
                  scale: selected ? 1.08 : 1,
                  duration: GDuration.fast,
                  curve: GCurve.standard,
                  child: Icon(
                    selected ? activeIcon : icon,
                    size: GSize.iconLg - 4,
                    color: color,
                  ),
                ),
                if (badge != null && badge! > 0)
                  PositionedDirectional(
                    top: -3,
                    end: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: c.danger,
                        borderRadius: GRadius.brPill,
                        border: Border.all(color: c.surface, width: 1.5),
                      ),
                      child: Text(
                        '$badge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontSize: 10.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
