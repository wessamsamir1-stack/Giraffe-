import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/repositories/providers.dart';
import '../../widgets/g_common.dart';
import '../../widgets/item_card.dart';

class PublicProfileScreen extends ConsumerWidget {
  const PublicProfileScreen({super.key, required this.username});

  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final ar = context.s.isArabic;

    final async = ref.watch(publicProfileProvider(username));
    final user = async.valueOrNull;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text('@$username')),
        body: async.hasError
            ? GEmptyState(
                icon: Icons.cloud_off_rounded,
                title: context.tr('common.error'),
                body: context.tr('common.errorBody'),
                actionLabel: context.tr('common.retry'),
                onAction: () =>
                    ref.invalidate(publicProfileProvider(username)),
              )
            : const Center(child: CircularProgressIndicator()),
      );
    }

    final items = ref.watch(userItemsProvider(user.id)).valueOrNull ?? const [];
    final reviews = ref.watch(reviewsProvider(user.id)).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text('@${user.username}'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) async {
              if (v == 'report') {
                context.push(R.report('user', user.id));
              } else if (v == 'block') {
                await ref.read(matchesRepositoryProvider).block(user.id);
                ref.invalidate(matchesProvider(false));
                if (context.mounted) context.pop();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'report',
                child: Text(context.tr('common.report')),
              ),
              PopupMenuItem(
                value: 'block',
                child: Text(
                  context.tr('common.block'),
                  style: TextStyle(color: c.danger),
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(GSpace.screenH),
        children: [
          Column(
            children: [
              GAvatar(
                name: user.displayName,
                seed: user.avatarSeed,
                size: GSize.avatarLg,
              ),
              const SizedBox(height: GSpace.md),
              Text(
                user.displayName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: GSpace.sm),
              TrustBadge(level: user.trustLevel),
              const SizedBox(height: GSpace.sm),
              Text(
                '${user.city.name(ar)} · ${user.country.name(ar)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (user.bio.isNotEmpty) ...[
                const SizedBox(height: GSpace.md),
                Text(
                  user.bio,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),

          const SizedBox(height: GSpace.xl),
          GSurface(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${user.completedTrades}',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        context.tr('profile.trades'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.star_rounded, size: 16, color: c.warning),
                          Text(
                            user.rating.toStringAsFixed(1),
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ],
                      ),
                      Text(
                        '${user.ratingCount} ${context.tr('profile.reviews')}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${user.memberSinceYear}',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        context.tr('profile.memberSince'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: GSpace.xl),
          Text(
            context.tr('items.title'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: GSpace.md),
          if (items.isEmpty)
            Text(
              context.tr('items.empty.title'),
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: GSpace.md,
                mainAxisSpacing: GSpace.md,
                childAspectRatio: 0.66,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) => ItemCard(
                item: items[i],
                onTap: () => context.push(R.item(items[i].id)),
              ),
            ),

          const SizedBox(height: GSpace.xl),
          Text(
            context.tr('profile.reviews'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: GSpace.md),
          if (reviews.isEmpty)
            Text(
              context.tr('profile.noReviews'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          for (final review in reviews.take(3))
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

class ReviewCard extends StatelessWidget {
  const ReviewCard({
    super.key,
    required this.author,
    required this.rating,
    required this.comment,
    required this.date,
  });

  final String author;
  final double rating;
  final String comment;
  final String date;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GAvatar(name: author, seed: author.length, size: 32),
              const SizedBox(width: GSpace.sm),
              Expanded(
                child: Text(
                  author,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < rating.round()
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 14,
                    color: c.warning,
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: GSpace.sm),
          Text(comment, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: GSpace.xs),
          Text(date, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
