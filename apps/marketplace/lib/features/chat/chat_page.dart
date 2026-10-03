import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:marketplace/features/chat/chat_controller.dart';
import 'package:marketplace/features/listing/listing_image.dart';
import 'package:marketplace/l10n/l10n.dart';
import 'package:marketplace_api/marketplace_api.dart';
import 'package:ui_kit/ui_kit.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({required this.listing, super.key});

  final Listing listing;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    ref.read(chatProvider(widget.listing.id).notifier).send(text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final listing = widget.listing;
    final chat = ref.watch(chatProvider(listing.id));
    final messages = chat.messages.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.sm),
              child: SizedBox.square(dimension: 40, child: ListingImage(listing.thumbnailUrl, cacheWidth: 40)),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(listing.sellerName, style: theme.textTheme.titleMedium),
                  Text(
                    chat.sellerTyping ? l10n.typing : listing.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: chat.sellerTyping ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(Space.lg),
              itemCount: messages.length,
              itemBuilder: (_, i) => _Bubble(
                message: messages[i],
                onRetry: () => ref.read(chatProvider(listing.id).notifier).retry(messages[i].clientId),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.sm, Space.sm),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('message'),
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(hintText: l10n.messageHint, isDense: true),
                    ),
                  ),
                  IconButton.filled(key: const Key('send'), onPressed: _send, icon: const Icon(Icons.send)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.onRetry});

  final UiMessage message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final mine = message.fromMe;
    final failed = message.status == DeliveryStatus.failed;
    final time = DateFormat.jm(context.localeTag).format(message.sentAt);

    return Align(
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: GestureDetector(
        onTap: failed ? onRetry : null,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: Space.xs),
          padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
          decoration: BoxDecoration(
            color: failed
                ? scheme.errorContainer
                : mine
                ? scheme.primaryContainer
                : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(message.text),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(failed ? l10n.notSent : time, style: Theme.of(context).textTheme.labelSmall),
                  if (mine) ...[
                    const SizedBox(width: 4),
                    Icon(
                      switch (message.status) {
                        DeliveryStatus.sending => Icons.schedule,
                        DeliveryStatus.sent => Icons.done,
                        DeliveryStatus.failed => Icons.error_outline,
                      },
                      size: 14,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
