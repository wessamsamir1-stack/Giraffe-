import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../widgets/g_common.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final Map<String, bool> _values = {
    'notif.matches': true,
    'notif.messages': true,
    'notif.offers': true,
    'notif.wishlist': true,
    'notif.nearby': false,
    'notif.marketing': false,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('settings.notifications'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: GSpace.xxxl),
        children: [
          GSettingsGroup(
            title: context.tr('notif.title'),
            children: [
              for (final key in _values.keys)
                GSettingsTile(
                  icon: switch (key) {
                    'notif.matches' => Icons.favorite_rounded,
                    'notif.messages' => Icons.chat_bubble_outline_rounded,
                    'notif.offers' => Icons.swap_horiz_rounded,
                    'notif.wishlist' => Icons.bookmark_outline_rounded,
                    'notif.nearby' => Icons.near_me_outlined,
                    _ => Icons.campaign_outlined,
                  },
                  label: context.tr(key),
                  trailing: Switch(
                    value: _values[key]!,
                    activeColor: c.brand,
                    onChanged: (v) => setState(() => _values[key] = v),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
