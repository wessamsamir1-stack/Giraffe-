import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/l10n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/mock/mock_data.dart';
import '../../data/models/models.dart';
import '../../widgets/g_button.dart';
import '../../widgets/g_common.dart';
import 'trade_swipe_card.dart';

/// شاشة السحب — قلب التطبيق.
class DeckScreen extends ConsumerStatefulWidget {
  const DeckScreen({super.key});

  @override
  ConsumerState<DeckScreen> createState() => _DeckScreenState();
}

class _DeckScreenState extends ConsumerState<DeckScreen>
    with SingleTickerProviderStateMixin {
  late final List<TradeCandidate> _cards = List.of(Mock.deck);
  final List<TradeCandidate> _history = [];

  Offset _drag = Offset.zero;
  bool _animatingOut = false;

  static const double _thresholdX = 110;
  static const double _thresholdY = 130;

  TradeCandidate? get _top => _cards.isEmpty ? null : _cards.first;

  SwipeIntent? get _currentIntent {
    if (_drag.dy < -_thresholdY * 0.5 && _drag.dy.abs() > _drag.dx.abs()) {
      return SwipeIntent.dream;
    }
    if (_drag.dx > _thresholdX * 0.4) return SwipeIntent.interested;
    if (_drag.dx < -_thresholdX * 0.4) return SwipeIntent.skip;
    return null;
  }

  void _commit(SwipeIntent intent) {
    final card = _top;
    if (card == null || _animatingOut) return;

    HapticFeedback.lightImpact();

    setState(() {
      _history.add(card);
      _cards.removeAt(0);
      _drag = Offset.zero;
    });

    if (intent == SwipeIntent.skip) return;

    // خصم من الحد اليومي
    final left = ref.read(swipesLeftProvider);
    ref.read(swipesLeftProvider.notifier).state = (left - 1).clamp(0, 999);

    if (intent == SwipeIntent.dream) {
      final dreams = ref.read(dreamsLeftProvider);
      ref.read(dreamsLeftProvider.notifier).state = (dreams - 1).clamp(0, 99);
    }

    // في النسخة النهائية الماتش بيتحدد من الخادم.
    // هنا بنحاكي: أول كارت بيعمل ماتش عشان نقدر نستعرض الشاشة.
    if (card.id == 'tc_1') {
      Future.microtask(() {
        if (mounted) context.push(R.matchCelebrate('m_1'));
      });
    }
  }

  void _undo() {
    if (_history.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _cards.insert(0, _history.removeLast());
      _drag = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final swipesLeft = ref.watch(swipesLeftProvider);

    if (swipesLeft <= 0) {
      return _wrap(
        context,
        GEmptyState(
          icon: Icons.hourglass_bottom_rounded,
          tone: GEmptyTone.brand,
          title: context.tr('deck.limitReached.title'),
          body: context.tr('deck.limitReached.body'),
          actionLabel: context.tr('market.title'),
          onAction: () => context.go(R.market),
        ),
      );
    }

    if (_cards.isEmpty) {
      return _wrap(
        context,
        GEmptyState(
          icon: Icons.style_rounded,
          tone: GEmptyTone.brand,
          title: context.tr('deck.empty.title'),
          body: context.tr('deck.empty.body'),
          actionLabel: context.tr('deck.empty.addItem'),
          onAction: () => context.push(R.addItem),
          secondaryLabel: context.tr('deck.empty.editWishlist'),
          onSecondary: () => context.push(R.wishlist),
        ),
      );
    }

    return _wrap(
      context,
      Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                GSpace.lg,
                GSpace.sm,
                GSpace.lg,
                GSpace.md,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // الكارت اللي وراه
                  if (_cards.length > 1)
                    Transform.scale(
                      scale: 0.94,
                      child: Transform.translate(
                        offset: const Offset(0, 14),
                        child: Opacity(
                          opacity: 0.6,
                          child: IgnorePointer(
                            child: TradeSwipeCard(candidate: _cards[1]),
                          ),
                        ),
                      ),
                    ),

                  // الكارت العلوي
                  _draggableTop(context),
                ],
              ),
            ),
          ),

          _ActionBar(
            onSkip: () => _commit(SwipeIntent.skip),
            onInterested: () => _commit(SwipeIntent.interested),
            onDream: () => _commit(SwipeIntent.dream),
            onUndo: _history.isEmpty ? null : _undo,
            dreamsLeft: ref.watch(dreamsLeftProvider),
          ),
          const SizedBox(height: GSpace.sm),
          Text(
            context.trf('deck.dailyLeft', {'n': swipesLeft}),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: c.textTertiary),
          ),
          const SizedBox(height: GSpace.md),
        ],
      ),
    );
  }

  Widget _draggableTop(BuildContext context) {
    final card = _top!;
    final rotation = (_drag.dx / 1200).clamp(-0.18, 0.18);
    final intent = _currentIntent;

    return GestureDetector(
      onPanUpdate: (details) => setState(() => _drag += details.delta),
      onPanEnd: (_) {
        if (_drag.dy < -_thresholdY && _drag.dy.abs() > _drag.dx.abs()) {
          _commit(SwipeIntent.dream);
        } else if (_drag.dx > _thresholdX) {
          _commit(SwipeIntent.interested);
        } else if (_drag.dx < -_thresholdX) {
          _commit(SwipeIntent.skip);
        } else {
          setState(() => _drag = Offset.zero);
        }
      },
      child: AnimatedContainer(
        duration: _drag == Offset.zero ? GDuration.base : Duration.zero,
        curve: GCurve.spring,
        transform: Matrix4.identity()
          ..translate(_drag.dx, _drag.dy)
          ..rotateZ(rotation),
        transformAlignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            TradeSwipeCard(
              candidate: card,
              onTapDetails: () => context.push(R.item(card.theirItem.id)),
            ),
            if (intent != null)
              Align(
                alignment: switch (intent) {
                  SwipeIntent.dream => Alignment.topCenter,
                  SwipeIntent.interested => Alignment.centerLeft,
                  SwipeIntent.skip => Alignment.centerRight,
                },
                child: Padding(
                  padding: const EdgeInsets.all(GSpace.xxl),
                  child: SwipeStamp(
                    intent: intent,
                    opacity: intent == SwipeIntent.dream
                        ? (_drag.dy.abs() / _thresholdY)
                        : (_drag.dx.abs() / _thresholdX),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _wrap(BuildContext context, Widget child) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('deck.title')),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => context.push(R.deckFilters),
          ),
        ],
      ),
      body: SafeArea(top: false, child: child),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.onSkip,
    required this.onInterested,
    required this.onDream,
    required this.onUndo,
    required this.dreamsLeft,
  });

  final VoidCallback onSkip;
  final VoidCallback onInterested;
  final VoidCallback onDream;
  final VoidCallback? onUndo;
  final int dreamsLeft;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // زر التراجع — مجاني للجميع عن عمد.
        // في المقايضة السحبة الغلط مؤلمة أكتر من تطبيقات التعارف،
        // فتحويله لميزة مدفوعة معناه بيع حل لمشكلة إحنا سببناها.
        GIconButton(
          icon: Icons.replay_rounded,
          size: 46,
          bordered: true,
          onPressed: onUndo,
          foreground: onUndo == null ? c.textTertiary : c.textSecondary,
          tooltip: context.tr('deck.undo'),
        ),
        const SizedBox(width: GSpace.lg),
        _BigAction(
          icon: Icons.close_rounded,
          color: AppPalette.swipeSkip,
          size: 58,
          onTap: onSkip,
          tooltip: context.tr('deck.skip'),
        ),
        const SizedBox(width: GSpace.lg),
        Stack(
          clipBehavior: Clip.none,
          children: [
            _BigAction(
              icon: Icons.star_rounded,
              color: AppPalette.swipeDream,
              size: 52,
              onTap: dreamsLeft > 0 ? onDream : null,
              tooltip: context.tr('deck.dream'),
            ),
            PositionedDirectional(
              top: -2,
              end: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppPalette.swipeDream,
                  borderRadius: GRadius.brPill,
                  border: Border.all(color: c.background, width: 1.6),
                ),
                child: Text(
                  '$dreamsLeft',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: GSpace.lg),
        _BigAction(
          icon: Icons.favorite_rounded,
          color: AppPalette.swipeInterested,
          size: 58,
          onTap: onInterested,
          tooltip: context.tr('deck.interested'),
        ),
      ],
    );
  }
}

class _BigAction extends StatelessWidget {
  const _BigAction({
    required this.icon,
    required this.color,
    required this.size,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onTap != null;

    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: c.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: enabled ? color.withOpacity(0.35) : c.border,
              width: 1.6,
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: size * 0.44,
            color: enabled ? color : c.textTertiary,
          ),
        ),
      ),
    );
  }
}
