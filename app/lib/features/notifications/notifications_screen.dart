import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/mock/mock_data.dart';
import '../../data/models/models.dart';
import '../../widgets/g_common.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ar = context.s.isArabic;
    final items = Mock.notifications;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('notif.title'))),
      body: items.isEmpty
          ? GEmptyState(
              icon: Icons.notifications_none_rounded,
              title: context.tr('notif.empty.title'),
              body: context.tr('notif.empty.body'),
            )
          : ListView.separated(
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
      NotificationKind.system => (Icons.info_rounded, c.textSecondary),
    };

    return GSurface(
      onTap: () => context.push(R.matches),
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
