import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/l10n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/mock/mock_data.dart';
import '../../data/models/models.dart';
import '../../widgets/g_common.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final active = Mock.matches.where((m) => !m.archived).toList();
    final archived = Mock.matches.where((m) => m.archived).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('matches.title')),
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(84),
          child: Column(
            children: [
              // عدّاد الغرف النشطة — سقف عادل بدل قفل التطبيق
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: GSpace.screenH,
                  vertical: GSpace.xs,
                ),
                child: Row(
                  children: [
                    Icon(Icons.forum_outlined, size: 15, color: c.textTertiary),
                    const SizedBox(width: GSpace.xs),
                    Text(
                      context.trf('matches.roomsCount', {
                        'n': active.length,
                        'max': kMaxActiveRooms,
                      }),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              TabBar(
                controller: _tabs,
                labelColor: c.brand,
                unselectedLabelColor: c.textTertiary,
                indicatorColor: c.brand,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: c.border,
                tabs: [
                  Tab(text: context.tr('matches.active')),
                  Tab(text: context.tr('matches.archived')),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _list(context, active),
          _list(context, archived),
        ],
      ),
    );
  }

  Widget _list(BuildContext context, List<TradeMatch> matches) {
    if (matches.isEmpty) {
      return GEmptyState(
        icon: Icons.forum_outlined,
        tone: GEmptyTone.brand,
        title: context.tr('matches.empty.title'),
        body: context.tr('matches.empty.body'),
        actionLabel: context.tr('matches.empty.action'),
        onAction: () => context.go(R.deck),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(GSpace.screenH),
      itemCount: matches.length,
      separatorBuilder: (_, __) => const SizedBox(height: GSpace.md),
      itemBuilder: (context, i) => _MatchRow(match: matches[i]),
    );
  }
}

class _MatchRow extends StatelessWidget {
  const _MatchRow({required this.match});

  final TradeMatch match;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ar = context.s.isArabic;

    final stageColor = switch (match.stage) {
      TradeStage.completed => c.success,
      TradeStage.disputed => c.danger,
      TradeStage.cancelled => c.textTertiary,
      TradeStage.offerPending => c.warning,
      TradeStage.meetingSet => c.info,
      _ => c.textSecondary,
    };

    return GSurface(
      onTap: () => context.push(R.room(match.id)),
      padding: const EdgeInsets.all(GSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GAvatar(
            name: match.other.displayName,
            seed: match.other.avatarSeed,
            size: GSize.avatarMd,
          ),
          const SizedBox(width: GSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        match.other.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      match.lastActivity,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 2),

                // ملخص الصفقة
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        match.myItem.title(ar),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        Icons.swap_horiz_rounded,
                        size: 13,
                        color: c.brand,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        match.theirItem.title(ar),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: GSpace.sm),
                Row(
                  children: [
                    GChip(
                      label: context.tr(match.stage.labelKey),
                      color: stageColor,
                      background: stageColor.withOpacity(0.12),
                      dense: true,
                    ),
                    const SizedBox(width: GSpace.sm),
                    Expanded(
                      child: Text(
                        match.lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    if (match.unread > 0)
                      Container(
                        margin: const EdgeInsetsDirectional.only(
                          start: GSpace.sm,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: c.brand,
                          borderRadius: GRadius.brPill,
                        ),
                        child: Text(
                          '${match.unread}',
                          style: TextStyle(
                            color: c.onBrand,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
