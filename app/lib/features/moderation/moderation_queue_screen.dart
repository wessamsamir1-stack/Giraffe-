import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/repositories/moderation_repository.dart';
import '../../data/repositories/providers.dart';
import '../../widgets/g_button.dart';
import '../../widgets/g_common.dart';

/// طابور المراجعة البشرية.
///
/// الطابور مقسوم عن قصد:
///
///   • **محتاج حكم** — الموديل شاف حاجة وقال «راجعوا ده»
///   • **تعثّر النظام** — سقف أو موديل مارّدش. مش محتاج حكم، محتاج
///     إعادة محاولة — بزر واحد لكل الدفعة.
///
/// خلطهم في طابور واحد بيهدر أندر مورد عندنا: انتباه المراجع. لو
/// معظم الطابور أعطال نظام، المراجع بيقلب على الوضع الآلي وبيعدّي
/// الحالة الحقيقية اللي كانت محتاجاه.
class ModerationQueueScreen extends ConsumerStatefulWidget {
  const ModerationQueueScreen({super.key});

  @override
  ConsumerState<ModerationQueueScreen> createState() =>
      _ModerationQueueScreenState();
}

class _ModerationQueueScreenState extends ConsumerState<ModerationQueueScreen> {
  FlagKind _kind = FlagKind.content;
  bool _requeuing = false;

  Future<void> _requeue() async {
    setState(() => _requeuing = true);
    final n = await ref.read(moderationRepositoryProvider).requeueSystemFlags();

    if (!mounted) return;
    setState(() => _requeuing = false);

    ref.invalidate(moderationQueueProvider);
    ref.invalidate(moderationStatsProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.trf('mod.requeued', {'n': n}))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final stats = ref.watch(moderationStatsProvider).valueOrNull;
    final queue = ref.watch(moderationQueueProvider(_kind));

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('mod.title'))),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(moderationQueueProvider);
          ref.invalidate(moderationStatsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(GSpace.screenH),
          children: [
            if (stats != null) _StatsHeader(stats: stats),
            const SizedBox(height: GSpace.lg),

            // التبويبان
            Row(
              children: [
                Expanded(
                  child: GChip(
                    label: context.trf('mod.needsJudgement', {
                      'n': stats?.pendingContent ?? 0,
                    }),
                    icon: Icons.gavel_rounded,
                    selected: _kind == FlagKind.content,
                    onTap: () => setState(() => _kind = FlagKind.content),
                  ),
                ),
                const SizedBox(width: GSpace.sm),
                Expanded(
                  child: GChip(
                    label: context.trf('mod.systemFlags', {
                      'n': stats?.pendingSystem ?? 0,
                    }),
                    icon: Icons.sync_problem_rounded,
                    selected: _kind == FlagKind.system,
                    onTap: () => setState(() => _kind = FlagKind.system),
                  ),
                ),
              ],
            ),
            const SizedBox(height: GSpace.lg),

            // -----------------------------------------------------------------
            // أعطال النظام: مفيش حاجة تتقرا هنا — دي بترجع للفحص الآلي
            // -----------------------------------------------------------------
            if (_kind == FlagKind.system) ...[
              GNotice(
                tone: GNoticeTone.info,
                icon: Icons.info_outline_rounded,
                text: context.tr('mod.systemHint'),
              ),
              const SizedBox(height: GSpace.md),
              if ((stats?.pendingSystem ?? 0) > 0)
                GButton(
                  label: context.trf('mod.requeueAll', {
                    'n': stats?.pendingSystem ?? 0,
                  }),
                  icon: Icons.refresh_rounded,
                  style: GButtonStyle.secondary,
                  loading: _requeuing,
                  onPressed: _requeue,
                ),
              const SizedBox(height: GSpace.lg),
            ],

            queue.when(
              loading: () => const Column(
                children: [
                  GSkeleton(height: 108, radius: GRadius.brLg),
                  SizedBox(height: GSpace.md),
                  GSkeleton(height: 108, radius: GRadius.brLg),
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
                    icon: Icons.inbox_rounded,
                    title: context.tr('mod.empty'),
                    body: context.tr('mod.emptyBody'),
                    tone: GEmptyTone.brand,
                  );
                }
                return Column(
                  children: [
                    for (final entry in rows) ...[
                      _QueueCard(
                        entry: entry,
                        onTap: () => context.push(R.modReview(entry.itemId)),
                      ),
                      const SizedBox(height: GSpace.md),
                    ],
                  ],
                );
              },
            ),

            const SizedBox(height: GSpace.xxl),
            Text(
              context.tr('mod.footer'),
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

/// المؤشرات.
///
/// الرقم الكبير هو **أقدم حالة مستنية** مش المتوسط — المتوسط بيخبّي
/// الحالة اللي نسيناها من أسبوع.
class _StatsHeader extends StatelessWidget {
  const _StatsHeader({required this.stats});

  final ModerationStats stats;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final oldest = stats.oldestMinutes;

    final tone = oldest > 60 * 24
        ? c.danger
        : oldest > 60 * 4
            ? c.warning
            : c.success;

    return GSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('mod.oldest'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: GSpace.xs),
          Text(
            _humanAge(context, oldest),
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(color: tone, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: GSpace.md),
          Wrap(
            spacing: GSpace.sm,
            runSpacing: GSpace.sm,
            children: [
              GChip(
                label: context.trf('mod.withReports', {'n': stats.withReports}),
                icon: Icons.flag_rounded,
                color: stats.withReports > 0 ? c.danger : null,
                dense: true,
              ),
              GChip(
                label: context.trf('mod.decidedToday', {
                  'n': stats.decidedToday,
                }),
                icon: Icons.check_circle_outline_rounded,
                dense: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _humanAge(BuildContext context, int minutes) {
  if (minutes <= 0) return context.tr('mod.age.none');
  if (minutes < 60) return context.trf('mod.age.minutes', {'n': minutes});
  if (minutes < 60 * 24) {
    return context.trf('mod.age.hours', {'n': minutes ~/ 60});
  }
  return context.trf('mod.age.days', {'n': minutes ~/ (60 * 24)});
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({required this.entry, required this.onTap});

  final QueueEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return GSurface(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (entry.openReports > 0) ...[
                const SizedBox(width: GSpace.sm),
                GChip(
                  label: '${entry.openReports}',
                  icon: Icons.flag_rounded,
                  color: c.danger,
                  background: c.danger.withOpacity(0.12),
                  dense: true,
                ),
              ],
            ],
          ),
          const SizedBox(height: GSpace.xs),

          // سبب التعليم — للمراجع بس، مابيتعرضش لصاحب المنتج
          if (entry.flagNote != null)
            Text(
              entry.flagNote!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: c.warning),
            ),

          const SizedBox(height: GSpace.sm),
          Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 13, color: c.textTertiary),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  context.trf('mod.ownerLine', {
                    'name': entry.ownerName,
                    'trades': entry.ownerTrades,
                  }),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Icon(
                Icons.schedule_rounded,
                size: 13,
                color: entry.isUrgent ? c.danger : c.textTertiary,
              ),
              const SizedBox(width: 3),
              Text(
                _humanAge(context, entry.waitingMinutes),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: entry.isUrgent ? c.danger : null,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
