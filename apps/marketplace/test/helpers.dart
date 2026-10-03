import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:marketplace/core/feed_cache.dart';
import 'package:marketplace/core/providers.dart';
import 'package:marketplace_api/marketplace_api.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockApi extends Mock implements MarketplaceApi {}

Listing listing(int id, {String? thumbnail}) => Listing(
  id: id,
  title: 'Listing $id',
  description: 'A good item in great condition',
  priceHalalas: 10000 * id,
  category: 'smartphones',
  city: 'Riyadh',
  sellerName: 'Seller $id',
  thumbnailUrl: thumbnail ?? '',
  imageUrls: const [],
  postedAt: DateTime(2026, 9),
);

ListingPage page(List<int> ids, {required int total, int offset = 0}) =>
    ListingPage(items: [for (final id in ids) listing(id)], total: total, offset: offset);

void registerFallbacks() {
  registerFallbackValue(const ListingQuery());
  registerFallbackValue(CancelToken());
  registerFallbackValue(
    const ListingDraft(title: '', description: '', priceHalalas: 0, category: '', city: '', imageIds: []),
  );
}

/// Stubs `listings` for any arguments.
When<Future<ListingPage>> whenListings(MockApi api) => when(
  () => api.listings(
    any(),
    offset: any(named: 'offset'),
    limit: any(named: 'limit'),
    cancelToken: any(named: 'cancelToken'),
  ),
);

/// A container with real SharedPreferences (in-memory) and a temp cache.
Future<ProviderContainer> makeContainer({
  required MarketplaceApi api,
  Map<String, Object> prefs = const {},
  List<Override> overrides = const [],
  Directory? cacheDir,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final preferences = await SharedPreferences.getInstance();
  final dir = cacheDir ?? await Directory.systemTemp.createTemp('feed_cache');
  return ProviderContainer.test(
    retry: (_, _) => null,
    overrides: [
      marketplaceApiProvider.overrideWithValue(api),
      sharedPreferencesProvider.overrideWithValue(preferences),
      feedCacheProvider.overrideWithValue(FeedCache(dir)),
      ...overrides,
    ],
  );
}

/// Lets microtasks, timers of zero duration and short delays run.
Future<void> settle([Duration duration = const Duration(milliseconds: 20)]) => Future<void>.delayed(duration);
