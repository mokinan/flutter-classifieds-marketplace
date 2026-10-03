import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace/core/providers.dart';
import 'package:marketplace/features/chat/chat_controller.dart';
import 'package:marketplace_api/marketplace_api.dart';

import 'helpers.dart';

void main() {
  late SimulatedChatGateway gateway;

  setUp(() {
    gateway = SimulatedChatGateway(
      ackDelay: const Duration(milliseconds: 10),
      replyDelay: const Duration(milliseconds: 40),
    );
  });

  tearDown(() => gateway.close());

  Future<ChatController> open() async {
    final container = await makeContainer(api: MockApi(), overrides: [chatGatewayProvider.overrideWithValue(gateway)]);
    container.listen(chatProvider(1), (_, _) {});
    await settle();
    return container.read(chatProvider(1).notifier);
  }

  test('shows a message immediately, then marks it sent', () async {
    final chat = await open();
    final sending = chat.send('Is it available?');

    expect(chat.state.messages.single.status, DeliveryStatus.sending);
    await sending;
    expect(chat.state.messages.single.status, DeliveryStatus.sent);
  });

  test('receives the typing indicator and the reply', () async {
    final chat = await open();
    await chat.send('Hello');

    await settle(const Duration(milliseconds: 25));
    expect(chat.state.sellerTyping, isTrue);
    await settle(const Duration(milliseconds: 40));
    expect(chat.state.sellerTyping, isFalse);
    expect(chat.state.messages.map((m) => m.fromMe), [true, false]);
  });

  test('a failed message can be retried without duplicating it', () async {
    final chat = await open();
    gateway.failureRate = 1;
    await chat.send('Last price?');
    final failed = chat.state.messages.single;
    expect(failed.status, DeliveryStatus.failed);

    gateway.failureRate = 0;
    await chat.retry(failed.clientId);
    await chat.retry(failed.clientId); // already sent: ignored

    expect(chat.state.messages.single.status, DeliveryStatus.sent);
    expect((await gateway.history('listing-1')).where((m) => m.fromMe), hasLength(1));
  });

  test('ignores blank messages', () async {
    final chat = await open();
    await chat.send('   ');
    expect(chat.state.messages, isEmpty);
  });
}
