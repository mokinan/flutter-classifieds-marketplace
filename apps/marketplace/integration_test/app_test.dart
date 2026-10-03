import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:marketplace/features/post_ad/photo_services.dart';
import 'package:marketplace/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';

/// Supplies real product photos instead of opening the system picker.
class _DownloadedPhotos implements PhotoSource {
  static const _urls = [
    'https://cdn.dummyjson.com/product-images/vehicle/300-touring/1.webp',
    'https://cdn.dummyjson.com/product-images/vehicle/300-touring/2.webp',
  ];

  @override
  Future<List<Uint8List>> pick({required int max}) async {
    final dio = Dio();
    return [
      for (final url in _urls.take(max))
        Uint8List.fromList((await dio.get<List<int>>(url, options: Options(responseType: ResponseType.bytes))).data!),
    ];
  }
}

/// End-to-end against the live demo API: browse, search, open a listing,
/// save it, chat with the seller, and post an ad with photo uploads.
///
/// `flutter drive --driver=test_driver/integration_test.dart
/// --target=integration_test/app_test.dart` also saves screenshots.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(WidgetTester tester, String name) async {
    FocusManager.instance.primaryFocus?.unfocus();
    for (final m in tester.stateList<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))) {
      m.clearSnackBars();
    }
    // Live mode only renders on pump(): keep producing frames so images can
    // finish loading and their fade-in animations can complete.
    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    }
    await binding.takeScreenshot(name);
  }

  testWidgets('browse, chat and sell', (tester) async {
    await (await SharedPreferences.getInstance()).clear();
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();

    await app.main(overrides: [photoSourceProvider.overrideWithValue(_DownloadedPhotos())]);
    await tester.pumpUntil(find.textContaining('results'));
    await shot(tester, 'feed');

    // Category filter.
    await tester.pumpUntil(find.text('Cars'));
    await tester.tap(find.text('Cars'));
    await tester.pumpUntil(find.textContaining('300 Touring'));
    await shot(tester, 'category');

    // Details, save, chat.
    await tester.tap(find.textContaining('300 Touring').first);
    await tester.pumpUntil(find.text('Chat with seller'));
    await tester.tap(find.byTooltip('Save'));
    await tester.pump(const Duration(milliseconds: 500));
    await shot(tester, 'details');

    await tester.tap(find.text('Chat with seller'));
    await tester.pumpUntil(find.byKey(const Key('message')));
    await tester.enterText(find.byKey(const Key('message')), 'Hi, is it still available?');
    await tester.tap(find.byKey(const Key('send')));
    await tester.pumpUntil(find.textContaining('still available.'), timeout: const Duration(seconds: 10));
    await tester.enterText(find.byKey(const Key('message')), 'Great, can I see it tomorrow?');
    await tester.tap(find.byKey(const Key('send')));
    await tester.pumpUntil(find.text('typing…'), timeout: const Duration(seconds: 10));
    await shot(tester, 'chat');
    await tester.pageBack();
    await tester.pumpUntil(find.text('Chat with seller'));
    await tester.pageBack();
    await tester.pumpUntil(find.text('Cars'));

    // Search.
    await tester.tap(find.text('All').first);
    await tester.enterText(find.byKey(const Key('search')), 'iphone');
    await tester.pumpUntil(find.textContaining('iPhone'));
    await shot(tester, 'search');

    // Post an ad.
    await tester.tap(find.text('Sell'));
    await tester.pumpUntil(find.byKey(const Key('add-photos')));
    await tester.tap(find.byKey(const Key('add-photos')));
    await tester.pumpUntil(find.byType(CircularProgressIndicator));
    await shot(tester, 'sell_uploading');
    await tester.pumpUntilGone(find.byType(CircularProgressIndicator));
    await tester.tap(find.byKey(const Key('next')));
    await tester.pumpUntil(find.byKey(const Key('title')));
    await tester.enterText(find.byKey(const Key('title')), 'Chrysler 300 Touring 2019');
    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cars').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('description')),
      'Single owner, full agency service history, no accidents. Recently replaced tyres.',
    );
    await tester.tap(find.byKey(const Key('next')));
    await tester.pumpUntil(find.byKey(const Key('price')));
    await tester.enterText(find.byKey(const Key('price')), '68500');
    await tester.tap(find.text('City'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jeddah').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('next')));
    await tester.pumpUntil(find.text('Publish'));
    await shot(tester, 'sell_review');
    await tester.tap(find.text('Publish'));
    await tester.pumpUntil(find.text('Your ad is live!'));

    // Saved works from local snapshots.
    await tester.tap(find.text('Saved'));
    await tester.pumpUntil(find.textContaining('300 Touring'));
    await shot(tester, 'saved');

    // Arabic.
    await tester.tap(find.text('Browse'));
    await tester.pumpUntil(find.text('العربية'));
    await tester.enterText(find.byKey(const Key('search')), '');
    await tester.pumpUntil(find.textContaining('Durango'));
    await tester.tap(find.text('العربية'));
    await tester.pumpUntil(find.text('تصفح'));
    await tester.pumpUntil(find.text('سيارات'));
    await shot(tester, 'feed_arabic');
  });
}

extension on WidgetTester {
  Future<void> pumpUntil(Finder finder, {Duration timeout = const Duration(seconds: 20)}) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await pump(const Duration(milliseconds: 100));
      if (any(finder)) return;
    }
    throw TestFailure('Timed out waiting for $finder');
  }

  Future<void> pumpUntilGone(Finder finder, {Duration timeout = const Duration(seconds: 20)}) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await pump(const Duration(milliseconds: 100));
      if (!any(finder)) return;
    }
    throw TestFailure('Still showing $finder');
  }
}
