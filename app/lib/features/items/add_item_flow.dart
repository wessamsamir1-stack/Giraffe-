import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_state.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/catalog/categories.dart';
import '../../data/models/models.dart';
import '../../data/repositories/ai_repository.dart';
import '../../data/repositories/providers.dart';
import '../../widgets/g_button.dart';
import '../../widgets/g_common.dart';
import '../../widgets/g_text_field.dart';

/// رفع منتج — أربع خطوات.
///
/// الترتيب الفعلي للعمليات:
///
///   1. المستخدم يختار الصور (في الذاكرة لسه)
///   2. ننشئ المنتج كمسودة، نرفع الصور، وندي الذكاء الاصطناعي يحللها
///   3. المستخدم يراجع الاقتراحات ويعدّل — **هو اللي بيقرر**
///   4. تفضيلات المقايضة، ثم النشر ثم فحص المحتوى
///
/// قاعدة حاكمة: **المستخدم مايتوقفش أبداً**. لو التحليل فشل أو السقف
/// اتعدى، بيكمل إدخال يدوي من غير ما يشوف رسالة خطأ.
class AddItemFlowScreen extends ConsumerStatefulWidget {
  const AddItemFlowScreen({super.key});

  @override
  ConsumerState<AddItemFlowScreen> createState() => _AddItemFlowScreenState();
}

class _AddItemFlowScreenState extends ConsumerState<AddItemFlowScreen> {
  final _picker = ImagePicker();

  int _step = 0;
  final List<XFile> _photos = [];

  String? _itemId;
  ItemSuggestion _suggestion = const ItemSuggestion();
  ValueEstimate? _estimate;

  // نتائج المراجعة
  final _title = TextEditingController();
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _description = TextEditingController();
  String _category = 'misc';
  String? _subCategory;
  ItemCondition _condition = ItemCondition.good;

  final _willPay = TextEditingController();
  final Set<String> _wanted = {};
  bool _acceptDiff = true;

  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _brand.dispose();
    _model.dispose();
    _description.dispose();
    _willPay.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  Future<void> _pick({required bool camera}) async {
    try {
      if (camera) {
        final shot = await _picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1600,
          imageQuality: 82,
        );
        if (shot != null && _photos.length < 6) {
          setState(() => _photos.add(shot));
        }
        return;
      }

      final picked = await _picker.pickMultiImage(
        maxWidth: 1600,
        imageQuality: 82,
      );
      setState(() {
        for (final file in picked) {
          if (_photos.length < 6) _photos.add(file);
        }
      });
    } catch (_) {
      if (mounted) _toast(context.tr('common.error'));
    }
  }

  /// إنشاء المسودة ورفع الصور ثم التحليل.
  Future<void> _uploadAndAnalyze() async {
    setState(() {
      _busy = true;
      _step = 1;
    });

    final country = ref.read(countryProvider);
    final city = ref.read(cityProvider);

    final itemId = await ref.read(itemsRepositoryProvider).create(
          title: 'مسودة',
          description: '',
          categoryId: 'misc',
          condition: ItemCondition.good,
          countryCode: country.code,
          cityId: city.id,
          currencyCode: country.currency.code,
        );

    if (itemId == null) {
      if (mounted) {
        setState(() {
          _busy = false;
          _step = 2;   // إدخال يدوي — مانوقفش المستخدم
        });
      }
      return;
    }
    _itemId = itemId;

    final storage = ref.read(storageRepositoryProvider);
    final items = ref.read(itemsRepositoryProvider);

    for (var i = 0; i < _photos.length; i++) {
      final Uint8List bytes = await _photos[i].readAsBytes();
      final path = await storage.uploadItemPhoto(
        itemId: itemId,
        position: i,
        bytes: bytes,
      );
      if (path != null) {
        await items.attachPhoto(
          itemId: itemId,
          storagePath: path,
          position: i,
        );
      }
    }

    final suggestion = await ref.read(aiRepositoryProvider).analyzeItem(itemId);
    if (!mounted) return;

    // تعبئة الحقول بالاقتراحات — والمستخدم يعدّل اللي عايزه
    _suggestion = suggestion;
    _title.text = suggestion.title ?? '';
    _brand.text = suggestion.brand ?? '';
    _model.text = suggestion.model ?? '';
    _description.text = suggestion.description ?? '';
    _category = suggestion.categoryId ?? 'misc';
    _subCategory = suggestion.subCategoryId;
    _condition = suggestion.condition ?? ItemCondition.good;

    final estimate = await ref.read(aiRepositoryProvider).estimateValue(
          itemId: itemId,
          categoryId: _category,
          subCategoryId: _subCategory,
          brand: _brand.text,
          model: _model.text,
          condition: _condition,
          countryCode: country.code,
        );

    if (!mounted) return;
    setState(() {
      _estimate = estimate;
      _busy = false;
      _step = 2;
    });
  }

  /// النشر: حفظ المراجعة ثم فحص المحتوى.
  Future<void> _publish() async {
    if (_itemId == null) {
      if (mounted) context.pop();
      return;
    }

    setState(() => _busy = true);

    final error = await ref.read(itemsRepositoryProvider).update(
          itemId: _itemId!,
          title: _title.text,
          description: _description.text,
          categoryId: _category,
          subCategoryId: _subCategory,
          condition: _condition,
          brand: _brand.text,
          model: _model.text,
          valueMin: _estimate?.min,
          valueMax: _estimate?.max,
          aiConfidence: _estimate?.confidence ?? 0,
          comparableCount: _estimate?.sampleSize ?? 0,
          willPayUpTo: double.tryParse(_willPay.text) ?? 0,
          acceptsCashDiff: _acceptDiff,
          status: ItemStatus.pending,
          wantedCategoryIds: _wanted.toList(),
        );

    if (!mounted) return;

    if (error != null) {
      setState(() => _busy = false);
      _toast(context.tr(error));
      return;
    }

    final decision = await ref.read(aiRepositoryProvider).moderateItem(_itemId!);
    if (!mounted) return;

    setState(() => _busy = false);

    ref.invalidate(myItemsProvider);
    ref.invalidate(marketFeedProvider);
    ref.invalidate(deckProvider);

    _toast(switch (decision) {
      ModerationDecision.approved => context.tr('add.publish'),
      ModerationDecision.rejected => context.tr('safety.banned'),
      // معلّم أو غير معروف = مراجعة بشرية، والمنتج لسه مش ظاهر
      _ => context.tr('report.sent'),
    });

    if (mounted) context.pop();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ---------------------------------------------------------------------------
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
            photos: _photos,
            onCamera: () => _pick(camera: true),
            onGallery: () => _pick(camera: false),
            onRemove: (i) => setState(() => _photos.removeAt(i)),
            onNext: _uploadAndAnalyze,
          ),
        1 => _AnalyzingStep(onManual: () => setState(() => _step = 2)),
        2 => _reviewStep(),
        _ => _preferencesStep(),
      },
    );
  }

  // ---------------------------------------------------------------------------
  Widget _reviewStep() {
    final c = context.colors;
    final ar = context.s.isArabic;
    final country = ref.watch(countryProvider);

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

              if (!_suggestion.isEmpty)
                GChip(
                  label: context.tr('add.review.aiFilled'),
                  icon: Icons.auto_awesome_rounded,
                  color: c.brand,
                  background: c.brandSoft,
                  dense: true,
                ),
              const SizedBox(height: GSpace.xl),

              // نطاق القيمة — نطاق دايماً، ومعاه مصدره
              _EstimateBox(estimate: _estimate, isArabic: ar),

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
                  for (final category in Categories.all)
                    GChip(
                      label: category.name(ar),
                      icon: category.icon,
                      selected: _category == category.id,
                      onTap: () => setState(() {
                        _category = category.id;
                        _subCategory = null;
                      }),
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

              const SizedBox(height: GSpace.lg),
              GButton(
                label: context.tr('price.estimate'),
                icon: Icons.refresh_rounded,
                style: GButtonStyle.ghost,
                size: GButtonSize.small,
                loading: _busy,
                onPressed: () async {
                  setState(() => _busy = true);
                  final estimate =
                      await ref.read(aiRepositoryProvider).estimateValue(
                            itemId: _itemId,
                            categoryId: _category,
                            subCategoryId: _subCategory,
                            brand: _brand.text,
                            model: _model.text,
                            condition: _condition,
                            countryCode: country.code,
                          );
                  if (!mounted) return;
                  setState(() {
                    _estimate = estimate;
                    _busy = false;
                  });
                },
              ),
            ],
          ),
        ),
        _BottomBar(
          child: GButton(
            label: context.tr('common.next'),
            onPressed: _title.text.trim().length < 3
                ? null
                : () => setState(() => _step = 3),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  Widget _preferencesStep() {
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
              const SizedBox(height: GSpace.xs),
              Text(
                ar
                    ? 'الاختيار ده هو نص شرط المطابقة — من غيره منتجك مش هيظهر لحد.'
                    : 'This is half of the matching condition — without it your item reaches no one.',
                style: Theme.of(context).textTheme.bodyMedium,
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
              const SizedBox(height: GSpace.md),
              GNotice(
                icon: Icons.visibility_outlined,
                text: ar
                    ? 'المنتج بيتفحص قبل ما يظهر في السوق. غالباً دقايق.'
                    : 'Your item is screened before it appears in the market. Usually minutes.',
              ),
            ],
          ),
        ),
        _BottomBar(
          child: GButton(
            label: context.tr('add.publish'),
            loading: _busy,
            onPressed: _wanted.isEmpty ? null : _publish,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 1. الصور
// =============================================================================
class _PhotosStep extends StatelessWidget {
  const _PhotosStep({
    required this.photos,
    required this.onCamera,
    required this.onGallery,
    required this.onRemove,
    required this.onNext,
  });

  final List<XFile> photos;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final ValueChanged<int> onRemove;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final count = photos.length;

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
                      onTap: onGallery,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: c.surfaceAlt,
                          borderRadius: GRadius.brMd,
                          border: Border.all(color: c.borderStrong, width: 1.4),
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
                        child: ClipRRect(
                          borderRadius: GRadius.brMd,
                          child: Image.network(
                            photos[i].path,
                            fit: BoxFit.cover,
                            // على الموبايل المسار محلي مش شبكي — بنقع على
                            // البديل الملوّن بدل ما نعرض أيقونة كسر
                            errorBuilder: (_, __, ___) => GImagePlaceholder(
                              seed: 30 + i,
                              radius: GRadius.brMd,
                            ),
                          ),
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
                      onPressed: onCamera,
                    ),
                  ),
                  const SizedBox(width: GSpace.sm),
                  Expanded(
                    child: GButton(
                      label: context.tr('add.photos.gallery'),
                      icon: Icons.photo_library_outlined,
                      style: GButtonStyle.ghost,
                      size: GButtonSize.small,
                      onPressed: onGallery,
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

// =============================================================================
// 2. التحليل
// =============================================================================
class _AnalyzingStep extends StatelessWidget {
  const _AnalyzingStep({required this.onManual});

  final VoidCallback onManual;

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
            for (var i = 1; i <= 3; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: GSpace.sm),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.radio_button_unchecked_rounded,
                      size: 17,
                      color: c.textTertiary,
                    ),
                    const SizedBox(width: GSpace.sm),
                    Text(
                      context.tr('add.analyzing.step$i'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: GSpace.xxl),
            // مخرج فوري لو الخدمة بطيئة — المستخدم مايتحبسش في انتظار
            TextButton(
              onPressed: onManual,
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

// =============================================================================
/// صندوق نطاق القيمة.
///
/// لو مفيش تقدير (ثقة منخفضة أو مفيش مقارنات) بنقول للمستخدم صراحة
/// إنه يحدد القيمة بنفسه — **مانخمّنش**.
class _EstimateBox extends StatelessWidget {
  const _EstimateBox({required this.estimate, required this.isArabic});

  final ValueEstimate? estimate;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (estimate == null) {
      return GNotice(
        tone: GNoticeTone.warning,
        icon: Icons.help_outline_rounded,
        text: context.tr('price.lowConfidence'),
      );
    }

    final e = estimate!;

    return GSurface(
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
            '${e.min.round()} – ${e.max.round()} ${e.currencyCode}',
            style: Theme.of(context).textTheme.headlineSmall,
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(height: GSpace.xs),
          Text(
            e.fromOurData
                ? context.trf('price.basedOn', {
                    'n': e.sampleSize,
                    'market': isArabic ? 'السوق المحلي' : 'the local market',
                  })
                : (isArabic
                    ? 'تقدير مبدئي — هيبقى أدق مع أول صفقات في القسم ده'
                    : 'Early estimate — improves as trades complete'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: GSpace.sm),
          Text(
            context.tr('price.disclaimer'),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: c.textTertiary, fontSize: 11.5),
          ),
        ],
      ),
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
