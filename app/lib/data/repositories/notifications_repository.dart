import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_init.dart';
import '../mock/mock_data.dart';
import '../models/models.dart';

/// الإشعارات داخل التطبيق.
///
/// دي مش إشعارات الدفع — دي السجل اللي المستخدم بيشوفه في التبويب.
/// إشعارات الدفع بتتبعت من الخادم عبر Firebase Messaging.
class NotificationsRepository {
  const NotificationsRepository();

  bool get hasBackend => SupabaseInit.isReady;
  SupabaseClient get _client => SupabaseInit.client;

  Future<List<AppNotification>> list({int limit = 50}) async {
    if (!hasBackend) return Mock.notifications;

    final id = _client.auth.currentUser?.id;
    if (id == null) return const [];

    final rows = await _client
        .from('notifications')
        .select()
        .eq('user_id', id)
        .order('created_at', ascending: false)
        .limit(limit);

    return rows.map(AppNotification.fromMap).toList();
  }

  Future<int> unreadCount() async {
    if (!hasBackend) {
      return Mock.notifications.where((n) => n.unread).length;
    }

    final id = _client.auth.currentUser?.id;
    if (id == null) return 0;

    final rows = await _client
        .from('notifications')
        .select('id')
        .eq('user_id', id)
        .isFilter('read_at', null);

    return rows.length;
  }

  Future<void> markAllRead() async {
    if (!hasBackend) return;

    final id = _client.auth.currentUser?.id;
    if (id == null) return;

    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('user_id', id)
        .isFilter('read_at', null);
  }

  Future<void> markRead(String notificationId) async {
    if (!hasBackend) return;
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('id', notificationId);
  }
}
