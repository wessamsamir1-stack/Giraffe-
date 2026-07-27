import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/repositories/providers.dart';
import '../../widgets/g_common.dart';
import 'public_profile_screen.dart';

class ReviewsScreen extends ConsumerWidget {
  const ReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;

    final me = ref.watch(myProfileProvider).valueOrNull;
    if (me == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('profile.reviews'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final reviews = ref.watch(reviewsProvider(me.id)).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('profile.reviews'))),
      body: reviews.isEmpty
          ? GEmptyState(
              icon: Icons.star_outline_rounded,
              title: context.tr('profile.noReviews'),
              body: context.tr('rate.hidden'),
            )
          : ListView(
              padding: const EdgeInsets.all(GSpace.screenH),
              children: [
                GSurface(
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            me.rating.toStringAsFixed(1),
                            style: Theme.of(context).textTheme.displaySmall,
                          ),
                          Row(
                            children: List.generate(
                              5,
                              (i) => Icon(
                                i < me.rating.round()
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                size: 15,
                                color: c.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: GSpace.xl),
                      Expanded(
                        child: Column(
                          children: [
                            for (var star = 5; star >= 1; star--)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Row(
                                  children: [
                                    Text(
                                      '$star',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                    const SizedBox(width: GSpace.xs),
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: GRadius.brPill,
                                        child: LinearProgressIndicator(
                                          value: switch (star) {
                                            5 => 0.72,
                                            4 => 0.2,
                                            3 => 0.06,
                                            _ => 0.01,
                                          },
                                          minHeight: 5,
                                          backgroundColor: c.surfaceSunken,
                                          valueColor:
                                              AlwaysStoppedAnimation(c.warning),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: GSpace.xl),
                for (final review in reviews)
                  Padding(
                    padding: const EdgeInsets.only(bottom: GSpace.md),
                    child: ReviewCard(
                      author: review.author,
                      rating: review.rating,
                      comment: review.comment,
                      date: review.date,
                    ),
                  ),
              ],
            ),
    );
  }
}
