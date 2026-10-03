import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace/core/providers.dart';
import 'package:marketplace/features/favorites/favorites_controller.dart';
import 'package:marketplace/features/feed/feed_page.dart';
import 'package:marketplace/l10n/l10n.dart';
import 'package:ui_kit/ui_kit.dart';

/// Saved listings, served from local snapshots — works offline.
class SavedPage extends ConsumerWidget {
  const SavedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final saved = ref.watch(favoritesProvider).values.toList().reversed.toList();
    final now = ref.watch(clockProvider)();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSaved)),
      body: saved.isEmpty
          ? StatusView(icon: Icons.favorite_border, title: l10n.savedEmptyTitle, message: l10n.savedEmptyMessage)
          : GridView.builder(
              padding: const EdgeInsets.all(Space.lg),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 240,
                mainAxisSpacing: Space.md,
                crossAxisSpacing: Space.md,
                childAspectRatio: 0.62,
              ),
              itemCount: saved.length,
              itemBuilder: (_, i) => ListingTile(listing: saved[i], isFavorite: true, now: now),
            ),
    );
  }
}
