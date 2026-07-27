import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/repositories/moderation_repository.dart';
import '../../data/repositories/providers.dart';
import '../../widgets/g_button.dart';
import '../../widgets/g_common.dart';

/// طابور بلاغات المستخدمين والرسايل.
///
/// بلاغات المنتجات **مش هنا** — دي بتظهر مع المنتج نفسه في طابور
/// المراجعة وبتتقفل مع قراره. تكرارها هنا معناه إن المراجع يحكم على
/// نفس الحاجة مرتين.
class ReportsQueueScreen extends ConsumerWidget {
  const ReportsQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final queue = ref.watch(reportsQueueProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('reports.title'))),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(reportsQueueProvider),
        child: ListView(
          padding: const EdgeInsets.all(GSpace.screenH),
          children: [
            queue.when(
              loading: () => const Column(
                children: [
                  GSkeleton(height: 120, radius: GRadius.brLg),
                  SizedBox(height: GSpace.md),
                  GSkeleton(height: 120, radius: GRadius.brLg),
                ],
              ),
              error: (_, __) => GEmptyState(
                icon: Icons.error_outline_rounded,
                title: context.tr('common.error'),
                body: context.tr('mod.err.notStaff'),
              ),
              data: (rows) {
                if (rows.isEmpty) {
                  return GEmptyState(
                    icon: Icons.verified_user_outlined,
                    title: context.tr('reports.empty'),
                    body: context.tr('reports.emptyBody'),
                    tone: GEmptyTone.brand,
                  );
                }
                return Column(
                  children: [
                    for (final entry in rows) ...[
                      _ReportCard(entry: entry),
                      const SizedBox(height: GSpace.md),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: GSpace.xl),
            Text(
              context.tr('reports.footer'),
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: c.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends ConsumerStatefulWidget {
  const _ReportCard({required this.entry});

  final ReportEntry entry;

  @override
  ConsumerState<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends ConsumerState<_ReportCard> {
  bool _busy = false;

  Future<void> _decide(ReportAction action) async {
    String? reason;

    // الرفض بس هو اللي بيعدّي من غير سبب. أي إجراء عقابي بيوصل
    // لمستخدم حقيقي، فلازم يبقى مكتوب ليه.
    if (action != ReportAction.dismissed) {
      reason = await _askReason(action);
      if (reason == null) return;
    }

    setState(() => _busy = true);

    final error = await ref.read(moderationRepositoryProvider).decideReport(
          reportId: widget.entry.reportId,
          action: action,
          reason: reason,
        );

    if (!mounted) return;
    setState(() => _busy = false);

    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr(error))));
      return;
    }

    ref.invalidate(reportsQueueProvider);
  }

  Future<String?> _askReason(ReportAction action) {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('reports.action.${action.name}')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ctx.tr('reports.reasonHint')),
            const SizedBox(height: GSpace.md),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 200,
              decoration: const InputDecoration(
                border: OutlineInputBorder(borderRadius: GRadius.brLg),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(ctx.tr('common.cancel')),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.length < 3) return;
              Navigator.of(ctx).pop(text);
            },
            child: Text(ctx.tr('common.confirm')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final e = widget.entry;

    return GSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                e.isMessage ? Icons.chat_bubble_outline_rounded
                            : Icons.person_outline_rounded,
                size: 16,
                color: c.textSecondary,
              ),
              const SizedBox(width: GSpace.xs),
              Expanded(
                child: Text(
                  e.targetLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),

              // أقوى إشارة عندنا: خمس ناس مختلفين بلّغوا مش صدفة
              if (e.reportsOnTarget > 1)
                GChip(
                  label: context.trf('reports.count', {
                    'n': e.reportsOnTarget,
                  }),
                  icon: Icons.flag_rounded,
                  color: c.danger,
                  background: c.danger.withOpacity(0.12),
                  dense: true,
                ),
            ],
          ),
          const SizedBox(height: GSpace.sm),

          GChip(
            label: context.tr('report.reason.${e.reason}'),
            dense: true,
          ),

          // نص الرسالة — المراجع مايقدرش يحكم من غيره
          if (e.targetBody != null) ...[
            const SizedBox(height: GSpace.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(GSpace.sm),
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: GRadius.brMd,
              ),
              child: Text(
                e.targetBody!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],

          if (e.details != null && e.details!.isNotEmpty) ...[
            const SizedBox(height: GSpace.sm),
            Text(
              context.trf('reports.said', {
                'name': e.reporterName,
                'text': e.details!,
              }),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],

          const SizedBox(height: GSpace.md),
          Row(
            children: [
              Expanded(
                child: GButton(
                  label: context.tr('reports.action.dismissed'),
                  style: GButtonStyle.ghost,
                  loading: _busy,
                  onPressed: () => _decide(ReportAction.dismissed),
                ),
              ),
              const SizedBox(width: GSpace.sm),
              Expanded(
                child: GButton(
                  label: context.tr(
                    e.isMessage ? 'reports.action.removed'
                                : 'reports.action.warned',
                  ),
                  style: GButtonStyle.secondary,
                  loading: _busy,
                  onPressed: () => _decide(
                    e.isMessage ? ReportAction.removed : ReportAction.warned,
                  ),
                ),
              ),
            ],
          ),

          if (!e.isMessage) ...[
            const SizedBox(height: GSpace.sm),
            GButton(
              label: context.tr('reports.action.banned'),
              icon: Icons.gavel_rounded,
              style: GButtonStyle.danger,
              loading: _busy,
              onPressed: () => _decide(ReportAction.banned),
            ),
          ],
        ],
      ),
    );
  }
}
