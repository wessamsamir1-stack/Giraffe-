import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_init.dart';

/// نوع سبب التعليم.
///
/// التقسيم ده مش تفصيلة عرض — ده اللي بيحمي وقت المراجع.
///
/// [content] الموديل شاف حاجة وقال «راجعوا ده» → محتاج **حكم بشري**.
/// [system]  النظام تعثّر (سقف أو موديل مارّدش) → محتاج **إعادة محاولة**.
///
/// خلطهم بيهدر أندر مورد عندنا. لو 90% من الطابور أعطال نظام، المراجع
/// هيقلب على الوضع الآلي وهيعدّي الحالة الحقيقية اللي كانت محتاجاه.
enum FlagKind { content, system, unknown }

FlagKind _parseFlagKind(String? raw) => switch (raw) {
      'content' => FlagKind.content,
      'system' => FlagKind.system,
      _ => FlagKind.unknown,
    };

/// صف في طابور المراجعة.
class QueueEntry {
  const QueueEntry({
    required this.itemId,
    required this.title,
    required this.description,
    required this.categoryId,
    required this.ownerId,
    required this.ownerName,
    required this.ownerUsername,
    required this.ownerTrust,
    required this.ownerTrades,
    required this.photoCount,
    required this.flagKind,
    required this.flagNote,
    required this.waitingMinutes,
    required this.openReports,
    this.photos = const [],
  });

  final String itemId;
  final String title;
  final String? description;
  final String categoryId;
  final String ownerId;
  final String ownerName;
  final String ownerUsername;
  final String ownerTrust;
  final int ownerTrades;
  final int photoCount;
  final FlagKind flagKind;

  /// سبب التعليم — **بيتعرض للمراجع بس**، مش لصاحب المنتج.
  final String? flagNote;

  final int waitingMinutes;
  final int openReports;

  /// مسارات الصور في التخزين، بترتيبها.
  ///
  /// من غيرها المراجعة مستحيلة على منتج اتعلّم بسبب صوره أصلاً —
  /// كنا بنعرض العدد بس ونطلب حكم على محتوى بصري مش ظاهر.
  final List<String> photos;

  bool get isUrgent => openReports > 0 || waitingMinutes > 60 * 24;

  factory QueueEntry.fromMap(Map<String, dynamic> row) => QueueEntry(
        itemId: row['item_id'] as String,
        title: row['title'] as String? ?? '',
        description: row['description'] as String?,
        categoryId: row['category_id'] as String? ?? '',
        ownerId: row['owner_id'] as String? ?? '',
        ownerName: row['owner_name'] as String? ?? '',
        ownerUsername: row['owner_username'] as String? ?? '',
        ownerTrust: row['owner_trust'] as String? ?? 'new',
        ownerTrades: (row['owner_trades'] as num?)?.toInt() ?? 0,
        photoCount: (row['photo_count'] as num?)?.toInt() ?? 0,
        flagKind: _parseFlagKind(row['flag_kind'] as String?),
        flagNote: row['moderation_note'] as String?,
        waitingMinutes: (row['waiting_minutes'] as num?)?.toInt() ?? 0,
        openReports: (row['open_reports'] as num?)?.toInt() ?? 0,
        photos: ((row['photos'] as List<dynamic>?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
}

/// مؤشرات الطابور.
class ModerationStats {
  const ModerationStats({
    this.pendingContent = 0,
    this.pendingSystem = 0,
    this.pendingUnknown = 0,
    this.oldestMinutes = 0,
    this.withReports = 0,
    this.decidedToday = 0,
  });

  final int pendingContent;
  final int pendingSystem;
  final int pendingUnknown;

  /// أقدم حالة مستنية — **ده المؤشر اللي بيهم**.
  ///
  /// المتوسط بيخبّي الحالة اللي نسيناها من أسبوع.
  final int oldestMinutes;

  final int withReports;
  final int decidedToday;

  factory ModerationStats.fromMap(Map<String, dynamic> row) => ModerationStats(
        pendingContent: (row['pending_content'] as num?)?.toInt() ?? 0,
        pendingSystem: (row['pending_system'] as num?)?.toInt() ?? 0,
        pendingUnknown: (row['pending_unknown'] as num?)?.toInt() ?? 0,
        oldestMinutes: (row['oldest_minutes'] as num?)?.toInt() ?? 0,
        withReports: (row['with_reports'] as num?)?.toInt() ?? 0,
        decidedToday: (row['decided_today'] as num?)?.toInt() ?? 0,
      );
}

/// لوحة المراجعة البشرية.
///
/// الصلاحية بتتفحص في القاعدة، مش هنا. إخفاء الشاشة في التطبيق تحسين
/// عرض بس — لو حد وصل للمسار بأي طريقة، القاعدة هي اللي بترفض.
class ModerationRepository {
  const ModerationRepository();

  bool get hasBackend => SupabaseInit.isReady;
  SupabaseClient get _client => SupabaseInit.client;

  /// هل المستخدم الحالي من الطاقم؟
  Future<bool> amIStaff() async {
    if (!hasBackend) return true;   // في الوضع التجريبي بنعرض اللوحة
    try {
      final result = await _client.rpc('is_staff');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<QueueEntry>> queue({
    FlagKind kind = FlagKind.content,
    int limit = 30,
  }) async {
    if (!hasBackend) return _mockQueue(kind);

    try {
      final rows = await _client.rpc('moderation_queue_page', params: {
        'p_kind': kind.name,
        'p_limit': limit,
      },) as List<dynamic>;

      return rows
          .map((r) => QueueEntry.fromMap(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<ModerationStats> stats() async {
    if (!hasBackend) {
      return const ModerationStats(
        pendingContent: 3,
        pendingSystem: 2,
        oldestMinutes: 190,
        withReports: 1,
        decidedToday: 7,
      );
    }

    try {
      final row = await _client.rpc('moderation_stats')
          as Map<String, dynamic>;
      if (row['ok'] != true) return const ModerationStats();
      return ModerationStats.fromMap(row);
    } catch (_) {
      return const ModerationStats();
    }
  }

  /// القرار.
  ///
  /// بترجّع `null` لو نجح، أو مفتاح ترجمة للخطأ.
  Future<String?> decide({
    required String itemId,
    required bool approve,
    String? reason,
  }) async {
    if (!hasBackend) return null;

    try {
      final row = await _client.rpc('moderate_decide', params: {
        'p_item': itemId,
        'p_decision': approve ? 'approved' : 'rejected',
        'p_reason': reason,
      },) as Map<String, dynamic>;

      if (row['ok'] == true) return null;

      return switch (row['error']) {
        'not_authorized' => 'mod.err.notStaff',
        'own_item' => 'mod.err.ownItem',
        'reason_required' => 'mod.err.reason',
        'not_found' => 'common.error',
        _ => 'common.error',
      };
    } catch (_) {
      return 'common.error';
    }
  }

  /// إعادة أعطال النظام للطابور الآلي — دفعة واحدة.
  ///
  /// دي **مش قرار**، فمالهاش سجل قرارات. المنتجات دي محدش حكم عليها
  /// أصلاً — النظام هو اللي تعثّر.
  Future<int> requeueSystemFlags() async {
    if (!hasBackend) return 2;
    try {
      final n = await _client.rpc('moderate_requeue_system_flags',
          params: {'p_limit': 100},);
      return (n as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  List<QueueEntry> _mockQueue(FlagKind kind) {
    if (kind == FlagKind.system) {
      return const [
        QueueEntry(
          itemId: 'mock-sys-1',
          title: 'دراجة هوائية كوبرا',
          description: 'مستعملة سنة، الفرامل جديدة.',
          categoryId: 'sports',
          ownerId: 'u2',
          ownerName: 'أحمد فتحي',
          ownerUsername: 'ahmed',
          ownerTrust: 'trusted',
          ownerTrades: 12,
          photoCount: 3,
          flagKind: FlagKind.system,
          flagNote: 'moderation_unavailable',
          waitingMinutes: 45,
          openReports: 0,
        ),
      ];
    }

    return const [
      QueueEntry(
        itemId: 'mock-1',
        title: 'ساعة سويسرية أصلية',
        description: 'بالضمان والفاتورة.',
        categoryId: 'fashion',
        ownerId: 'u1',
        ownerName: 'وسام سمير',
        ownerUsername: 'wessam',
        ownerTrust: 'new',
        ownerTrades: 0,
        photoCount: 2,
        flagKind: FlagKind.content,
        flagNote: 'ادعاء أصالة غير مؤكد — الصور مش واضحة',
        waitingMinutes: 190,
        openReports: 2,
        photos: ['demo/watch-1.jpg', 'demo/watch-2.jpg'],
      ),
      QueueEntry(
        itemId: 'mock-2',
        title: 'لابتوب ديل للبيع أو البدل',
        description: 'i7 وذاكرة 16 جيجا.',
        categoryId: 'computers',
        ownerId: 'u3',
        ownerName: 'منى حسن',
        ownerUsername: 'mona',
        ownerTrust: 'elite',
        ownerTrades: 31,
        photoCount: 4,
        flagKind: FlagKind.content,
        flagNote: 'رقم موبايل ظاهر في الوصف',
        waitingMinutes: 20,
        openReports: 0,
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // البلاغات
  // ---------------------------------------------------------------------------

  Future<List<ReportEntry>> reports({int limit = 30}) async {
    if (!hasBackend) return _mockReports();

    try {
      final rows = await _client
          .rpc('report_queue_page', params: {'p_limit': limit}) as List<dynamic>;
      return rows
          .map((r) => ReportEntry.fromMap(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// القرار على بلاغ.
  ///
  /// `days` بـ `null` معناه إيقاف دائم — وده للأدمن بس، والقاعدة
  /// هي اللي بتفرض ده.
  Future<String?> decideReport({
    required String reportId,
    required ReportAction action,
    String? reason,
    int? days = 7,
  }) async {
    if (!hasBackend) return null;

    try {
      final row = await _client.rpc('report_decide', params: {
        'p_report': reportId,
        'p_action': action.name,
        'p_reason': reason,
        'p_days': days,
      },) as Map<String, dynamic>;

      if (row['ok'] == true) return null;

      return switch (row['error']) {
        'not_authorized' => 'mod.err.notStaff',
        'own_report' => 'mod.err.ownReport',
        'reason_required' => 'mod.err.reason',
        'admin_required' => 'mod.err.adminOnly',
        _ => 'common.error',
      };
    } catch (_) {
      return 'common.error';
    }
  }

  /// تقرير دقة الفحص.
  Future<AccuracyReport?> accuracyReport({int days = 30}) async {
    if (!hasBackend) {
      return const AccuracyReport(
        decisions: 40, approved: 14, rejected: 26,
        falseFlagRate: 0.35, medianWaitMinutes: 42, p90WaitMinutes: 310,
        reportsHandled: 9,
      );
    }

    try {
      final row = await _client
          .rpc('moderation_report', params: {'p_days': days})
              as Map<String, dynamic>;
      if (row['ok'] != true) return null;
      return AccuracyReport.fromMap(row);
    } catch (_) {
      return null;
    }
  }

  List<ReportEntry> _mockReports() => const [
        ReportEntry(
          reportId: 'r1',
          targetType: 'user',
          targetId: 'u2',
          reason: 'scam',
          details: 'طلب مني تحويل قبل اللقاء',
          reporterName: 'وسام سمير',
          reportsOnTarget: 3,
          waitingMinutes: 95,
          targetLabel: 'أحمد فتحي',
          targetBody: null,
        ),
        ReportEntry(
          reportId: 'r2',
          targetType: 'message',
          targetId: 'm9',
          reason: 'inappropriate',
          details: 'بيحاول ياخد المعاملة بره التطبيق',
          reporterName: 'منى حسن',
          reportsOnTarget: 1,
          waitingMinutes: 20,
          targetLabel: 'رسالة',
          targetBody: 'كلّمني على الرقم ده بره التطبيق',
        ),
      ];
}

/// الإجراء على بلاغ، مرتّب بالشدّة.
enum ReportAction { dismissed, warned, removed, banned }

/// صف في طابور البلاغات.
class ReportEntry {
  const ReportEntry({
    required this.reportId,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.details,
    required this.reporterName,
    required this.reportsOnTarget,
    required this.waitingMinutes,
    required this.targetLabel,
    required this.targetBody,
  });

  final String reportId;
  final String targetType;
  final String targetId;
  final String reason;
  final String? details;
  final String reporterName;

  /// كام بلاغ مفتوح على نفس الهدف.
  ///
  /// أقوى إشارة عندنا: خمس ناس مختلفين بلّغوا على نفس الشخص مش صدفة.
  final int reportsOnTarget;

  final int waitingMinutes;

  /// اسم المستخدم المبلَّغ عنه، أو «رسالة».
  final String targetLabel;

  /// نص الرسالة المبلَّغ عنها — المراجع مايقدرش يحكم من غيره.
  final String? targetBody;

  bool get isMessage => targetType == 'message';

  factory ReportEntry.fromMap(Map<String, dynamic> row) {
    final target = (row['target'] as Map<String, dynamic>?) ?? const {};
    final type = row['target_type'] as String? ?? 'user';

    return ReportEntry(
      reportId: row['report_id'] as String,
      targetType: type,
      targetId: row['target_id'] as String? ?? '',
      reason: row['reason'] as String? ?? 'other',
      details: row['details'] as String?,
      reporterName: row['reporter_name'] as String? ?? '',
      reportsOnTarget: (row['reports_on_target'] as num?)?.toInt() ?? 1,
      waitingMinutes: (row['waiting_minutes'] as num?)?.toInt() ?? 0,
      targetLabel: type == 'user'
          ? (target['display_name'] as String? ?? '')
          : 'رسالة',
      targetBody: target['body'] as String?,
    );
  }
}

/// تقرير دقة الفحص.
class AccuracyReport {
  const AccuracyReport({
    required this.decisions,
    required this.approved,
    required this.rejected,
    required this.falseFlagRate,
    required this.medianWaitMinutes,
    required this.p90WaitMinutes,
    required this.reportsHandled,
  });

  final int decisions;
  final int approved;
  final int rejected;

  /// من كل المنتجات اللي الموديل علّمها، كام واحد المراجع وافق عليه.
  ///
  /// عالي = الموديل بيهدر انتباه المراجع على منتجات سليمة.
  /// صفر = غالباً متساهل زيادة ومابيعلّمش حاجات المفروض يعلّمها.
  ///
  /// **مفيش رقم صح مطلق** — الاتجاه هو اللي بيقول نشدّ ولا نرخي.
  final double? falseFlagRate;

  final double? medianWaitMinutes;
  final double? p90WaitMinutes;
  final int reportsHandled;

  factory AccuracyReport.fromMap(Map<String, dynamic> row) => AccuracyReport(
        decisions: (row['decisions'] as num?)?.toInt() ?? 0,
        approved: (row['approved'] as num?)?.toInt() ?? 0,
        rejected: (row['rejected'] as num?)?.toInt() ?? 0,
        falseFlagRate: (row['false_flag_rate'] as num?)?.toDouble(),
        medianWaitMinutes: (row['median_wait_minutes'] as num?)?.toDouble(),
        p90WaitMinutes: (row['p90_wait_minutes'] as num?)?.toDouble(),
        reportsHandled: (row['reports_handled'] as num?)?.toInt() ?? 0,
      );
}
