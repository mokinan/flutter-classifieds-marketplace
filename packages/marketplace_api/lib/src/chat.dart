import 'dart:async';
import 'dart:math';

import 'package:marketplace_api/src/api_exception.dart';
import 'package:meta/meta.dart';

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.text,
    required this.fromMe,
    required this.sentAt,
  });

  /// Server-assigned id, or the client id for messages not yet acknowledged.
  final String id;
  final String conversationId;
  final String text;
  final bool fromMe;
  final DateTime sentAt;
}

/// Something pushed by the server over the realtime connection.
sealed class ChatEvent {
  const ChatEvent(this.conversationId);
  final String conversationId;
}

final class MessageReceived extends ChatEvent {
  MessageReceived(this.message) : super(message.conversationId);
  final ChatMessage message;
}

final class TypingChanged extends ChatEvent {
  const TypingChanged(super.conversationId, {required this.isTyping});
  final bool isTyping;
}

/// Realtime chat transport (a WebSocket in production).
abstract interface class ChatGateway {
  Stream<ChatEvent> get events;

  /// Sends a message; [clientId] makes retries idempotent.
  Future<ChatMessage> send({required String conversationId, required String clientId, required String text});

  Future<List<ChatMessage>> history(String conversationId);
}

/// In-process chat server: acknowledges messages after a delay, shows the
/// seller typing, then replies. Failure injection exercises retry UI.
class SimulatedChatGateway implements ChatGateway {
  SimulatedChatGateway({
    this.ackDelay = const Duration(milliseconds: 400),
    this.replyDelay = const Duration(seconds: 2),
    this.failureRate = 0,
    DateTime Function()? clock,
    Random? random,
  }) : _clock = clock ?? DateTime.now,
       _random = random ?? Random();

  final Duration ackDelay;
  final Duration replyDelay;
  double failureRate;
  final DateTime Function() _clock;
  final Random _random;

  final _events = StreamController<ChatEvent>.broadcast();
  final _messages = <String, List<ChatMessage>>{};
  final _acknowledged = <String, ChatMessage>{};
  int _serverIds = 0;

  static const _replies = [
    'Hi! Yes, it is still available.',
    'Price is slightly negotiable for a quick sale.',
    'You can see it this evening if that works.',
    'It is in excellent condition, barely used.',
  ];

  @override
  Stream<ChatEvent> get events => _events.stream;

  @override
  Future<List<ChatMessage>> history(String conversationId) async {
    await Future<void>.delayed(ackDelay);
    return List.unmodifiable(_messages[conversationId] ?? const <ChatMessage>[]);
  }

  @override
  Future<ChatMessage> send({required String conversationId, required String clientId, required String text}) async {
    await Future<void>.delayed(ackDelay);
    // A retry of a message the server already stored returns the original.
    final existing = _acknowledged[clientId];
    if (existing != null) return existing;
    if (_random.nextDouble() < failureRate) throw const NetworkUnavailable('Message not sent');

    final message = ChatMessage(
      id: 'srv-${++_serverIds}',
      conversationId: conversationId,
      text: text,
      fromMe: true,
      sentAt: _clock(),
    );
    _acknowledged[clientId] = message;
    (_messages[conversationId] ??= []).add(message);
    unawaited(_replyLater(conversationId));
    return message;
  }

  Future<void> _replyLater(String conversationId) async {
    await Future<void>.delayed(replyDelay ~/ 2);
    if (_events.isClosed) return;
    _events.add(TypingChanged(conversationId, isTyping: true));
    await Future<void>.delayed(replyDelay ~/ 2);
    if (_events.isClosed) return;
    final sellerReplies = (_messages[conversationId] ?? const <ChatMessage>[]).where((m) => !m.fromMe).length;
    final reply = ChatMessage(
      id: 'srv-${++_serverIds}',
      conversationId: conversationId,
      text: _replies[sellerReplies % _replies.length],
      fromMe: false,
      sentAt: _clock(),
    );
    (_messages[conversationId] ??= []).add(reply);
    _events
      ..add(TypingChanged(conversationId, isTyping: false))
      ..add(MessageReceived(reply));
  }

  Future<void> close() => _events.close();
}
