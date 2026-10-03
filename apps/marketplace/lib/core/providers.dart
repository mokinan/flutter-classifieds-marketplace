import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace/core/feed_cache.dart';
import 'package:marketplace/core/retry_interceptor.dart';
import 'package:marketplace_api/marketplace_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in `main` once the async instance is ready.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override sharedPreferencesProvider in ProviderScope'),
);

/// Overridden in `main` with a directory from `path_provider`.
final feedCacheProvider = Provider<FeedCache>(
  (ref) => throw UnimplementedError('Override feedCacheProvider in ProviderScope'),
);

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://dummyjson.com',
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
    ),
  );
  dio.interceptors.add(RetryInterceptor(dio));
  ref.onDispose(dio.close);
  return dio;
});

final imageUploaderProvider = Provider<SimulatedImageUploader>((ref) => SimulatedImageUploader());

final marketplaceApiProvider = Provider<MarketplaceApi>(
  (ref) => MarketplaceApi(ref.watch(dioProvider), uploader: ref.watch(imageUploaderProvider)),
);

final chatGatewayProvider = Provider<ChatGateway>((ref) {
  final gateway = SimulatedChatGateway();
  ref.onDispose(gateway.close);
  return gateway;
});

final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final categoriesProvider = FutureProvider<List<Category>>((ref) => ref.watch(marketplaceApiProvider).categories());
