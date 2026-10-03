import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace/core/providers.dart';
import 'package:marketplace/features/feed/feed_page.dart';
import 'package:marketplace/l10n/l10n.dart';
import 'package:marketplace_api/marketplace_api.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers.dart';

void main() {
  late MockApi api;

  setUpAll(registerFallbacks);
  setUp(() => api = MockApi());

  Future<ProviderContainer> pump(WidgetTester tester, {Locale locale = const Locale('en')}) async {
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final container = await tester.runAsync(
      () => makeContainer(
        api: api,
        overrides: [
          categoriesProvider.overrideWith((ref) async => const [Category(slug: 'vehicle', name: 'Vehicle')]),
          clockProvider.overrideWithValue(() => DateTime(2026, 9, 1, 3)),
        ],
      ),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container!,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const FeedPage(),
        ),
      ),
    );
    return container;
  }

  testWidgets('shows results with prices, cities and age', (tester) async {
    whenListings(api).thenAnswer((_) async => page([1, 2], total: 2));
    await pump(tester);
    await tester.pump();
    await tester.pump();

    expect(find.text('2 results'), findsOneWidget);
    expect(find.text('Listing 1'), findsOneWidget);
    expect(find.text('100 SAR'), findsOneWidget);
    expect(find.text('Riyadh · 3 h'), findsNWidgets(2));
  });

  testWidgets('selecting a category requests it', (tester) async {
    whenListings(api).thenAnswer((_) async => page([1], total: 1));
    await pump(tester);
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Cars'));
    await tester.pump();

    final queries = verify(
      () => api.listings(
        captureAny(),
        offset: any(named: 'offset'),
        limit: any(named: 'limit'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).captured.cast<ListingQuery>();
    expect(queries.last.category, 'vehicle');
  });

  testWidgets('offers a retry when the network is down', (tester) async {
    whenListings(api).thenThrow(const NetworkUnavailable('offline'));
    await pump(tester);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();

    expect(find.text('No internet connection'), findsOneWidget);
    whenListings(api).thenAnswer((_) async => page([3], total: 1));
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Listing 3'), findsOneWidget);
  });

  testWidgets('is fully localized in Arabic', (tester) async {
    whenListings(api).thenAnswer((_) async => page([1], total: 1));
    await pump(tester, locale: const Locale('ar'));
    await tester.pump();
    await tester.pump();

    expect(find.text('نتيجة واحدة'), findsOneWidget);
    expect(find.text('سيارات'), findsOneWidget);
    expect(find.text('الرياض · 3 س'), findsOneWidget);
  });
}
