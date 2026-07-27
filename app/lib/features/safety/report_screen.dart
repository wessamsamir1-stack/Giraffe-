import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/repositories/providers.dart';
import '../../widgets/g_button.dart';
import '../../widgets/g_common.dart';
import '../../widgets/g_text_field.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({
    super.key,
    required this.targetType,
    required this.targetId,
  });

  final String targetType;
  final String targetId;

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  final _details = TextEditingController();
  int? _reason;
  bool _sent = false;
  bool _saving = false;

  static const _reasons = [
    'report.r1',
    'report.r2',
    'report.r3',
    'report.r4',
    'report.r5',
    'report.r6',
  ];

  /// نفس ترتيب القائمة فوق — لازم يطابق نوع `report_reason` في القاعدة.
  static const _reasonValues = [
    'inappropriate',
    'scam',
    'prohibited_item',
    'harassment',
    'fake_account',
    'other',
  ];

  Future<void> _submit() async {
    if (_reason == null) return;
    setState(() => _saving = true);

    final error = await ref.read(matchesRepositoryProvider).report(
          targetType: widget.targetType,
          targetId: widget.targetId,
          reason: _reasonValues[_reason!],
          details: _details.text,
        );

    if (!mounted) return;
    setState(() {
      _saving = false;
      _sent = error == null;
    });

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(error))),
      );
    }
  }

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (_sent) {
      return Scaffold(
        appBar: AppBar(),
        body: GEmptyState(
          icon: Icons.verified_outlined,
          tone: GEmptyTone.brand,
          title: context.tr('report.sent'),
          body: context.tr('safety.bannedBody'),
          actionLabel: context.tr('common.done'),
          onAction: () => context.pop(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('report.title'))),
      body: ListView(
        padding: const EdgeInsets.all(GSpace.screenH),
        children: [
          Text(
            context.tr('report.reason'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: GSpace.md),
          for (var i = 0; i < _reasons.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: GSpace.sm),
              child: GSurface(
                onTap: () => setState(() => _reason = i),
                color: _reason == i ? c.brandSoft : null,
                padding: const EdgeInsets.symmetric(
                  horizontal: GSpace.lg,
                  vertical: GSpace.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr(_reasons[i]),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    if (_reason == i)
                      Icon(Icons.check_circle_rounded,
                          size: 20, color: c.brand),
                  ],
                ),
              ),
            ),

          const SizedBox(height: GSpace.lg),
          GTextField(
            label: context.tr('report.details'),
            controller: _details,
            maxLines: 5,
            maxLength: 600,
          ),

          const SizedBox(height: GSpace.xxl),
          GButton(
            label: context.tr('report.submit'),
            style: GButtonStyle.danger,
            loading: _saving,
            onPressed: _reason == null ? null : _submit,
          ),
        ],
      ),
    );
  }
}
