import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/catalog/categories.dart';
import '../../data/mock/mock_data.dart';
import '../../widgets/g_button.dart';
import '../../widgets/g_common.dart';

class MatchCelebrationScreen extends StatefulWidget {
  const MatchCelebrationScreen({super.key, required this.matchId});

  final String matchId;

  @override
  State<MatchCelebrationScreen> createState() => _MatchCelebrationScreenState();
}

class _MatchCelebrationScreenState extends State<MatchCelebrationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: GDuration.celebrate,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final match = Mock.match(widget.matchId);

    return Scaffold(
      backgroundColor: c.brand,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: GSpace.screenH),
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
              ),
              const Spacer(),

              FadeTransition(
                opacity: _controller,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.7, end: 1).animate(
                    CurvedAnimation(parent: _controller, curve: GCurve.enter),
                  ),
                  child: Column(
                    children: [
                      Text(
                        context.tr('match.title'),
                        style: Theme.of(context)
                            .textTheme
                            .displayMedium
                            ?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: GSpace.md),
                      Text(
                        context.trf('match.body', {
                          'name': match.other.displayName,
                        }),
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: Colors.white.withOpacity(0.9)),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: GSpace.huge),

              // المنتجان جنب بعض
              Row(
                children: [
                  Expanded(
                    child: _MatchItem(
                      title: match.myItem.title,
                      icon: Categories.byId(match.myItem.categoryId).icon,
                      seed: match.myItem.imageSeed,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: GSpace.md),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.swap_horiz_rounded,
                        color: c.brand,
                        size: 24,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _MatchItem(
                      title: match.theirItem.title,
                      icon: Categories.byId(match.theirItem.categoryId).icon,
                      seed: match.theirItem.imageSeed,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              GButton(
                label: context.tr('match.startChat'),
                style: GButtonStyle.secondary,
                onPressed: () {
                  context.pop();
                  context.push(R.room(match.id));
                },
              ),
              const SizedBox(height: GSpace.md),
              TextButton(
                onPressed: () => context.pop(),
                child: Text(
                  context.tr('match.keepSwiping'),
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(height: GSpace.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchItem extends StatelessWidget {
  const _MatchItem({
    required this.title,
    required this.icon,
    required this.seed,
  });

  final String title;
  final IconData icon;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: GRadius.brXl,
              border: Border.all(color: Colors.white, width: 3),
            ),
            clipBehavior: Clip.antiAlias,
            child: GImagePlaceholder(
              seed: seed,
              icon: icon,
              radius: BorderRadius.zero,
            ),
          ),
        ),
        const SizedBox(height: GSpace.sm),
        Text(
          title,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: Colors.white),
        ),
      ],
    );
  }
}
