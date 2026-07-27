import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_init.dart';
import '../mock/mock_data.dart';
import '../models/models.dart';

/// غرف المقايضة.
class MatchesRepository {
  const MatchesRepository();

  bool get hasBackend => SupabaseInit.isReady;
  SupabaseClient get _client => SupabaseInit.client;

  String? get _me => _client.auth.currentUser?.id;

  /// أسماء المفاتيح الأجنبية لازم تكون صريحة، لأن `matches` فيها
  /// مفتاحين لـ profiles ومفتاحين لـ items — من غيرها الاستعلام بيفشل.
  static const String _columns = '''
    *,
    a:profiles!matches_user_a_fkey(*, user_stats(*)),
    b:profiles!matches_user_b_fkey(*, user_stats(*)),
    ia:items!matches_item_a_fkey(*, item_photos(storage_path,is_cover,position)),
    ib:items!matches_item_b_fkey(*, item_photos(storage_path,is_cover,position))
  ''';

  Future<List<TradeMatch>> list({bool archived = false}) async {
    if (!hasBackend) {
      return Mock.matches.where((m) => m.archived == archived).toList();
    }

    final me = _me;
    if (me == null) return const [];

    var query = _client.from('matches').select(_columns).or(
          'user_a.eq.$me,user_b.eq.$me',
        );

    query = archived
        ? query.not('archived_at', 'is', null)
        : query.isFilter('archived_at', null);

    final rows = await query.order('last_activity_at', ascending: false);

    return rows.map((row) => _toMatch(row, me)).toList();
  }

  Future<TradeMatch?> byId(String matchId) async {
    if (!hasBackend) return Mock.match(matchId);

    final me = _me;
    if (me == null) return null;

    final rows = await _client.from('matches').select(_columns).eq('id', matchId);
    if (rows.isEmpty) return null;
    return _toMatch(rows.first, me);
  }

  TradeMatch _toMatch(Map<String, dynamic> row, String me) {
    final isA = row['user_a'] == me;

    final other = UserProfile.fromMap(
      (isA ? row['b'] : row['a']) as Map<String, dynamic>,
    );
    final mine = Item.fromMap(
      (isA ? row['ia'] : row['ib']) as Map<String, dynamic>,
    );
    final theirs = Item.fromMap(
      (isA ? row['ib'] : row['ia']) as Map<String, dynamic>,
    );

    return TradeMatch(
      id: row['id'] as String,
      other: other,
      myItem: mine,
      theirItem: theirs,
      stage: TradeStageX.parse(row['stage']),
      lastMessage: '',
      lastActivity: _relative(row['last_activity_at']),
      archived: row['archived_at'] != null,
      closedByBlock: row['closed_by_block'] == true,
      frozen: row['frozen_by_report'] == true,
    );
  }

  static String _relative(Object? raw) {
    final at = DateTime.tryParse('$raw');
    if (at == null) return '';
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'دلوقتي';
    if (diff.inMinutes < 60) return 'من ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'من ${diff.inHours} ساعة';
    if (diff.inDays == 1) return 'إمبارح';
    return 'من ${diff.inDays} يوم';
  }

  // ---------------------------------------------------------------------------
  // الرسائل
  // ---------------------------------------------------------------------------

  /// بث لحظي لرسائل الغرفة.
  Stream<List<Message>> messageStream(String matchId) {
    if (!hasBackend) {
      return Stream.value(Mock.conversation);
    }

    final me = _me ?? '';
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('match_id', matchId)
        .order('created_at')
        .map((rows) => rows.map((r) => Message.fromMap(r, myId: me)).toList());
  }

  Future<String?> sendMessage(String matchId, String body) async {
    if (!hasBackend) return null;

    final me = _me;
    if (me == null) return 'auth.err.generic';
    if (body.trim().isEmpty) return null;

    try {
      await _client.from('messages').insert({
        'match_id': matchId,
        'sender_id': me,
        'kind': 'text',
        'body': body.trim(),
      });
      return null;
    } on PostgrestException {
      // سياسة الصفوف بترفض الإرسال في الغرف المقفولة بالحظر أو المجمّدة
      return 'room.requestClose';
    } catch (_) {
      return 'common.error';
    }
  }

  Future<void> markRead(String matchId) async {
    if (!hasBackend) return;
    final me = _me;
    if (me == null) return;

    await _client
        .from('messages')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('match_id', matchId)
        .neq('sender_id', me)
        .isFilter('read_at', null);
  }

  // ---------------------------------------------------------------------------
  // العروض
  // ---------------------------------------------------------------------------
  Future<String?> createOffer({
    required String matchId,
    required String giveItemId,
    required String getItemId,
    required double cashDelta,
    required String currencyCode,
  }) async {
    if (!hasBackend) return null;

    final me = _me;
    if (me == null) return 'auth.err.generic';

    try {
      await _client.from('offers').insert({
        'match_id': matchId,
        'from_user': me,
        'give_item_id': giveItemId,
        'get_item_id': getItemId,
        'cash_delta': cashDelta,
        'currency_code': currencyCode,
      });
      return null;
    } on PostgrestException catch (error) {
      // مؤشر فريد جزئي: عرض معلّق واحد بس في كل غرفة
      if (error.code == '23505') return 'offer.title';
      return 'common.error';
    } catch (_) {
      return 'common.error';
    }
  }

  Future<String?> respondToOffer(String offerId, {required bool accept}) async {
    if (!hasBackend) return null;
    try {
      await _client
          .from('offers')
          .update({'status': accept ? 'accepted' : 'declined'})
          .eq('id', offerId);
      return null;
    } catch (_) {
      return 'common.error';
    }
  }

  // ---------------------------------------------------------------------------
  // اللقاء والإتمام
  // ---------------------------------------------------------------------------
  Future<List<MeetingPlace>> meetingPlaces(String cityId) async {
    if (!hasBackend) return Mock.meetingPlaces;

    final rows = await _client
        .from('meeting_places')
        .select()
        .eq('city_id', cityId)
        .eq('is_active', true);

    return rows.map(MeetingPlace.fromMap).toList();
  }

  Future<String?> scheduleMeeting({
    required String matchId,
    required String placeId,
    required DateTime at,
  }) async {
    if (!hasBackend) return null;

    final me = _me;
    if (me == null) return 'auth.err.generic';

    try {
      await _client.from('meetings').insert({
        'match_id': matchId,
        'place_id': placeId,
        'scheduled_at': at.toUtc().toIso8601String(),
        'created_by': me,
      });
      return null;
    } catch (_) {
      return 'common.error';
    }
  }

  /// تأكيد الإتمام. الصفقة مابتكتملش إلا لما **الطرفين** يأكدوا —
  /// محفّز في القاعدة هو اللي بيقفلها.
  /// إصدار كودي أنا — **بيتولّد على الخادم**.
  ///
  /// بيرجّع نفس الكود لو اتنادى تاني، عشان الطرف التاني مايلاقيش
  /// الكود اتغير وهو بيمسحه.
  Future<String?> issueTradeCode(String matchId) async {
    if (!hasBackend) return 'GRF-DEMO24';

    try {
      final code = await _client.rpc(
        'issue_trade_code',
        params: {'p_match': matchId},
      );
      return code as String?;
    } catch (_) {
      return null;
    }
  }

  /// التأكيد بمسح كود الطرف التاني.
  ///
  /// القاعدة: الكود اللي بمسحه بتاع التاني، واللي بيتأكد هو **صفي أنا**.
  /// يعني مستحيل أأكد من غير ما أكون شايف شاشته.
  ///
  /// بترجع `null` لو نجح، أو مفتاح ترجمة للخطأ.
  Future<String?> confirmTrade(String matchId, String code) async {
    if (!hasBackend) return null;

    try {
      final result = await _client.rpc(
        'confirm_trade',
        params: {'p_match': matchId, 'p_code': code},
      ) as Map<String, dynamic>;

      if (result['ok'] == true) return null;

      return switch (result['error']) {
        'invalid_code' => 'complete.err.code',
        'too_many_attempts' => 'complete.err.attempts',
        'issue_code_first' => 'complete.err.order',
        'room_closed' => 'complete.err.closed',
        _ => 'common.error',
      };
    } catch (_) {
      return 'common.error';
    }
  }

  /// هل الطرف التاني أكّد؟ — من غير ما نكشف كوده.
  Future<bool> otherSideConfirmed(String matchId) async {
    if (!hasBackend) return false;

    try {
      final done = await _client.rpc(
        'other_side_confirmed',
        params: {'p_match': matchId},
      );
      return done == true;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // الأمان
  // ---------------------------------------------------------------------------

  /// الحظر بيقفل كل الغرف المشتركة فوراً — محفّز في القاعدة.
  Future<String?> block(String userId) async {
    if (!hasBackend) return null;

    final me = _me;
    if (me == null) return 'auth.err.generic';

    try {
      await _client.from('blocks').insert({
        'blocker_id': me,
        'blocked_id': userId,
      });
      return null;
    } catch (_) {
      return 'common.error';
    }
  }

  Future<String?> report({
    required String targetType,
    required String targetId,
    required String reason,
    String? details,
  }) async {
    if (!hasBackend) return null;

    final me = _me;
    if (me == null) return 'auth.err.generic';

    try {
      await _client.from('reports').insert({
        'reporter_id': me,
        'target_type': targetType,
        'target_id': targetId,
        'reason': reason,
        if (details != null && details.isNotEmpty) 'details': details,
      });
      return null;
    } on PostgrestException catch (error) {
      if (error.code == '23505') return null; // بلّغ قبل كده
      return 'common.error';
    } catch (_) {
      return 'common.error';
    }
  }

  Future<String?> openDispute({
    required String matchId,
    required String reason,
    String? details,
  }) async {
    if (!hasBackend) return null;

    final me = _me;
    if (me == null) return 'auth.err.generic';

    try {
      await _client.from('disputes').insert({
        'match_id': matchId,
        'opened_by': me,
        'reason': reason,
        if (details != null && details.isNotEmpty) 'details': details,
      });
      return null;
    } catch (_) {
      return 'common.error';
    }
  }

  Future<String?> submitReview({
    required String matchId,
    required String revieweeId,
    required int overall,
    int? accuracy,
    int? punctuality,
    String? comment,
  }) async {
    if (!hasBackend) return null;

    final me = _me;
    if (me == null) return 'auth.err.generic';

    try {
      await _client.from('reviews').insert({
        'match_id': matchId,
        'reviewer_id': me,
        'reviewee_id': revieweeId,
        'overall': overall,
        if (accuracy != null) 'accuracy': accuracy,
        if (punctuality != null) 'punctuality': punctuality,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      });
      return null;
    } catch (_) {
      return 'common.error';
    }
  }
}
