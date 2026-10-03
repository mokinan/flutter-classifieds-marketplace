import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace/app/locale_controller.dart';
import 'package:marketplace/app/router.dart';
import 'package:marketplace/core/providers.dart';
import 'package:marketplace/core/relative_time.dart';
import 'package:marketplace/features/favorites/favorites_controller.dart';
import 'package:marketplace/features/feed/feed_controller.dart';
import 'package:marketplace/features/listing/listing_image.dart';
import 'package:marketplace/l10n/l10n.dart';
import 'package:marketplace_api/marketplace_api.dart';
import 'package:ui_kit/ui_kit.dart';

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) ref.read(feedControllerProvider.notifier).loadMore();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(feedControllerProvider);
    final controller = ref.read(feedControllerProvider.notifier);
    final now = ref.watch(clockProvider)();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          TextButton(
            onPressed: () {
              final arabic = Localizations.localeOf(context).languageCode == 'ar';
              ref.read(localeProvider.notifier).set(Locale(arabic ? 'en' : 'ar'));
            },
            child: Text(l10n.switchLanguage),
          ),
          _SortButton(current: state.query.sort, onSelected: controller.sortBy),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(112),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
                child: TextField(
                  key: const Key('search'),
                  onChanged: controller.search,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: l10n.searchHint,
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                  ),
                ),
              ),
              _CategoryBar(selected: state.query.category, onSelected: controller.selectCategory),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          if (state.isOffline)
            OfflineBanner(message: l10n.offlineShowing(relativeTime(l10n, state.cachedAt!, now: now))),
          Expanded(
            child: RefreshIndicator(
              onRefresh: controller.refresh,
              child: switch (state.status) {
                FeedStatus.loading => const _SkeletonGrid(),
                FeedStatus.error => ListView(
                  children: [
                    const SizedBox(height: 80),
                    StatusView(
                      icon: state.error is NetworkUnavailable ? Icons.wifi_off : Icons.error_outline,
                      title: l10n.errorTitle(state.error),
                      message: state.error is NetworkUnavailable ? l10n.errorNetworkHint : null,
                      actionLabel: l10n.retry,
                      onAction: controller.refresh,
                    ),
                  ],
                ),
                FeedStatus.ready when state.items.isEmpty => ListView(
                  children: [
                    const SizedBox(height: 80),
                    StatusView(icon: Icons.search_off, title: l10n.noResults, message: l10n.noResultsHint),
                  ],
                ),
                FeedStatus.ready => _Grid(state: state, scroll: _scroll, now: now),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Grid extends ConsumerWidget {
  const _Grid({required this.state, required this.scroll, required this.now});

  final FeedState state;
  final ScrollController scroll;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final favorites = ref.watch(favoritesProvider);
    return CustomScrollView(
      controller: scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, 0),
          sliver: SliverToBoxAdapter(
            child: Text(l10n.resultsCount(state.total), style: Theme.of(context).textTheme.labelLarge),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(Space.lg),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 240,
              mainAxisSpacing: Space.md,
              crossAxisSpacing: Space.md,
              childAspectRatio: 0.62,
            ),
            itemCount: state.items.length,
            itemBuilder: (context, i) {
              final listing = state.items[i];
              return ListingTile(listing: listing, isFavorite: favorites.containsKey(listing.id), now: now);
            },
          ),
        ),
        if (state.loadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(bottom: Space.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

/// A [ListingCard] wired to navigation and favorites.
class ListingTile extends ConsumerWidget {
  const ListingTile({required this.listing, required this.isFavorite, required this.now, super.key});

  final Listing listing;
  final bool isFavorite;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ListingCard(
      title: listing.title,
      priceHalalas: listing.priceHalalas,
      subtitle: '${l10n.cityName(listing.city)} · ${relativeTime(l10n, listing.postedAt, now: now)}',
      image: Hero(
        tag: 'listing-${listing.id}',
        child: ListingImage(listing.thumbnailUrl, cacheWidth: 240),
      ),
      isFavorite: isFavorite,
      favoriteTooltip: isFavorite ? l10n.saved : l10n.save,
      onFavoriteToggle: () async {
        final ok = await ref.read(favoritesProvider.notifier).toggle(listing);
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.favoriteFailed)));
        }
      },
      onTap: () => context.push(Routes.listing(listing.id), extra: listing),
    );
  }
}

class _CategoryBar extends ConsumerWidget {
  const _CategoryBar({required this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Space.lg),
        children: [
          for (final (slug, label) in [
            (null, l10n.allCategories),
            for (final c in categories) (c.slug, l10n.categoryName(c.slug)),
          ])
            Padding(
              padding: const EdgeInsetsDirectional.only(end: Space.sm),
              child: ChoiceChip(label: Text(label), selected: selected == slug, onSelected: (_) => onSelected(slug)),
            ),
        ],
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.current, required this.onSelected});

  final ListingSort current;
  final ValueChanged<ListingSort> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopupMenuButton<ListingSort>(
      tooltip: l10n.sortTitle,
      icon: const Icon(Icons.sort),
      initialValue: current,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final (sort, label) in [
          (ListingSort.relevance, l10n.sortRelevance),
          (ListingSort.newest, l10n.sortNewest),
          (ListingSort.priceLowToHigh, l10n.sortPriceLow),
          (ListingSort.priceHighToLow, l10n.sortPriceHigh),
        ])
          CheckedPopupMenuItem(value: sort, checked: sort == current, child: Text(label)),
      ],
    );
  }
}

class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();

  @override
  Widget build(BuildContext context) => GridView.builder(
    padding: const EdgeInsets.all(Space.lg),
    physics: const AlwaysScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 240,
      mainAxisSpacing: Space.md,
      crossAxisSpacing: Space.md,
      childAspectRatio: 0.62,
    ),
    itemCount: 6,
    itemBuilder: (_, _) => const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(aspectRatio: 1, child: Skeleton(radius: Radii.md)),
        SizedBox(height: Space.sm),
        Skeleton(height: 14),
        SizedBox(height: Space.xs),
        Skeleton(height: 14, width: 80),
      ],
    ),
  );
}
