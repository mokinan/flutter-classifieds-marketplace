import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace/core/feed_cache.dart';
import 'package:marketplace/features/favorites/favorites_controller.dart';
import 'package:marketplace_api/marketplace_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  group('FavoritesController', () {
    test('saves optimistically and persists', () async {
      final container = await makeContainer(
        api: MockApi(),
        overrides: [favoritesApiProvider.overrideWithValue(FavoritesApi(latency: const Duration(milliseconds: 30)))],
      );
      final controller = container.read(favoritesProvider.notifier);

      final pending = controller.toggle(listing(1));
      expect(container.read(favoritesProvider).keys, [1], reason: 'visible before the server answers');
      expect(await pending, isTrue);

      final stored = (await SharedPreferences.getInstance()).getString('favorites_v1');
      expect(stored, contains('Listing 1'));
    });

    test('rolls back when the server fails', () async {
      final container = await makeContainer(
        api: MockApi(),
        overrides: [favoritesApiProvider.overrideWithValue(FavoritesApi(latency: Duration.zero, failureRate: 1))],
      );

      expect(await container.read(favoritesProvider.notifier).toggle(listing(1)), isFalse);
      expect(container.read(favoritesProvider), isEmpty);
    });

    test('restores saved listings on start', () async {
      final first = await makeContainer(
        api: MockApi(),
        overrides: [favoritesApiProvider.overrideWithValue(FavoritesApi(latency: Duration.zero))],
      );
      await first.read(favoritesProvider.notifier).toggle(listing(5));
      final saved = (await SharedPreferences.getInstance()).getString('favorites_v1')!;

      final second = await makeContainer(api: MockApi(), prefs: {'favorites_v1': saved});
      expect(second.read(favoritesProvider)[5]?.title, 'Listing 5');
    });
  });

  group('FeedCache', () {
    late Directory dir;

    setUp(() async => dir = await Directory.systemTemp.createTemp('cache_test'));
    tearDown(() => dir.delete(recursive: true));

    test('round-trips a page per query', () async {
      final cache = FeedCache(dir);
      const phones = ListingQuery(category: 'smartphones');
      await cache.write(phones, page([1, 2], total: 9), now: DateTime(2026, 10));

      final cached = await cache.read(phones);
      expect(cached!.page.items.map((l) => l.priceHalalas), [10000, 20000]);
      expect(cached.page.total, 9);
      expect(cached.savedAt, DateTime(2026, 10));
      expect(await cache.read(const ListingQuery(category: 'laptops')), isNull);
    });

    test('evicts the oldest entries', () async {
      final cache = FeedCache(dir, maxEntries: 2);
      for (final c in ['a', 'b', 'c']) {
        await cache.write(ListingQuery(category: c), page([1], total: 1));
        await Future<void>.delayed(const Duration(milliseconds: 1100));
      }
      expect(await cache.read(const ListingQuery(category: 'a')), isNull);
      expect(await cache.read(const ListingQuery(category: 'c')), isNotNull);
    });

    test('discards a corrupt entry instead of crashing', () async {
      final cache = FeedCache(dir);
      const query = ListingQuery();
      await cache.write(query, page([1], total: 1));
      final file = dir.listSync().whereType<File>().single;
      await file.writeAsString('{not json');
      expect(await cache.read(query), isNull);
    });
  });
}
