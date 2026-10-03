import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:marketplace_api/marketplace_api.dart';
import 'package:test/test.dart';

/// Records requests and answers from a handler.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.respond);

  final FutureOr<(int, Object?)> Function(RequestOptions) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? body, Future<void>? cancelFuture) async {
    requests.add(options);
    final (status, data) = await respond(options);
    return ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> product(int id, {num price = 100, String category = 'smartphones'}) => {
  'id': id,
  'title': 'Item $id',
  'description': 'desc',
  'price': price,
  'category': category,
  'brand': 'Brand',
  'thumbnail': 'https://img/$id.webp',
  'images': ['https://img/$id-1.webp'],
  'meta': {'createdAt': '2026-08-26T17:22:47.153Z'},
};

void main() {
  late FakeAdapter adapter;
  late MarketplaceApi api;

  MarketplaceApi build(FutureOr<(int, Object?)> Function(RequestOptions) respond) {
    adapter = FakeAdapter(respond);
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = adapter;
    return MarketplaceApi(dio, uploader: SimulatedImageUploader(chunkDelay: Duration.zero));
  }

  group('listings', () {
    test('maps products to listings with integer prices', () async {
      api = build(
        (_) => (
          200,
          {
            'products': [product(1, price: 9.99)],
            'total': 30,
          },
        ),
      );
      final page = await api.listings(const ListingQuery());

      final listing = page.items.single;
      expect(listing.priceHalalas, 3700, reason: '9.99 USD × 3.75 = 37.46 SAR → 37 SAR');
      expect(listing.city, Listing.demoCities[1]);
      expect(listing.postedAt, DateTime.utc(2026, 8, 26, 17, 22, 47, 153));
      expect(page.hasMore, isTrue);
      expect(page.nextOffset, 1);
    });

    test('builds the right request for search, category and sort', () async {
      api = build((_) => (200, {'products': <Object?>[], 'total': 0}));

      await api.listings(const ListingQuery(search: ' iphone ', sort: ListingSort.priceLowToHigh), offset: 40);
      await api.listings(const ListingQuery(category: 'vehicle', sort: ListingSort.newest));

      final search = adapter.requests[0];
      expect(search.path, '/products/search');
      expect(search.queryParameters, containsPair('q', 'iphone'));
      expect(search.queryParameters, containsPair('skip', 40));
      expect(search.queryParameters, containsPair('sortBy', 'price'));
      expect(search.queryParameters, containsPair('order', 'asc'));

      await api.listings(const ListingQuery());
      expect(adapter.requests[2].queryParameters, containsPair('sortBy', 'price'), reason: 'featured home feed');

      final category = adapter.requests[1];
      expect(category.path, '/products/category/vehicle');
      expect(category.queryParameters, containsPair('order', 'desc'));
    });

    test('a cancelled request surfaces as RequestCancelled', () async {
      final gate = Completer<(int, Object?)>();
      api = build((_) => gate.future);
      final token = CancelToken();
      final future = api.listings(const ListingQuery(), cancelToken: token);
      token.cancel();
      await expectLater(future, throwsA(isA<RequestCancelled>()));
    });
  });

  test('categories are filtered to classifieds and ordered by priority', () async {
    api = build(
      (_) => (
        200,
        [
          {'slug': 'furniture', 'name': 'Furniture'},
          {'slug': 'beauty', 'name': 'Beauty'},
          {'slug': 'vehicle', 'name': 'Vehicle'},
        ],
      ),
    );
    expect((await api.categories()).map((c) => c.slug), ['vehicle', 'furniture']);
  });

  group('errors', () {
    test('maps HTTP failures to typed exceptions', () async {
      api = build((_) => (404, {'message': 'nope'}));
      await expectLater(api.listing(9), throwsA(isA<NotFound>()));

      api = build((_) => (503, null));
      await expectLater(api.listing(9), throwsA(isA<ServerError>()));

      api = build((_) => (400, {'message': 'bad'}));
      await expectLater(api.listing(9), throwsA(isA<BadRequest>()));
    });

    test('maps connection errors to NetworkUnavailable', () async {
      api = build((o) => throw DioException.connectionError(requestOptions: o, reason: 'offline'));
      await expectLater(api.categories(), throwsA(isA<NetworkUnavailable>()));
    });
  });

  test('publish posts the draft and returns a listing', () async {
    api = build((o) => (201, {'id': 195, ...(o.data as Map<String, Object?>)}));
    final listing = await api.publish(
      const ListingDraft(
        title: 'Bike',
        description: 'Good',
        priceHalalas: 75000,
        category: 'sports-accessories',
        city: 'Riyadh',
        imageIds: ['upload-1'],
      ),
    );
    expect(listing.id, 195);
    expect(listing.priceHalalas, 75000);
    expect((adapter.requests.single.data as Map)['price'], 200);
  });

  group('SimulatedImageUploader', () {
    test('reports progress to completion', () async {
      final progress = <double>[];
      final id = await SimulatedImageUploader(chunkDelay: Duration.zero).upload([1, 2, 3], onProgress: progress.add);
      expect(progress.last, 1.0);
      expect(progress, orderedEquals([...progress]..sort()));
      expect(id, endsWith('-3'));
    });

    test('can fail mid-upload', () async {
      final uploader = SimulatedImageUploader(failureRate: 1, chunkDelay: Duration.zero);
      await expectLater(uploader.upload([1]), throwsA(isA<NetworkUnavailable>()));
    });
  });

  group('ListingQuery', () {
    test('search and category are mutually exclusive', () {
      const q = ListingQuery(category: 'vehicle', sort: ListingSort.newest);
      final searched = q.withSearch('bmw');
      expect(searched.category, isNull);
      expect(searched.sort, ListingSort.newest);
      expect(searched.withCategory('laptops').search, isEmpty);
      expect(q.cacheKey, isNot(searched.cacheKey));
    });
  });
}
