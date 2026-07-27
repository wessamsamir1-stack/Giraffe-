import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/catalog/categories.dart';
import '../../data/repositories/moderation_repository.dart';
import '../../data/repositories/providers.dart';
import '../../widgets/g_button.dart';
import '../../widgets/g_common.dart';

/// شاشة الحكم على منتج معلّم.
///
/// قاعدتان في التصميم:
///
///   **١.** الرفض لازم معاه سبب. المستخدم بيتبلّغ بالسبب، ومن غيره
///        بيتعلّم إن القرار عشوائي — وبيعيد نفس الغلطة.
///
///   **٢.** الاعتماد أسهل من الرفض عن قصد. الرفض الخاطئ بيطرد مستخدم
///        شرعي، والاعتماد الخاطئ بيتصلّح ببلاغ. التكلفتان مش متساويتين.
class ModerationReviewScreen extends ConsumerStatefulWidget {
  const ModerationReviewScreen({super.key, required this.itemId});

  final String itemId;

  @override
  ConsumerState<ModerationReviewScreen> createState() =>
      _ModerationReviewScreenState();
}

class _ModerationReviewScreenState
    extends ConsumerState<ModerationReviewScreen> {
  final _reason = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _decide(bool approve) async {
    if (!approve) {
      final reason = _reason.text.trim();
      if (reason.length < 3) {
        _toast(context.tr('mod.err.reason'));
        return;
      }

      final sure = await _confirmReject(reason);
      if (sure != true) return;
    }

    setState(() => _busy = true);

    final error = await ref.read(moderationRepositoryProvider).decide(
          itemId: widget.itemId,
          approve: approve,
          reason: approve ? null : _reason.text.trim(),
        );

    if (!mounted) return;
    setState(() => _busy = false);

    if (error != null) {
      _toast(context.tr(error));
      return;
    }

    ref.invalidate(moderationQueueProvider);
    ref.invalidate(moderationStatsProvider);

    _toast(context.tr(approve ? 'mod.approved' : 'mod.rejected'));
    if (mounted) context.pop();
  }

  /// الرفض بيتأكد مرة تانية — ده بيوصل لمستخدم حقيقي.
  Future<bool?> _confirmReject(String reason) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('mod.confirmReject')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ctx.tr('mod.confirmRejectBody')),
            const SizedBox(height: GSpace.md),
            Text(
              '«$reason»',
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.tr('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.tr('mod.reject')),
          ),
        ],
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final queue = ref.watch(moderationQueueProvider(FlagKind.content));

    final entry = queue.valueOrNull
        ?.where((e) => e.itemId == widget.itemId)
        .toList();

    if (entry == null || entry.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('mod.review'))),
        body: Center(
          child: queue.isLoading
              ? const CircularProgressIndicator()
              : GEmptyState(
                  icon: Icons.check_circle_outline_rounded,
                  title: context.tr('mod.gone'),
                  body: context.tr('mod.goneBody'),
                  tone: GEmptyTone.brand,
                ),
        ),
      );
    }

    final it = entry.first;
    final category = Categories.byId(it.categoryId);
    final ar = context.s.isArabic;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('mod.review'))),
      body: ListView(
        padding: const EdgeInsets.all(GSpace.screenH),
        children: [
          // -------------------------------------------------------------------
          // ليه اتعلّم — أول حاجة المراجع لازم يشوفها
          // -------------------------------------------------------------------
          GNotice(
            tone: GNoticeTone.warning,
            icon: Icons.report_gmailerrorred_rounded,
            text: it.flagNote ?? context.tr('mod.noReason'),
          ),

          if (it.openReports > 0) ...[
            const SizedBox(height: GSpace.sm),
            GNotice(
              tone: GNoticeTone.danger,
              icon: Icons.flag_rounded,
              text: context.trf('mod.reportsOn', {'n': it.openReports}),
            ),
          ],

          const SizedBox(height: GSpace.lg),

          // -------------------------------------------------------------------
          // المنتج
          // -------------------------------------------------------------------
          GSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(it.title,
                    style: Theme.of(context).textTheme.titleMedium,),
                const SizedBox(height: GSpace.sm),
                if (it.description != null && it.description!.isNotEmpty)
                  Text(it.description!,
                      style: Theme.of(context).textTheme.bodyMedium,),
                const SizedBox(height: GSpace.md),
                Wrap(
                  spacing: GSpace.sm,
                  runSpacing: GSpace.sm,
                  children: [
                    GChip(
                      label: category.name(ar),
                      icon: category.icon,
                      dense: true,
                    ),
                    GChip(
                      label: context.trf('mod.photos', {'n': it.photoCount}),
                      icon: Icons.photo_library_outlined,
                      dense: true,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: GSpace.md),

          // -------------------------------------------------------------------
          // صاحب المنتج — السجل بيغيّر الحكم
          // -------------------------------------------------------------------
          GSurface(
            child: Row(
              children: [
                Icon(Icons.person_outline_rounded, color: c.textSecondary),
                const SizedBox(width: GSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(it.ownerName,
                          style: Theme.of(context).textTheme.titleSmall,),
                      Text(
                        context.trf('mod.ownerHistory', {
                          'trades': it.ownerTrades,
                        }),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                GChip(
                  label: context.tr('trust.${it.ownerTrust}'),
                  dense: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: GSpace.xl),

          // -------------------------------------------------------------------
          // القرار
          // -------------------------------------------------------------------
          Text(
            context.tr('mod.decision'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: GSpace.md),

          GButton(
            label: context.tr('mod.approve'),
            icon: Icons.check_rounded,
            style: GButtonStyle.success,
            loading: _busy,
            onPressed: () => _decide(true),
          ),

          const SizedBox(height: GSpace.xl),

          Text(
            context.tr('mod.rejectReason'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: GSpace.xs),
          Text(
            context.tr('mod.rejectReasonHint'),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: c.textTertiary),
          ),
          const SizedBox(height: GSpace.sm),
          TextField(
            controller: _reason,
            maxLines: 2,
            maxLength: 200,
            decoration: InputDecoration(
              hintText: context.tr('mod.rejectReasonPlaceholder'),
              border: const OutlineInputBorder(borderRadius: GRadius.brLg),
            ),
          ),
          const SizedBox(height: GSpace.sm),
          GButton(
            label: context.tr('mod.reject'),
            icon: Icons.block_rounded,
            style: GButtonStyle.danger,
            loading: _busy,
            onPressed: () => _decide(false),
          ),

          const SizedBox(height: GSpace.xl),
          GNotice(
            tone: GNoticeTone.info,
            icon: Icons.history_rounded,
            text: context.tr('mod.logged'),
          ),
        ],
      ),
    );
  }
}
