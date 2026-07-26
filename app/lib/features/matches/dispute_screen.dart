import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../widgets/g_button.dart';
import '../../widgets/g_common.dart';
import '../../widgets/g_text_field.dart';

/// مسار فض النزاع.
///
/// مفقود تماماً من الـ spec الأصلي وهو ضروري: الصفقات هتفشل،
/// والمنتج هيطلع مش زي الوصف، وحد هيتأخر وحد ما يجيش.
///
/// من غير المسار ده كل نزاع هيتحول لبلاغ عشوائي وتقييم انتقامي.
class DisputeScreen extends StatefulWidget {
  const DisputeScreen({super.key, required this.matchId});

  final String matchId;

  @override
  State<DisputeScreen> createState() => _DisputeScreenState();
}

class _DisputeScreenState extends State<DisputeScreen> {
  final _details = TextEditingController();
  int? _reason;
  bool _sent = false;

  static const _reasons = [
    'dispute.r1',
    'dispute.r2',
    'dispute.r3',
    'dispute.r4',
    'dispute.r5',
  ];

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
          icon: Icons.support_agent_rounded,
          tone: GEmptyTone.brand,
          title: context.tr('report.sent'),
          body: context.tr('dispute.body'),
          actionLabel: context.tr('common.done'),
          onAction: () => context.go('/matches'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('dispute.title'))),
      body: ListView(
        padding: const EdgeInsets.all(GSpace.screenH),
        children: [
          GNotice(
            tone: GNoticeTone.warning,
            icon: Icons.ac_unit_rounded,
            text: context.tr('dispute.body'),
          ),
          const SizedBox(height: GSpace.xl),

          Text(
            context.tr('dispute.reason'),
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
            label: context.tr('dispute.details'),
            controller: _details,
            maxLines: 5,
            maxLength: 800,
          ),

          const SizedBox(height: GSpace.lg),
          GButton(
            label: context.tr('dispute.attach'),
            icon: Icons.add_photo_alternate_outlined,
            style: GButtonStyle.ghost,
            onPressed: () {},
          ),

          const SizedBox(height: GSpace.xxl),
          GButton(
            label: context.tr('dispute.submit'),
            style: GButtonStyle.danger,
            onPressed: _reason == null ? null : () => setState(() => _sent = true),
          ),
        ],
      ),
    );
  }
}
