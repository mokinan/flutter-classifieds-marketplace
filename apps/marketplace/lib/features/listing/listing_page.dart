import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:go_router/go_router.dart';
import 'package:marketplace/app/router.dart';
import 'package:marketplace/core/providers.dart';
import 'package:marketplace/core/relative_time.dart';
import 'package:marketplace/features/chat/chat_controller.dart';
import 'package:marketplace/features/favorites/favorites_controller.dart';
import 'package:marketplace/features/listing/listing_image.dart';
import 'package:marketplace/l10n/l10n.dart';
import 'package:marketplace_api/marketplace_api.dart';
import 'package:ui_kit/ui_kit.dart';

/// Fetches a listing by id — used for deep links and to refresh details.
final FutureProviderFamily<Listing, int> listingProvider = FutureProvider.autoDispose.family<Listing, int>(
  (ref, id) => ref.watch(marketplaceApiProvider).listing(id),
);

class ListingDetailsPage extends ConsumerWidget {
  const ListingDetailsPage({required this.id, this.initial, super.key});

  final int id;

  /// Shown immediately when available (navigating from a list).
  final Listing? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final saved = ref.watch(favoritesProvider)[id];
    final listing = initial ?? saved ?? ref.watch(listingProvider(id)).value;

    if (listing == null) {
      final async = ref.watch(listingProvider(id));
      return Scaffold(
        appBar: AppBar(),
        body: async.hasError
            ? StatusView(
                icon: Icons.error_outline,
                title: l10n.errorTitle(async.error is ApiException ? async.error! as ApiException : null),
                actionLabel: l10n.retry,
                onAction: () => ref.invalidate(listingProvider(id)),
              )
            : const Center(child: CircularProgressIndicator()),
      );
    }
    return _Details(listing: listing);
  }
}

class _Details extends ConsumerStatefulWidget {
  const _Details({required this.listing});

  final Listing listing;

  @override
  ConsumerState<_Details> createState() => _DetailsState();
}

class _DetailsState extends ConsumerState<_Details> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final listing = widget.listing;
    final images = listing.imageUrls.isEmpty ? [listing.thumbnailUrl] : listing.imageUrls;
    final isFavorite = ref.watch(favoritesProvider).containsKey(listing.id);
    final now = ref.watch(clockProvider)();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: MediaQuery.sizeOf(context).width,
            pinned: true,
            actions: [
              IconButton.filledTonal(
                tooltip: isFavorite ? l10n.saved : l10n.save,
                isSelected: isFavorite,
                onPressed: () async {
                  final ok = await ref.read(favoritesProvider.notifier).toggle(listing);
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.favoriteFailed)));
                  }
                },
                icon: const Icon(Icons.favorite_border),
                selectedIcon: Icon(Icons.favorite, color: theme.colorScheme.error),
              ),
              const SizedBox(width: Space.sm),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    itemCount: images.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (_, i) => i == 0
                        ? Hero(tag: 'listing-${listing.id}', child: ListingImage(images[i]))
                        : ListingImage(images[i]),
                  ),
                  if (images.length > 1)
                    Positioned(
                      bottom: Space.md,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < images.length; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: i == _page ? 18 : 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: i == _page ? 1 : 0.6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(Space.lg),
            sliver: SliverList.list(
              children: [
                PriceText(listing.priceHalalas, style: theme.textTheme.headlineSmall),
                const SizedBox(height: Space.sm),
                Text(listing.title, style: theme.textTheme.titleLarge),
                const SizedBox(height: Space.sm),
                Row(
                  children: [
                    Icon(Icons.place_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: Space.xs),
                    Text(
                      '${l10n.cityName(listing.city)} · ${l10n.categoryName(listing.category)} · '
                      '${relativeTime(l10n, listing.postedAt, now: now)}',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const Divider(height: Space.xxl),
                Text(l10n.description, style: theme.textTheme.titleMedium),
                const SizedBox(height: Space.sm),
                Text(listing.description, style: theme.textTheme.bodyLarge),
                const Divider(height: Space.xxl),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Text(listing.sellerName.characters.first)),
                  title: Text(listing.sellerName),
                  subtitle: Text(l10n.seller),
                ),
                const SizedBox(height: 96),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: FilledButton.icon(
            onPressed: () {
              ref.read(conversationsProvider.notifier).open(listing);
              context.push(Routes.chat(listing.id), extra: listing);
            },
            icon: const Icon(Icons.chat_bubble_outline),
            label: Text(l10n.chatWithSeller),
          ),
        ),
      ),
    );
  }
}
