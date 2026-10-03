import 'dart:math';

import 'package:marketplace_api/marketplace_api.dart';
import 'package:test/test.dart';

void main() {
  late SimulatedChatGateway gateway;

  setUp(() {
    gateway = SimulatedChatGateway(ackDelay: Duration.zero, replyDelay: const Duration(milliseconds: 20));
  });

  tearDown(() => gateway.close());

  test('acknowledges, shows typing, then replies', () async {
    final events = <ChatEvent>[];
    final sub = gateway.events.listen(events.add);

    final sent = await gateway.send(conversationId: 'c1', clientId: 'local-1', text: 'Is it available?');
    expect(sent.fromMe, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(events.whereType<TypingChanged>().map((e) => e.isTyping), [true, false]);
    final reply = events.whereType<MessageReceived>().single.message;
    expect(reply.fromMe, isFalse);
    expect((await gateway.history('c1')).map((m) => m.fromMe), [true, false]);
    await sub.cancel();
  });

  test('retrying the same client id does not duplicate the message', () async {
    final first = await gateway.send(conversationId: 'c1', clientId: 'local-1', text: 'Hi');
    final retry = await gateway.send(conversationId: 'c1', clientId: 'local-1', text: 'Hi');
    expect(retry.id, first.id);
    expect((await gateway.history('c1')).where((m) => m.fromMe), hasLength(1));
  });

  test('can fail to deliver', () async {
    gateway = SimulatedChatGateway(ackDelay: Duration.zero, failureRate: 1, random: Random(1));
    await expectLater(
      gateway.send(conversationId: 'c1', clientId: 'x', text: 'Hi'),
      throwsA(isA<NetworkUnavailable>()),
    );
  });
}
