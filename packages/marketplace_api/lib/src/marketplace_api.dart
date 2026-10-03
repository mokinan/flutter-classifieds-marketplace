import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:marketplace_api/src/api_exception.dart';
import 'package:marketplace_api/src/models.dart';

/// Typed access to listings, categories and uploads.
class MarketplaceApi {
  MarketplaceApi(this._dio, {ImageUploader? uploader}) : _uploader = uploader ?? SimulatedImageUploader();

  /// Categories that make sense for a classifieds site, in display order —
  /// the highest-traffic categories first.
  static const classifiedCategories = [
    'vehicle',
    'motorcycle',
    'smartphones',
    'laptops',
    'tablets',
    'mobile-accessories',
    'furniture',
    'home-decoration',
    'kitchen-accessories',
    'mens-watches',
    'sports-accessories',
  ];

  static const _fields = 'id,title,description,price,category,brand,thumbnail,images,meta';

  final Dio _dio;
  final ImageUploader _uploader;

  Future<List<Category>> categories() => _guard(() async {
    final response = await _dio.get<List<Object?>>('/products/categories');
    return response.data!
        .cast<Map<String, Object?>>()
        .map(Category.fromJson)
        .where((c) => classifiedCategories.contains(c.slug))
        .toList()
      ..sort((a, b) => classifiedCategories.indexOf(a.slug).compareTo(classifiedCategories.indexOf(b.slug)));
  });

  /// Fetches one page. Pass a [cancelToken] so a newer query can abort an
  /// older one that is still in flight.
  Future<ListingPage> listings(ListingQuery query, {int offset = 0, int limit = 20, CancelToken? cancelToken}) =>
      _guard(() async {
        final path = query.isSearch
            ? '/products/search'
            : query.category != null
            ? '/products/category/${query.category}'
            : '/products';
        final response = await _dio.get<Map<String, Object?>>(
          path,
          cancelToken: cancelToken,
          queryParameters: {
            if (query.isSearch) 'q': query.search.trim(),
            'limit': limit,
            'skip': offset,
            'select': _fields,
            ...switch (query.sort) {
              // The demo backend has no ranking. For the unfiltered home feed,
              // high-value items (cars, watches, bikes, laptops) stand in for
              // "featured"; elsewhere the backend's own order is used.
              ListingSort.relevance when !query.isSearch && query.category == null => const {
                'sortBy': 'price',
                'order': 'desc',
              },
              ListingSort.relevance => const <String, String>{},
              ListingSort.priceLowToHigh => const {'sortBy': 'price', 'order': 'asc'},
              ListingSort.priceHighToLow => const {'sortBy': 'price', 'order': 'desc'},
              ListingSort.newest => const {'sortBy': 'id', 'order': 'desc'},
            },
          },
        );
        final body = response.data!;
        return ListingPage(
          items: (body['products']! as List<Object?>).cast<Map<String, Object?>>().map(Listing.fromJson).toList(),
          total: body['total']! as int,
          offset: offset,
        );
      });

  Future<Listing> listing(int id) => _guard(() async {
    final response = await _dio.get<Map<String, Object?>>('/products/$id', queryParameters: {'select': _fields});
    return Listing.fromJson(response.data!);
  });

  /// Uploads one compressed image, reporting progress from 0 to 1.
  Future<String> uploadImage(List<int> bytes, {void Function(double progress)? onProgress}) =>
      _uploader.upload(bytes, onProgress: onProgress);

  Future<Listing> publish(ListingDraft draft) => _guard(() async {
    final response = await _dio.post<Map<String, Object?>>(
      '/products/add',
      data: {
        'title': draft.title,
        'description': draft.description,
        'price': draft.priceHalalas / 375,
        'category': draft.category,
        'images': draft.imageIds,
      },
    );
    final body = response.data!;
    return Listing(
      id: body['id']! as int,
      title: draft.title,
      description: draft.description,
      priceHalalas: draft.priceHalalas,
      category: draft.category,
      city: draft.city,
      sellerName: 'You',
      thumbnailUrl: draft.imageIds.firstOrNull ?? '',
      imageUrls: draft.imageIds,
      postedAt: DateTime.now(),
    );
  });

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

/// Storage for listing photos. An interface (not a typedef) so the real media
/// service and the simulator can carry their own configuration.
abstract interface class ImageUploader {
  Future<String> upload(List<int> bytes, {void Function(double progress)? onProgress});
}

/// Stands in for a media service: reports chunked progress and fails a
/// configurable share of uploads so retry handling can be exercised.
class SimulatedImageUploader implements ImageUploader {
  SimulatedImageUploader({this.failureRate = 0, this.chunkDelay = const Duration(milliseconds: 60), Random? random})
    : _random = random ?? Random();

  double failureRate;
  final Duration chunkDelay;
  final Random _random;
  int _counter = 0;

  @override
  Future<String> upload(List<int> bytes, {void Function(double progress)? onProgress}) async {
    const chunks = 10;
    final fails = _random.nextDouble() < failureRate;
    for (var i = 1; i <= chunks; i++) {
      await Future<void>.delayed(chunkDelay);
      if (fails && i == 6) throw const NetworkUnavailable('Upload interrupted');
      onProgress?.call(i / chunks);
    }
    return 'upload-${++_counter}-${bytes.length}';
  }
}
