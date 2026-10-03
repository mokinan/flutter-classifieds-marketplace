import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace/app/router.dart';
import 'package:marketplace/features/chat/chat_controller.dart';
import 'package:marketplace/features/listing/listing_image.dart';
import 'package:marketplace/l10n/l10n.dart';
import 'package:ui_kit/ui_kit.dart';

class ChatsPage extends ConsumerWidget {
  const ChatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final conversations = ref.watch(conversationsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navChats)),
      body: conversations.isEmpty
          ? StatusView(icon: Icons.chat_bubble_outline, title: l10n.chatsEmptyTitle, message: l10n.chatsEmptyMessage)
          : ListView.separated(
              itemCount: conversations.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 88),
              itemBuilder: (context, i) {
                final listing = conversations[i];
                final last = ref.watch(chatProvider(listing.id)).messages.lastOrNull;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.xs),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.sm),
                    child: SizedBox.square(dimension: 56, child: ListingImage(listing.thumbnailUrl, cacheWidth: 56)),
                  ),
                  title: Text(listing.sellerName),
                  subtitle: Text(last?.text ?? listing.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: PriceText(listing.priceHalalas, style: Theme.of(context).textTheme.labelLarge),
                  onTap: () => context.push(Routes.chat(listing.id), extra: listing),
                );
              },
            ),
    );
  }
}
