import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/catalog/categories.dart';
import '../../data/mock/mock_data.dart';
import '../../data/models/models.dart';
import '../../widgets/g_button.dart';
import '../../widgets/g_common.dart';

/// غرفة المقايضة.
///
/// قواعد الغرفة (تعديل مقصود على الـ spec الأصلي):
///
/// - الغرفة ما بتختفيش بمزاج طرف واحد — عشان مانسمحش بالهروب من الصفقات
/// - لكن **الحظر بيقفلها فوراً وبدون استثناء** — الأصل كان vector تحرش
/// - البلاغ بيجمّدها لحد مراجعة الإدارة
/// - الخمول 30 يوم بيأرشفها تلقائياً
class TradeRoomScreen extends StatefulWidget {
  const TradeRoomScreen({super.key, required this.matchId});

  final String matchId;

  @override
  State<TradeRoomScreen> createState() => _TradeRoomScreenState();
}

class _TradeRoomScreenState extends State<TradeRoomScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final match = Mock.match(widget.matchId);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            GAvatar(
              name: match.other.displayName,
              seed: match.other.avatarSeed,
              size: 34,
            ),
            const SizedBox(width: GSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    match.other.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    context.tr(match.other.trustLevel.labelKey),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) => _onMenu(context, value, match),
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'mute',
                child: _menuRow(ctx, Icons.notifications_off_outlined, 'common.mute'),
              ),
              PopupMenuItem(
                value: 'archive',
                child: _menuRow(ctx, Icons.archive_outlined, 'room.archive'),
              ),
              PopupMenuItem(
                value: 'close',
                child: _menuRow(ctx, Icons.handshake_outlined, 'room.requestClose'),
              ),
              PopupMenuItem(
                value: 'dispute',
                child: _menuRow(ctx, Icons.report_problem_outlined, 'dispute.title'),
              ),
              PopupMenuItem(
                value: 'report',
                child: _menuRow(ctx, Icons.flag_outlined, 'common.report'),
              ),
              PopupMenuItem(
                value: 'block',
                child: _menuRow(ctx, Icons.block_rounded, 'common.block', danger: true),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _StageBar(stage: match.stage),

          Expanded(
            child: ListView.separated(
              controller: _scroll,
              padding: const EdgeInsets.all(GSpace.lg),
              itemCount: Mock.conversation.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: GSpace.md),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return GNotice(
                    tone: GNoticeTone.warning,
                    icon: Icons.shield_outlined,
                    text: context.tr('room.safetyTip'),
                  );
                }
                return _Bubble(message: Mock.conversation[i - 1]);
              },
            ),
          ),

          _Composer(
            controller: _input,
            onOffer: () => context.push(R.offerNew(match.id)),
            onMeeting: () => context.push(R.meeting(match.id)),
          ),
        ],
      ),
    );
  }

  Widget _menuRow(
    BuildContext context,
    IconData icon,
    String key, {
    bool danger = false,
  }) {
    final color = danger ? context.colors.danger : context.colors.textPrimary;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: GSpace.sm),
        Text(context.tr(key), style: TextStyle(color: color)),
      ],
    );
  }

  void _onMenu(BuildContext context, String value, TradeMatch match) {
    switch (value) {
      case 'report':
        context.push(R.report('user', match.other.id));
      case 'dispute':
        context.push(R.dispute(match.id));
      case 'block':
        _confirmBlock(context, match);
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('common.soon'))),
        );
    }
  }

  Future<void> _confirmBlock(BuildContext context, TradeMatch match) async {
    final c = context.colors;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: const RoundedRectangleBorder(borderRadius: GRadius.brXl),
        title: Text(
          context.trf('block.confirm', {'name': match.other.displayName}),
          style: Theme.of(ctx).textTheme.titleLarge,
        ),
        content: Text(
          context.tr('block.body'),
          style: Theme.of(ctx).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.tr('common.cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.pop();
            },
            child: Text(
              context.tr('common.block'),
              style: TextStyle(color: c.danger),
            ),
          ),
        ],
      ),
    );
  }
}

/// شريط مرحلة الصفقة — بيوضح للطرفين إحنا فين بالظبط.
class _StageBar extends StatelessWidget {
  const _StageBar({required this.stage});

  final TradeStage stage;

  static const _steps = [
    TradeStage.negotiating,
    TradeStage.offerPending,
    TradeStage.agreed,
    TradeStage.meetingSet,
    TradeStage.completed,
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final current = stage.step;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: GSpace.lg,
        vertical: GSpace.md,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _steps.length; i++) ...[
            Column(
              children: [
                AnimatedContainer(
                  duration: GDuration.base,
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: i <= current ? c.brand : c.surfaceSunken,
                    shape: BoxShape.circle,
                  ),
                  child: i < current
                      ? Icon(Icons.check_rounded, size: 13, color: c.onBrand)
                      : Center(
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: i <= current ? c.onBrand : c.textTertiary,
                            ),
                          ),
                        ),
                ),
              ],
            ),
            if (i < _steps.length - 1)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: i < current ? c.brand : c.surfaceSunken,
                ),
              ),
          ],
          const SizedBox(width: GSpace.md),
          Text(
            context.tr(stage.labelKey),
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: c.brand),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (message.kind == MessageKind.system) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: GSpace.md,
            vertical: GSpace.sm,
          ),
          decoration: BoxDecoration(
            color: c.surfaceAlt,
            borderRadius: GRadius.brPill,
          ),
          child: Text(
            message.text,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }

    if (message.kind == MessageKind.offer && message.offer != null) {
      return Align(
        alignment: message.isMine
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: OfferCard(offer: message.offer!, time: message.time),
        ),
      );
    }

    return Align(
      alignment: message.isMine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: GSpace.md,
            vertical: GSpace.sm,
          ),
          decoration: BoxDecoration(
            color: message.isMine ? c.brand : c.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(GRadius.lg),
              topRight: const Radius.circular(GRadius.lg),
              bottomLeft: Radius.circular(message.isMine ? GRadius.lg : GRadius.xs),
              bottomRight: Radius.circular(message.isMine ? GRadius.xs : GRadius.lg),
            ),
            border: message.isMine ? null : Border.all(color: c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                message.text,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: message.isMine ? c.onBrand : c.textPrimary,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                message.time,
                style: TextStyle(
                  fontSize: 10.5,
                  color: message.isMine
                      ? c.onBrand.withOpacity(0.7)
                      : c.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// كارت العرض — عرض مرئي منظم مش نص.
class OfferCard extends StatelessWidget {
  const OfferCard({
    super.key,
    required this.offer,
    this.time = '',
    this.showActions = true,
  });

  final TradeOffer offer;
  final String time;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ar = context.s.isArabic;
    final currency = offer.getItem.country.currency;

    return GSurface(
      elevated: true,
      padding: const EdgeInsets.all(GSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.swap_horiz_rounded, size: 17, color: c.brand),
              const SizedBox(width: GSpace.xs),
              Text(
                context.tr('offer.title'),
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: c.brand),
              ),
              const Spacer(),
              if (time.isNotEmpty)
                Text(time, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: GSpace.md),

          _OfferLine(
            labelKey: 'offer.give',
            item: offer.giveItem,
            extra: offer.cashDelta > 0
                ? '+ ${currency.formatCompact(offer.cashDelta, ar: ar)}'
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: GSpace.sm),
            child: Divider(color: c.border, height: 1),
          ),
          _OfferLine(
            labelKey: 'offer.get',
            item: offer.getItem,
            extra: offer.cashDelta < 0
                ? '+ ${currency.formatCompact(offer.cashDelta.abs(), ar: ar)}'
                : null,
          ),

          if (offer.status == OfferStatus.pending && showActions) ...[
            const SizedBox(height: GSpace.md),
            Row(
              children: [
                Expanded(
                  child: GButton(
                    label: context.tr('offer.accept'),
                    style: GButtonStyle.success,
                    size: GButtonSize.small,
                    onPressed: () {},
                  ),
                ),
                const SizedBox(width: GSpace.sm),
                Expanded(
                  child: GButton(
                    label: context.tr('offer.counter'),
                    style: GButtonStyle.ghost,
                    size: GButtonSize.small,
                    onPressed: () {},
                  ),
                ),
              ],
            ),
            const SizedBox(height: GSpace.sm),
            Text(
              context.tr('offer.reservedFor'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else if (offer.status != OfferStatus.pending) ...[
            const SizedBox(height: GSpace.sm),
            GChip(
              label: context.tr(
                offer.status == OfferStatus.accepted
                    ? 'offer.accepted'
                    : 'offer.declined',
              ),
              color: offer.status == OfferStatus.accepted ? c.success : c.danger,
              background: (offer.status == OfferStatus.accepted
                      ? c.success
                      : c.danger)
                  .withOpacity(0.12),
              dense: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _OfferLine extends StatelessWidget {
  const _OfferLine({required this.labelKey, required this.item, this.extra});

  final String labelKey;
  final Item item;
  final String? extra;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ar = context.s.isArabic;

    return Row(
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: GImagePlaceholder(
            seed: item.imageSeed,
            icon: Categories.byId(item.categoryId).icon,
            radius: GRadius.brSm,
          ),
        ),
        const SizedBox(width: GSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr(labelKey),
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: c.textTertiary),
              ),
              Text(
                item.title(ar),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
        ),
        if (extra != null)
          Text(
            extra!,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: c.warning),
            textDirection: TextDirection.ltr,
          ),
      ],
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.onOffer,
    required this.onMeeting,
  });

  final TextEditingController controller;
  final VoidCallback onOffer;
  final VoidCallback onMeeting;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        GSpace.md,
        GSpace.sm,
        GSpace.md,
        GSpace.sm,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // إجراءات سريعة
            Row(
              children: [
                Expanded(
                  child: GButton(
                    label: context.tr('room.makeOffer'),
                    icon: Icons.swap_horiz_rounded,
                    size: GButtonSize.small,
                    onPressed: onOffer,
                  ),
                ),
                const SizedBox(width: GSpace.sm),
                Expanded(
                  child: GButton(
                    label: context.tr('room.scheduleMeeting'),
                    icon: Icons.event_outlined,
                    style: GButtonStyle.ghost,
                    size: GButtonSize.small,
                    onPressed: onMeeting,
                  ),
                ),
              ],
            ),
            const SizedBox(height: GSpace.sm),
            Row(
              children: [
                GIconButton(
                  icon: Icons.add_photo_alternate_outlined,
                  size: 42,
                  background: c.surfaceAlt,
                  onPressed: () {},
                  tooltip: context.tr('room.sendPhoto'),
                ),
                const SizedBox(width: GSpace.sm),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: GSpace.md,
                    ),
                    decoration: BoxDecoration(
                      color: c.surfaceAlt,
                      borderRadius: GRadius.brPill,
                    ),
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 4,
                      style: Theme.of(context).textTheme.bodyLarge,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: GSpace.md,
                        ),
                        hintText: context.tr('room.messageHint'),
                        hintStyle: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: GSpace.sm),
                GIconButton(
                  icon: Icons.send_rounded,
                  size: 42,
                  background: c.brand,
                  foreground: c.onBrand,
                  onPressed: () => controller.clear(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
