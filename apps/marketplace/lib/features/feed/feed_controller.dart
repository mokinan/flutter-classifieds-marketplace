import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace/core/providers.dart';
import 'package:marketplace_api/marketplace_api.dart';

enum FeedStatus { loading, ready, error }

@immutable
class FeedState {
  const FeedState({
    this.query = const ListingQuery(),
    this.status = FeedStatus.loading,
    this.items = const [],
    this.total = 0,
    this.loadingMore = false,
    this.cachedAt,
    this.error,
  });

  final ListingQuery query;
  final FeedStatus status;
  final List<Listing> items;
  final int total;
  final bool loadingMore;

  /// Set when [items] come from the offline cache rather than the network.
  final DateTime? cachedAt;
  final ApiException? error;

  bool get hasMore => items.length < total && cachedAt == null;
  bool get isOffline => cachedAt != null;

  FeedState copyWith({
    ListingQuery? query,
    FeedStatus? status,
    List<Listing>? items,
    int? total,
    bool? loadingMore,
    DateTime? Function()? cachedAt,
    ApiException? Function()? error,
  }) => FeedState(
    query: query ?? this.query,
    status: status ?? this.status,
    items: items ?? this.items,
    total: total ?? this.total,
    loadingMore: loadingMore ?? this.loadingMore,
    cachedAt: cachedAt != null ? cachedAt() : this.cachedAt,
    error: error != null ? error() : this.error,
  );
}

/// The listing feed: search, category, sort and infinite scroll.
///
/// * A new query cancels the request of the previous one, so a slow,
///   stale response can never overwrite newer results.
/// * Typing is debounced before any request is made.
/// * The first page of each query is cached; when the network fails, the
///   cached page is shown with an offline banner.
class FeedController extends Notifier<FeedState> {
  FeedController({this.debounce = const Duration(milliseconds: 350), this.pageSize = 20});

  final Duration debounce;
  final int pageSize;

  CancelToken? _inFlight;
  Timer? _debounceTimer;

  MarketplaceApi get _api => ref.read(marketplaceApiProvider);

  @override
  FeedState build() {
    ref.onDispose(() {
      _debounceTimer?.cancel();
      _inFlight?.cancel();
    });
    Future.microtask(() => _load(const ListingQuery()));
    return const FeedState();
  }

  void search(String text) {
    _debounceTimer?.cancel();
    if (text.trim() == state.query.search.trim()) return;
    _debounceTimer = Timer(debounce, () => _load(state.query.withSearch(text)));
  }

  Future<void> selectCategory(String? slug) => _load(state.query.withCategory(slug));

  Future<void> sortBy(ListingSort sort) => _load(state.query.withSort(sort));

  Future<void> refresh() => _load(state.query, keepItems: true);

  Future<void> loadMore() async {
    if (!state.hasMore || state.loadingMore || state.status != FeedStatus.ready) return;
    final query = state.query;
    final token = _inFlight = CancelToken();
    state = state.copyWith(loadingMore: true);
    try {
      final page = await _api.listings(query, offset: state.items.length, limit: pageSize, cancelToken: token);
      if (!ref.mounted || query != state.query) return;
      state = state.copyWith(items: [...state.items, ...page.items], total: page.total, loadingMore: false);
    } on RequestCancelled {
      return;
    } on ApiException catch (e) {
      if (ref.mounted) state = state.copyWith(loadingMore: false, error: () => e);
    }
  }

  Future<void> _load(ListingQuery query, {bool keepItems = false}) async {
    _inFlight?.cancel();
    final token = _inFlight = CancelToken();
    state = state.copyWith(
      query: query,
      status: keepItems ? state.status : FeedStatus.loading,
      items: keepItems ? state.items : const [],
      error: () => null,
    );

    try {
      final page = await _api.listings(query, limit: pageSize, cancelToken: token);
      if (!ref.mounted) return;
      state = state.copyWith(status: FeedStatus.ready, items: page.items, total: page.total, cachedAt: () => null);
      unawaited(ref.read(feedCacheProvider).write(query, page));
    } on RequestCancelled {
      // Superseded by a newer query.
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      final cached = e is NetworkUnavailable ? await ref.read(feedCacheProvider).read(query) : null;
      if (!ref.mounted || query != state.query) return;
      if (cached != null) {
        state = state.copyWith(
          status: FeedStatus.ready,
          items: cached.page.items,
          total: cached.page.total,
          cachedAt: () => cached.savedAt,
          error: () => e,
        );
      } else if (keepItems && state.items.isNotEmpty) {
        state = state.copyWith(error: () => e);
      } else {
        state = state.copyWith(status: FeedStatus.error, error: () => e);
      }
    }
  }
}

final feedControllerProvider = NotifierProvider<FeedController, FeedState>(FeedController.new);
