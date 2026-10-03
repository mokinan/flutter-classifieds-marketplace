import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:marketplace/app/app.dart';
import 'package:marketplace/core/feed_cache.dart';
import 'package:marketplace/core/providers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main({List<Override> overrides = const []}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final cacheDir = Directory('${(await getApplicationCacheDirectory()).path}/feed');

  runApp(
    ProviderScope(
      // Failures are handled explicitly in controllers; automatic retries
      // would hide them and double network traffic.
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        feedCacheProvider.overrideWithValue(FeedCache(cacheDir)),
        ...overrides,
      ],
      child: const MarketplaceApp(),
    ),
  );
}
