import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/catalog/categories.dart';
import '../../widgets/g_common.dart';

/// كل الأقسام مع أقسامها الفرعية.
class AllCategoriesScreen extends StatelessWidget {
  const AllCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ar = context.s.isArabic;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('market.allCategories'))),
      body: ListView.separated(
        padding: const EdgeInsets.all(GSpace.screenH),
        itemCount: Categories.all.length,
        separatorBuilder: (_, __) => const SizedBox(height: GSpace.md),
        itemBuilder: (context, i) {
          final category = Categories.all[i];
          return GSurface(
            padding: EdgeInsets.zero,
            child: Theme(
              // إزالة الخطوط الافتراضية للـ ExpansionTile
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                shape: const RoundedRectangleBorder(borderRadius: GRadius.brLg),
                collapsedShape:
                    const RoundedRectangleBorder(borderRadius: GRadius.brLg),
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: GSpace.lg,
                  vertical: GSpace.xs,
                ),
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: c.brand.withOpacity(0.10),
                    borderRadius: GRadius.brSm,
                  ),
                  child: Icon(category.icon, size: 21, color: c.brand),
                ),
                title: Text(
                  category.name(ar),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: Text(
                  '${category.subs.length} ${ar ? 'قسم فرعي' : 'subcategories'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                children: [
                  if (category.restricted)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        GSpace.lg,
                        0,
                        GSpace.lg,
                        GSpace.md,
                      ),
                      child: GNotice(
                        tone: GNoticeTone.warning,
                        icon: Icons.gavel_rounded,
                        text: ar
                            ? 'القسم ده عليه قيود قانونية. هيظهر لك تنبيه بالشروط قبل النشر.'
                            : 'This category has legal restrictions. You will see the rules before publishing.',
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      GSpace.lg,
                      0,
                      GSpace.lg,
                      GSpace.lg,
                    ),
                    child: Wrap(
                      spacing: GSpace.sm,
                      runSpacing: GSpace.sm,
                      children: [
                        for (final sub in category.subs)
                          GChip(
                            label: sub.name(ar),
                            onTap: () => context.push(R.category(category.id)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
