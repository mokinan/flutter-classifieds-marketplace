import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace/features/chat/chat_page.dart';
import 'package:marketplace/features/chat/chats_page.dart';
import 'package:marketplace/features/favorites/saved_page.dart';
import 'package:marketplace/features/feed/feed_page.dart';
import 'package:marketplace/features/listing/listing_page.dart';
import 'package:marketplace/features/post_ad/post_ad_page.dart';
import 'package:marketplace/l10n/l10n.dart';
import 'package:marketplace_api/marketplace_api.dart';

abstract final class Routes {
  static const browse = '/';
  static const saved = '/saved';
  static const sell = '/sell';
  static const chats = '/chats';

  /// Deep-linkable: `https://market.example/listing/12` or
  /// `marketplace://app/listing/12`.
  static String listing(int id) => '/listing/$id';
  static String chat(int listingId) => '/chats/$listingId';
}

GoRouter createRouter() => GoRouter(
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => _Shell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: Routes.browse, builder: (_, _) => const FeedPage())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: Routes.saved, builder: (_, _) => const SavedPage())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: Routes.sell, builder: (_, _) => const PostAdPage())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: Routes.chats, builder: (_, _) => const ChatsPage())],
        ),
      ],
    ),
    GoRoute(
      path: '/listing/:id',
      builder: (_, state) => ListingDetailsPage(
        id: int.parse(state.pathParameters['id']!),
        // Passed when navigating from a list, so details render instantly;
        // deep links fetch by id instead.
        initial: state.extra is Listing ? state.extra! as Listing : null,
      ),
    ),
    GoRoute(
      path: '/chats/:listingId',
      builder: (_, state) => ChatPage(listing: state.extra! as Listing),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(),
    body: Center(child: Text(context.l10n.noResults)),
  ),
);

class _Shell extends StatelessWidget {
  const _Shell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.search), label: l10n.navBrowse),
          NavigationDestination(
            icon: const Icon(Icons.favorite_border),
            selectedIcon: const Icon(Icons.favorite),
            label: l10n.navSaved,
          ),
          NavigationDestination(
            icon: const Icon(Icons.add_circle_outline),
            selectedIcon: const Icon(Icons.add_circle),
            label: l10n.navSell,
          ),
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline),
            selectedIcon: const Icon(Icons.chat_bubble),
            label: l10n.navChats,
          ),
        ],
      ),
    );
  }
}
