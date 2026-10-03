import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:marketplace/core/providers.dart';
import 'package:marketplace_api/marketplace_api.dart';

enum DeliveryStatus { sending, sent, failed }

@immutable
class UiMessage {
  const UiMessage({
    required this.clientId,
    required this.text,
    required this.fromMe,
    required this.sentAt,
    this.status = DeliveryStatus.sent,
  });

  /// Generated on the device; reused when retrying so the server
  /// deduplicates.
  final String clientId;
  final String text;
  final bool fromMe;
  final DateTime sentAt;
  final DeliveryStatus status;

  UiMessage withStatus(DeliveryStatus status) =>
      UiMessage(clientId: clientId, text: text, fromMe: fromMe, sentAt: sentAt, status: status);
}

@immutable
class ChatState {
  const ChatState({this.messages = const [], this.sellerTyping = false, this.loading = true});

  final List<UiMessage> messages;
  final bool sellerTyping;
  final bool loading;

  ChatState copyWith({List<UiMessage>? messages, bool? sellerTyping, bool? loading}) => ChatState(
    messages: messages ?? this.messages,
    sellerTyping: sellerTyping ?? this.sellerTyping,
    loading: loading ?? this.loading,
  );
}

/// One conversation with a seller, keyed by listing id.
///
/// Messages appear immediately with a "sending" state (optimistic UI). A
/// failed message can be retried with the same client id, so the server
/// never stores it twice.
class ChatController extends Notifier<ChatState> {
  ChatController(this.listingId);

  final int listingId;
  int _localIds = 0;

  String get conversationId => 'listing-$listingId';
  ChatGateway get _gateway => ref.read(chatGatewayProvider);

  @override
  ChatState build() {
    final subscription = _gateway.events.where((e) => e.conversationId == conversationId).listen(_onEvent);
    ref.onDispose(subscription.cancel);
    Future.microtask(_loadHistory);
    return const ChatState();
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final message = UiMessage(
      clientId: '$conversationId-${DateTime.now().microsecondsSinceEpoch}-${_localIds++}',
      text: trimmed,
      fromMe: true,
      sentAt: ref.read(clockProvider)(),
      status: DeliveryStatus.sending,
    );
    state = state.copyWith(messages: [...state.messages, message]);
    await _deliver(message);
  }

  Future<void> retry(String clientId) async {
    final message = state.messages.where((m) => m.clientId == clientId).firstOrNull;
    if (message == null || message.status != DeliveryStatus.failed) return;
    _replace(message.withStatus(DeliveryStatus.sending));
    await _deliver(message);
  }

  Future<void> _deliver(UiMessage message) async {
    try {
      await _gateway.send(conversationId: conversationId, clientId: message.clientId, text: message.text);
      if (ref.mounted) _replace(message.withStatus(DeliveryStatus.sent));
    } on ApiException {
      if (ref.mounted) _replace(message.withStatus(DeliveryStatus.failed));
    }
  }

  Future<void> _loadHistory() async {
    final history = await _gateway.history(conversationId);
    if (!ref.mounted) return;
    final known = state.messages;
    state = state.copyWith(
      loading: false,
      messages: [
        for (final m in history) UiMessage(clientId: m.id, text: m.text, fromMe: m.fromMe, sentAt: m.sentAt),
        ...known,
      ],
    );
  }

  void _onEvent(ChatEvent event) {
    switch (event) {
      case TypingChanged(:final isTyping):
        state = state.copyWith(sellerTyping: isTyping);
      case MessageReceived(:final message) when !message.fromMe:
        state = state.copyWith(
          messages: [
            ...state.messages,
            UiMessage(clientId: message.id, text: message.text, fromMe: false, sentAt: message.sentAt),
          ],
        );
      case MessageReceived():
        break;
    }
  }

  void _replace(UiMessage message) {
    state = state.copyWith(messages: [for (final m in state.messages) m.clientId == message.clientId ? message : m]);
  }
}

final NotifierProviderFamily<ChatController, ChatState, int> chatProvider =
    NotifierProvider.family<ChatController, ChatState, int>(ChatController.new);

/// Listings the user has started a conversation about, newest first.
class ConversationsController extends Notifier<List<Listing>> {
  @override
  List<Listing> build() => const [];

  void open(Listing listing) => state = [listing, ...state.where((l) => l.id != listing.id)];
}

final conversationsProvider = NotifierProvider<ConversationsController, List<Listing>>(ConversationsController.new);
