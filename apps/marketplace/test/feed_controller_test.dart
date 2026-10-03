import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace/core/providers.dart';
import 'package:marketplace/features/feed/feed_controller.dart';
import 'package:marketplace_api/marketplace_api.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers.dart';

void main() {
  late MockApi api;

  setUpAll(registerFallbacks);
  setUp(() => api = MockApi());

  test('loads the first page, then appends pages until the end', () async {
    whenListings(api).thenAnswer((i) async {
      final offset = i.namedArguments[#offset] as int;
      return offset == 0 ? page([1, 2], total: 3) : page([3], total: 3, offset: offset);
    });
    final container = await makeContainer(api: api);

    container.read(feedControllerProvider);
    await settle();
    expect(container.read(feedControllerProvider).items.map((l) => l.id), [1, 2]);

    await container.read(feedControllerProvider.notifier).loadMore();
    final state = container.read(feedControllerProvider);
    expect(state.items.map((l) => l.id), [1, 2, 3]);
    expect(state.hasMore, isFalse);

    await container.read(feedControllerProvider.notifier).loadMore();
    verify(
      () => api.listings(
        any(),
        offset: any(named: 'offset'),
        limit: any(named: 'limit'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).called(2);
  });

  test('debounces typing so only the final search is requested', () async {
    final queries = <String>[];
    whenListings(api).thenAnswer((i) async {
      queries.add((i.positionalArguments.first as ListingQuery).search);
      return page([1], total: 1);
    });
    final container = await makeContainer(api: api);
    container.read(feedControllerProvider);
    await settle();

    final controller = container.read(feedControllerProvider.notifier);
    for (final text in ['i', 'ip', 'iph', 'iphone']) {
      controller.search(text);
      await settle(const Duration(milliseconds: 50));
    }
    await settle(const Duration(milliseconds: 400));

    expect(queries, ['', 'iphone']);
  });

  test('a newer query cancels the older request and its result is ignored', () async {
    final slow = Completer<ListingPage>();
    CancelToken? firstToken;
    whenListings(api).thenAnswer((i) {
      final query = i.positionalArguments.first as ListingQuery;
      if (query.category == 'vehicle') {
        firstToken = i.namedArguments[#cancelToken] as CancelToken;
        return slow.future;
      }
      return Future.value(page([42], total: 1));
    });
    final container = await makeContainer(api: api);
    container.read(feedControllerProvider);
    await settle();

    final controller = container.read(feedControllerProvider.notifier);
    unawaited(controller.selectCategory('vehicle'));
    await settle();
    await controller.selectCategory('laptops');

    expect(firstToken!.isCancelled, isTrue);
    slow.completeError(const RequestCancelled());
    await settle();
    final state = container.read(feedControllerProvider);
    expect(state.query.category, 'laptops');
    expect(state.items.single.id, 42);
  });

  test('falls back to the cached first page when offline', () async {
    final container = await makeContainer(api: api);
    await container.read(feedCacheProvider).write(const ListingQuery(), page([7, 8], total: 50));
    whenListings(api).thenThrow(const NetworkUnavailable('offline'));

    container.read(feedControllerProvider);
    await settle();

    final state = container.read(feedControllerProvider);
    expect(state.status, FeedStatus.ready);
    expect(state.isOffline, isTrue);
    expect(state.items.map((l) => l.id), [7, 8]);
    expect(state.hasMore, isFalse, reason: 'no paging on stale data');
  });

  test('shows an error when offline without a cache', () async {
    whenListings(api).thenThrow(const NetworkUnavailable('offline'));
    final container = await makeContainer(api: api);
    container.read(feedControllerProvider);
    await settle();

    final state = container.read(feedControllerProvider);
    expect(state.status, FeedStatus.error);
    expect(state.error, isA<NetworkUnavailable>());
  });

  test('a failed refresh keeps the items already on screen', () async {
    whenListings(api).thenAnswer((_) async => page([1, 2], total: 2));
    final container = await makeContainer(api: api);
    container.read(feedControllerProvider);
    await settle();

    whenListings(api).thenThrow(ServerError(503));
    await container.read(feedControllerProvider.notifier).refresh();

    final state = container.read(feedControllerProvider);
    expect(state.items, hasLength(2));
    expect(state.error, isA<ServerError>());
    expect(state.status, FeedStatus.ready);
  });
}
