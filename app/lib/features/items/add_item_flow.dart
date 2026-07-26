import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/catalog/categories.dart';
import '../../data/models/models.dart';
import '../../widgets/g_button.dart';
import '../../widgets/g_common.dart';
import '../../widgets/g_text_field.dart';

/// رفع منتج — 4 خطوات في تدفق واحد.
///
/// 1. الصور
/// 2. التحليل بالذكاء الاصطناعي
/// 3. مراجعة البيانات (المستخدم بيقدر يعدّل كل حاجة)
/// 4. تفضيلات المقايضة
///
/// قاعدة ثابتة: **الذكاء الاصطناعي بيقترح والمستخدم بيقرر**.
/// ولو التحليل فشل، بنروح على الإدخال اليدوي فوراً — المستخدم
/// مايتوقفش أبداً بسبب عطل في خدمة خارجية.
class AddItemFlowScreen extends StatefulWidget {
  const AddItemFlowScreen({super.key});

  @override
  State<AddItemFlowScreen> createState() => _AddItemFlowScreenState();
}

class _AddItemFlowScreenState extends State<AddItemFlowScreen> {
  int _step = 0;
  int _photos = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('items.add')),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_step + 1) / 4,
            minHeight: 4,
            backgroundColor: context.colors.surfaceSunken,
            valueColor: AlwaysStoppedAnimation(context.colors.brand),
          ),
        ),
      ),
      body: switch (_step) {
        0 => _PhotosStep(
            count: _photos,
            onAdd: () => setState(() => _photos = (_photos + 1).clamp(0, 6)),
            onRemove: (i) => setState(() => _photos--),
            onNext: () => setState(() => _step = 1),
          ),
        1 => _AnalyzingStep(
            onDone: () => setState(() => _step = 2),
            onManual: () => setState(() => _step = 2),
          ),
        2 => _ReviewStep(onNext: () => setState(() => _step = 3)),
        _ => _PreferencesStep(onPublish: () => context.pop()),
      },
    );
  }
}

// ---------------------------------------------------------------- 1. الصور
class _PhotosStep extends StatelessWidget {
  const _PhotosStep({
    required this.count,
    required this.onAdd,
    required this.onRemove,
    required this.onNext,
  });

  final int count;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(GSpace.screenH),
            children: [
              Text(
                context.tr('add.photos.title'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: GSpace.xs),
              Text(
                context.tr('add.photos.body'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: GSpace.xl),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: GSpace.md,
                  mainAxisSpacing: GSpace.md,
                ),
                itemCount: count < 6 ? count + 1 : 6,
                itemBuilder: (context, i) {
                  if (i == count) {
                    return GestureDetector(
                      onTap: onAdd,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: c.surfaceAlt,
                          borderRadius: GRadius.brMd,
                          border: Border.all(
                            color: c.borderStrong,
                            width: 1.4,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.add_a_photo_outlined,
                            size: 26,
                            color: c.textTertiary,
                          ),
                        ),
                      ),
                    );
                  }
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: GImagePlaceholder(
                          seed: 30 + i,
                          radius: GRadius.brMd,
                        ),
                      ),
                      if (i == 0)
                        PositionedDirectional(
                          bottom: GSpace.xs,
                          start: GSpace.xs,
                          child: GChip(
                            label: context.s.isArabic ? 'رئيسية' : 'Cover',
                            color: Colors.white,
                            background: Colors.black.withOpacity(0.5),
                            dense: true,
                          ),
                        ),
                      PositionedDirectional(
                        top: GSpace.xs,
                        end: GSpace.xs,
                        child: GestureDetector(
                          onTap: () => onRemove(i),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: GSpace.xl),
              Row(
                children: [
                  Expanded(
                    child: GButton(
                      label: context.tr('add.photos.camera'),
                      icon: Icons.photo_camera_rounded,
                      style: GButtonStyle.ghost,
                      size: GButtonSize.small,
                      onPressed: onAdd,
                    ),
                  ),
                  const SizedBox(width: GSpace.sm),
                  Expanded(
                    child: GButton(
                      label: context.tr('add.photos.gallery'),
                      icon: Icons.photo_library_outlined,
                      style: GButtonStyle.ghost,
                      size: GButtonSize.small,
                      onPressed: onAdd,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: GSpace.xl),
              GNotice(
                icon: Icons.lightbulb_outline_rounded,
                text: context.tr('add.photos.tip'),
              ),
            ],
          ),
        ),
        _BottomBar(
          child: GButton(
            label: context.tr('common.next'),
            onPressed: count > 0 ? onNext : null,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- 2. التحليل
class _AnalyzingStep extends StatefulWidget {
  const _AnalyzingStep({required this.onDone, required this.onManual});

  final VoidCallback onDone;
  final VoidCallback onManual;

  @override
  State<_AnalyzingStep> createState() => _AnalyzingStepState();
}

class _AnalyzingStepState extends State<_AnalyzingStep> {
  int _stage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 900), (t) {
      if (!mounted) return;
      setState(() => _stage++);
      if (_stage >= 3) {
        t.cancel();
        widget.onDone();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(GSpace.xxxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 84,
              height: 84,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(c.brand),
              ),
            ),
            const SizedBox(height: GSpace.xxl),
            Text(
              context.tr('add.analyzing.title'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: GSpace.xl),
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: GSpace.sm),
                child: Row(
                  children: [
                    Icon(
                      i < _stage
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 17,
                      color: i < _stage ? c.success : c.textTertiary,
                    ),
                    const SizedBox(width: GSpace.sm),
                    Text(
                      context.tr('add.analyzing.step${i + 1}'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: GSpace.xxl),
            // مخرج فوري لو الخدمة بطيئة أو فاشلة
            TextButton(
              onPressed: widget.onManual,
              child: Text(
                context.tr('add.analyzing.manual'),
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: c.brand),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 3. المراجعة
class _ReviewStep extends StatefulWidget {
  const _ReviewStep({required this.onNext});

  final VoidCallback onNext;

  @override
  State<_ReviewStep> createState() => _ReviewStepState();
}

class _ReviewStepState extends State<_ReviewStep> {
  final _title = TextEditingController(text: 'آيفون 15 برو 256 جيجا');
  final _brand = TextEditingController(text: 'Apple');
  final _model = TextEditingController(text: 'iPhone 15 Pro');
  final _description = TextEditingController(
    text: 'بطارية 94%. بالعلبة والشاحن. مفيش أي خدوش.',
  );

  String _category = 'mobiles';
  ItemCondition _condition = ItemCondition.likeNew;

  @override
  void dispose() {
    _title.dispose();
    _brand.dispose();
    _model.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ar = context.s.isArabic;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(GSpace.screenH),
            children: [
              Text(
                context.tr('add.review.title'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: GSpace.xs),
              Text(
                context.tr('add.review.body'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: GSpace.lg),

              GChip(
                label: context.tr('add.review.aiFilled'),
                icon: Icons.auto_awesome_rounded,
                color: c.brand,
                background: c.brandSoft,
                dense: true,
              ),
              const SizedBox(height: GSpace.xl),

              // نطاق القيمة — نطاق مش رقم، مع المصدر وإخلاء المسؤولية
              GSurface(
                color: c.brandSoft,
                bordered: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('price.estimate'),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: GSpace.xs),
                    Text(
                      '38,000 – 44,000 ${ar ? 'ج.م' : 'EGP'}',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textDirection: TextDirection.ltr,
                    ),
                    const SizedBox(height: GSpace.xs),
                    Text(
                      context.trf('price.basedOn', {
                        'n': 31,
                        'market': ar ? 'مصر' : 'Egypt',
                      }),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: GSpace.sm),
                    Text(
                      context.tr('price.disclaimer'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: c.textTertiary,
                            fontSize: 11.5,
                          ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: GSpace.xl),
              GTextField(
                label: context.tr('setup.displayName'),
                controller: _title,
                prefixIcon: Icons.title_rounded,
                maxLength: 80,
              ),
              const SizedBox(height: GSpace.lg),

              Text(
                context.tr('item.category'),
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: GSpace.sm),
              Wrap(
                spacing: GSpace.sm,
                runSpacing: GSpace.sm,
                children: [
                  for (final category in Categories.featured)
                    GChip(
                      label: category.name(ar),
                      icon: category.icon,
                      selected: _category == category.id,
                      onTap: () => setState(() => _category = category.id),
                    ),
                ],
              ),

              const SizedBox(height: GSpace.lg),
              Text(
                context.tr('item.condition'),
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: GSpace.sm),
              Wrap(
                spacing: GSpace.sm,
                runSpacing: GSpace.sm,
                children: [
                  for (final condition in ItemCondition.values)
                    GChip(
                      label: context.tr(condition.labelKey),
                      selected: _condition == condition,
                      onTap: () => setState(() => _condition = condition),
                    ),
                ],
              ),

              const SizedBox(height: GSpace.lg),
              Row(
                children: [
                  Expanded(
                    child: GTextField(
                      label: context.tr('item.brand'),
                      controller: _brand,
                    ),
                  ),
                  const SizedBox(width: GSpace.md),
                  Expanded(
                    child: GTextField(
                      label: context.tr('item.model'),
                      controller: _model,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: GSpace.lg),
              GTextField(
                label: context.tr('item.description'),
                controller: _description,
                maxLines: 4,
                maxLength: 600,
              ),
            ],
          ),
        ),
        _BottomBar(
          child: GButton(
            label: context.tr('common.next'),
            onPressed: widget.onNext,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- 4. التفضيلات
class _PreferencesStep extends StatefulWidget {
  const _PreferencesStep({required this.onPublish});

  final VoidCallback onPublish;

  @override
  State<_PreferencesStep> createState() => _PreferencesStepState();
}

class _PreferencesStepState extends State<_PreferencesStep> {
  final Set<String> _wanted = {};
  final _willPay = TextEditingController();
  bool _acceptDiff = true;

  @override
  void dispose() {
    _willPay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ar = context.s.isArabic;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(GSpace.screenH),
            children: [
              Text(
                context.tr('add.prefs.title'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: GSpace.xl),

              Text(
                context.tr('add.prefs.tradeFor'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: GSpace.sm),
              Wrap(
                spacing: GSpace.sm,
                runSpacing: GSpace.sm,
                children: [
                  for (final category in Categories.all)
                    GChip(
                      label: category.name(ar),
                      icon: category.icon,
                      selected: _wanted.contains(category.id),
                      onTap: () => setState(() {
                        if (!_wanted.remove(category.id)) {
                          _wanted.add(category.id);
                        }
                      }),
                    ),
                ],
              ),

              const SizedBox(height: GSpace.xl),
              GTextField(
                label: context.tr('add.prefs.willPay'),
                controller: _willPay,
                keyboardType: TextInputType.number,
                prefixIcon: Icons.payments_outlined,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),

              const SizedBox(height: GSpace.lg),
              GSurface(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr('add.prefs.willReceive'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Switch(
                      value: _acceptDiff,
                      activeColor: context.colors.brand,
                      onChanged: (v) => setState(() => _acceptDiff = v),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: GSpace.xl),
              GNotice(
                tone: GNoticeTone.warning,
                icon: Icons.gavel_rounded,
                text: context.tr('safety.bannedBody'),
              ),
            ],
          ),
        ),
        _BottomBar(
          child: GButton(
            label: context.tr('add.publish'),
            onPressed: _wanted.isEmpty ? null : widget.onPublish,
          ),
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(GSpace.screenH),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(top: false, child: child),
    );
  }
}
