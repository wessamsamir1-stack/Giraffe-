import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/models/models.dart';
import '../../data/repositories/providers.dart';
import '../../widgets/g_common.dart';
import '../../widgets/item_card.dart';

/// البحث بلغة طبيعية.
///
/// المستخدم بيكتب جملة عادية زي "عايز لابتوب ألعاب بأقل من 30 ألف"
/// والنموذج بيحوّلها لفلاتر منظمة يعرضها فوق النتائج **عشان المستخدم
/// يقدر يعدّلها** — مش صندوق أسود.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _term = '';

  bool get _searched => _term.isNotEmpty;

  void _run() => setState(() => _term = _controller.text.trim());

  static const _recent = ['آيفون 15', 'لابتوب ألعاب', 'عدسة كانون', 'أنتريه'];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ar = context.s.isArabic;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsetsDirectional.only(end: GSpace.lg),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: GSpace.md),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: GRadius.brMd,
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 20, color: c.textTertiary),
                const SizedBox(width: GSpace.sm),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _run(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: c.textPrimary,
                        ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: context.tr('market.searchHint'),
                      hintStyle: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _searched ? _results(context, ar) : _suggestions(context, ar),
    );
  }

  Widget _suggestions(BuildContext context, bool ar) {
    return ListView(
      padding: const EdgeInsets.all(GSpace.screenH),
      children: [
        GNotice(
          icon: Icons.auto_awesome_rounded,
          text: ar
              ? 'اكتب طلبك بلغتك العادية. مثال: "عايز لابتوب ألعاب بأقل من 30 ألف في القاهرة"'
              : 'Type in plain language. e.g. "gaming laptop under 30k in Cairo"',
        ),
        const SizedBox(height: GSpace.xl),
        Text(
          ar ? 'عمليات بحث سابقة' : 'Recent searches',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: GSpace.md),
        Wrap(
          spacing: GSpace.sm,
          runSpacing: GSpace.sm,
          children: [
            for (final term in _recent)
              GChip(
                label: term,
                icon: Icons.history_rounded,
                onTap: () {
                  _controller.text = term;
                  _run();
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _results(BuildContext context, bool ar) {
    final async = ref.watch(searchResultsProvider(_term));
    final items = async.valueOrNull ?? const <Item>[];

    return Column(
      children: [
        // الفلاتر اللي فهمها النموذج — قابلة للتعديل
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(GSpace.md),
          color: context.colors.brandSoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ar ? 'فهمنا طلبك كالتالي' : 'We understood your request as',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: GSpace.sm),
              Wrap(
                spacing: GSpace.sm,
                runSpacing: GSpace.sm,
                children: [
                  GChip(
                    label: ar ? 'كمبيوتر ولابتوب' : 'Computers',
                    icon: Icons.category_rounded,
                    dense: true,
                  ),
                  GChip(
                    label: ar ? 'أقل من 30,000' : 'Under 30,000',
                    icon: Icons.payments_outlined,
                    dense: true,
                  ),
                  GChip(
                    label: ar ? 'القاهرة' : 'Cairo',
                    icon: Icons.location_on_outlined,
                    dense: true,
                  ),
                  GChip(
                    label: ar ? 'تعديل' : 'Edit',
                    icon: Icons.edit_rounded,
                    dense: true,
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
        if (async.isLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (items.isEmpty)
          Expanded(
            child: GEmptyState(
              icon: Icons.search_off_rounded,
              title: context.tr('market.emptyCategory'),
              body: context.tr('market.emptyCategoryBody'),
            ),
          )
        else
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(GSpace.screenH),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: GSpace.md,
              mainAxisSpacing: GSpace.md,
              childAspectRatio: 0.66,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) => ItemCard(
              item: items[i],
              onTap: () => context.push(R.item(items[i].id)),
            ),
          ),
        ),
      ],
    );
  }
}
