import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/mock/mock_data.dart';
import '../../widgets/g_button.dart';
import '../../widgets/g_common.dart';
import '../../widgets/g_text_field.dart';

/// تقييم الصفقة.
///
/// التقييم **محجوب** لحد ما الطرفين يقيّموا أو تعدي 7 أيام —
/// عشان نمنع التقييم الانتقامي. نفس نظام Airbnb وهو مجرب.
class RateTradeScreen extends StatefulWidget {
  const RateTradeScreen({super.key, required this.matchId});

  final String matchId;

  @override
  State<RateTradeScreen> createState() => _RateTradeScreenState();
}

class _RateTradeScreenState extends State<RateTradeScreen> {
  final _comment = TextEditingController();
  int _overall = 0;
  int _accuracy = 0;
  int _punctuality = 0;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final match = Mock.match(widget.matchId);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('rate.title'))),
      body: ListView(
        padding: const EdgeInsets.all(GSpace.screenH),
        children: [
          Center(
            child: Column(
              children: [
                GAvatar(
                  name: match.other.displayName,
                  seed: match.other.avatarSeed,
                  size: GSize.avatarLg,
                ),
                const SizedBox(height: GSpace.sm),
                Text(
                  match.other.displayName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
          const SizedBox(height: GSpace.xxl),

          _Stars(
            label: context.tr('rate.overall'),
            value: _overall,
            onChanged: (v) => setState(() => _overall = v),
            large: true,
          ),
          const SizedBox(height: GSpace.xl),
          _Stars(
            label: context.tr('rate.accuracy'),
            value: _accuracy,
            onChanged: (v) => setState(() => _accuracy = v),
          ),
          const SizedBox(height: GSpace.lg),
          _Stars(
            label: context.tr('rate.punctuality'),
            value: _punctuality,
            onChanged: (v) => setState(() => _punctuality = v),
          ),

          const SizedBox(height: GSpace.xxl),
          GTextField(
            label: '${context.tr('rate.comment')} · ${context.tr('common.optional')}',
            controller: _comment,
            hint: context.tr('rate.commentHint'),
            maxLines: 4,
            maxLength: 400,
          ),

          const SizedBox(height: GSpace.lg),
          GNotice(
            icon: Icons.visibility_off_outlined,
            text: context.tr('rate.hidden'),
          ),

          const SizedBox(height: GSpace.xxl),
          GButton(
            label: context.tr('rate.submit'),
            onPressed: _overall == 0 ? null : () => context.go('/matches'),
          ),
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({
    required this.label,
    required this.value,
    required this.onChanged,
    this.large = false,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final size = large ? 40.0 : 28.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: large
              ? Theme.of(context).textTheme.titleLarge
              : Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: GSpace.sm),
        Row(
          mainAxisAlignment:
              large ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: List.generate(5, (i) {
            final filled = i < value;
            return GestureDetector(
              onTap: () => onChanged(i + 1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: size,
                  color: filled ? c.warning : c.borderStrong,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
