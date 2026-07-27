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

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // فتح الشاشة = قراءة الكل. مفيش سبب نخلي المستخدم يضغط على كل واحد.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(notificationsRepositoryProvider).markAllRead();
      if (mounted) ref.invalidate(unreadCountProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ar = context.s.isArabic;
    final async = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('notif.title'))),
      body: switch (async) {
        AsyncLoading() => ListView(
            padding: const EdgeInsets.all(GSpace.screenH),
            children: const [
              GSkeleton(height: 68, radius: GRadius.brLg),
              SizedBox(height: GSpace.sm),
              GSkeleton(height: 68, radius: GRadius.brLg),
              SizedBox(height: GSpace.sm),
              GSkeleton(height: 68, radius: GRadius.brLg),
            ],
          ),
        AsyncError() => GEmptyState(
            icon: Icons.cloud_off_rounded,
            title: context.tr('common.error'),
            body: context.tr('common.errorBody'),
            actionLabel: context.tr('common.retry'),
            onAction: () => ref.invalidate(notificationsProvider),
          ),
        _ => _list(context, ref, async.value ?? const [], ar),
      },
    );
  }

  Widget _list(
    BuildContext context,
    WidgetRef ref,
    List<AppNotification> items,
    bool ar,
  ) {
    if (items.isEmpty) {
      return GEmptyState(
        icon: Icons.notifications_none_rounded,
        title: context.tr('notif.empty.title'),
        body: context.tr('notif.empty.body'),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(notificationsProvider),
      child: ListView.separated(
        padding: const EdgeInsets.all(GSpace.screenH),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: GSpace.sm),
        itemBuilder: (context, i) =>
            _NotificationRow(notification: items[i], isArabic: ar),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.notification, required this.isArabic});

  final AppNotification notification;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final (icon, color) = switch (notification.kind) {
      NotificationKind.match => (Icons.favorite_rounded, c.danger),
      NotificationKind.message => (Icons.chat_bubble_rounded, c.info),
      NotificationKind.offer => (Icons.swap_horiz_rounded, c.brand),
      NotificationKind.wishlist => (Icons.bookmark_rounded, c.success),
      NotificationKind.nearby => (Icons.near_me_rounded, c.warning),
      NotificationKind.meeting => (Icons.event_rounded, c.info),
      NotificationKind.review => (Icons.star_rounded, c.warning),
      NotificationKind.system => (Icons.info_rounded, c.textSecondary),
    };

    // التوجيه بيتحدد من حمولة الإشعار — الماتش يفتح الغرفة والمنتج يفتح صفحته
    final matchId = notification.payload['match_id'] as String?;
    final itemId = notification.payload['item_id'] as String?;

    return GSurface(
      onTap: () {
        if (matchId != null) {
          context.push(R.room(matchId));
        } else if (itemId != null) {
          context.push(R.item(itemId));
        } else {
          context.push(R.matches);
        }
      },
      color: notification.unread ? c.brandSoft : null,
      padding: const EdgeInsets.all(GSpace.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: GRadius.brSm,
            ),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: GSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title(isArabic),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  notification.time,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (notification.unread)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: c.brand,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
