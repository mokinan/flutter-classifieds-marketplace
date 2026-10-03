import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace/core/providers.dart';
import 'package:marketplace_api/marketplace_api.dart';

/// Server-side favorites. Simulated: it adds latency and can be told to
/// fail so the optimistic rollback path is visible.
class FavoritesApi {
  FavoritesApi({this.latency = const Duration(milliseconds: 300), this.failureRate = 0, Random? random})
    : _random = random ?? Random();

  final Duration latency;
  double failureRate;
  final Random _random;

  Future<void> setFavorite(int listingId, {required bool favorite}) async {
    await Future<void>.delayed(latency);
    if (_random.nextDouble() < failureRate) throw const NetworkUnavailable('Could not save');
  }
}

final favoritesApiProvider = Provider<FavoritesApi>((ref) => FavoritesApi());

/// Saved listings, keyed by id. Snapshots are stored so the favorites tab
/// works offline.
///
/// Toggling is **optimistic**: the heart fills instantly, and if the server
/// call fails the change is rolled back and `false` is returned so the UI
/// can explain why.
class FavoritesController extends Notifier<Map<int, Listing>> {
  static const _key = 'favorites_v1';

  @override
  Map<int, Listing> build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_key);
    if (raw == null) return const {};
    final list = (jsonDecode(raw) as List<Object?>).cast<Map<String, Object?>>().map(Listing.fromJson);
    return {for (final l in list) l.id: l};
  }

  bool isFavorite(int id) => state.containsKey(id);

  Future<bool> toggle(Listing listing) async {
    final previous = state;
    final favorite = !previous.containsKey(listing.id);
    state = favorite ? {...previous, listing.id: listing} : ({...previous}..remove(listing.id));
    try {
      await ref.read(favoritesApiProvider).setFavorite(listing.id, favorite: favorite);
      await _persist();
      return true;
    } on ApiException {
      // Roll back only our own change: other toggles may have happened since.
      if (!ref.mounted) return false;
      final current = {...state};
      if (favorite) {
        current.remove(listing.id);
      } else {
        current[listing.id] = listing;
      }
      state = current;
      return false;
    }
  }

  Future<void> _persist() =>
      ref.read(sharedPreferencesProvider).setString(_key, jsonEncode([for (final l in state.values) l.toJson()]));
}

final favoritesProvider = NotifierProvider<FavoritesController, Map<int, Listing>>(FavoritesController.new);
