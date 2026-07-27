import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/models/models.dart';
import '../../data/repositories/deck_repository.dart';
import '../../data/repositories/providers.dart';
import '../../widgets/g_button.dart';
import '../../widgets/g_common.dart';
import 'trade_swipe_card.dart';

/// شاشة السحب — قلب التطبيق.
///
/// ملاحظة معمارية: التطبيق **مابيقررش الماتش**. كل سحبة بتروح للقاعدة
/// عبر `record_swipe` وهي اللي بترجّع هل حصل ماتش ولا لأ. لو الحساب كان
/// هنا، أي حد يقدر يتحايل عليه.
class DeckScreen extends ConsumerStatefulWidget {
  const DeckScreen({super.key});

  @override
  ConsumerState<DeckScreen> createState() => _DeckScreenState();
}

class _DeckScreenState extends ConsumerState<DeckScreen> {
  final List<TradeCandidate> _cards = [];
  final List<TradeCandidate> _history = [];

  Offset _drag = Offset.zero;
  bool _busy = false;
  bool _seeded = false;

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

  // ---------------------------------------------------------------------------
  Future<void> _commit(SwipeIntent intent) async {
    final card = _top;
    if (card == null || _busy) return;

    HapticFeedback.lightImpact();

    setState(() {
      _busy = true;
      _history.add(card);
      _cards.removeAt(0);
      _drag = Offset.zero;
    });

    final result = await ref.read(deckRepositoryProvider).swipe(
          targetItemId: card.theirItem.id,
          offeredItemId: card.myItem.id,
          intent: intent,
        );

    if (!mounted) return;
    setState(() => _busy = false);

    if (!result.ok) {
      // الكارت يرجع مكانه — السحبة ما اتسجلتش
      setState(() {
        _cards.insert(0, card);
        if (_history.isNotEmpty) _history.removeLast();
      });
      _toast(context.tr(result.errorKey ?? 'common.error'));
      return;
    }

    ref.invalidate(swipeQuotaProvider);

    if (result.matched && result.matchId != null) {
      await context.push(R.matchCelebrate(result.matchId!));
      if (mounted) ref.invalidate(matchesProvider);
    }

    // نجيب دفعة جديدة قبل ما الكروت تخلص خالص
    if (_cards.length <= 2) await _loadMore();
  }

  Future<void> _undo() async {
    if (_history.isEmpty || _busy) return;
    HapticFeedback.selectionClick();

    setState(() => _busy = true);
    final ok = await ref.read(deckRepositoryProvider).undo();
    if (!mounted) return;

    setState(() {
      _busy = false;
      if (ok) {
        _cards.insert(0, _history.removeLast());
        _drag = Offset.zero;
      }
    });

    if (!ok && mounted) _toast(context.tr('common.error'));
    ref.invalidate(swipeQuotaProvider);
  }

  Future<void> _loadMore() async {
    final fresh = await ref.read(deckRepositoryProvider).deck();
    if (!mounted) return;

    final known = {
      for (final card in [..._cards, ..._history]) card.id,
    };
    setState(() {
      _cards.addAll(fresh.where((card) => !known.contains(card.id)));
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final deck = ref.watch(deckProvider);
    final quota = ref.watch(swipeQuotaProvider);

    // أول تحميل بس — بعد كده الحالة محلية عشان السحب يفضل سلس
    deck.whenData((cards) {
      if (!_seeded) {
        _seeded = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _cards.addAll(cards));
        });
      }
    });

    final swipesLeft = quota.valueOrNull?.swipes ?? 50;
    final dreamsLeft = quota.valueOrNull?.dreams ?? 3;

    return _wrap(
      context,
      switch (deck) {
        AsyncError() => GEmptyState(
            icon: Icons.cloud_off_rounded,
            title: context.tr('common.error'),
            body: context.tr('common.errorBody'),
            actionLabel: context.tr('common.retry'),
            onAction: () => ref.invalidate(deckProvider),
          ),
        AsyncLoading() when _cards.isEmpty => const _DeckSkeleton(),
        _ when swipesLeft <= 0 => GEmptyState(
            icon: Icons.hourglass_bottom_rounded,
            tone: GEmptyTone.brand,
            title: context.tr('deck.limitReached.title'),
            body: context.tr('deck.limitReached.body'),
            actionLabel: context.tr('market.title'),
            onAction: () => context.go(R.market),
          ),
        _ when _cards.isEmpty => GEmptyState(
            icon: Icons.style_rounded,
            tone: GEmptyTone.brand,
            title: context.tr('deck.empty.title'),
            body: context.tr('deck.empty.body'),
            actionLabel: context.tr('deck.empty.addItem'),
            onAction: () => context.push(R.addItem),
            secondaryLabel: context.tr('deck.empty.editWishlist'),
            onSecondary: () => context.push(R.wishlist),
          ),
        _ => Column(
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
                dreamsLeft: dreamsLeft,
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
      },
    );
  }

  Widget _draggableTop(BuildContext context) {
    final card = _top;
    if (card == null) return const SizedBox.shrink();

    final rotation = (_drag.dx / 1200).clamp(-0.18, 0.18);
    final intent = _currentIntent;

    return GestureDetector(
      onPanUpdate: _busy ? null : (d) => setState(() => _drag += d.delta),
      onPanEnd: _busy
          ? null
          : (_) {
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

/// كارت هيكلي أثناء أول تحميل.
class _DeckSkeleton extends StatelessWidget {
  const _DeckSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(GSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Expanded(child: GSkeleton(radius: GRadius.brXxl)),
          const SizedBox(height: GSpace.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              4,
              (_) => const Padding(
                padding: EdgeInsets.symmetric(horizontal: GSpace.sm),
                child: GSkeleton(width: 52, height: 52, radius: GRadius.brPill),
              ),
            ),
          ),
          const SizedBox(height: GSpace.xxl),
        ],
      ),
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
        // التراجع مجاني للجميع عن عمد. في المقايضة السحبة الغلط مؤلمة
        // أكتر من تطبيقات التعارف — بيع الحل لمشكلة إحنا سببناها قرار سيء.
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
