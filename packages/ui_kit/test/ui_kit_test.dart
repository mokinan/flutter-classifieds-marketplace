import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui_kit/ui_kit.dart';

Widget _host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  theme: MarketplaceTheme.light(),
  locale: locale,
  supportedLocales: const [Locale('en'), Locale('ar')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: Scaffold(body: child),
);

void main() {
  group('formatSar', () {
    test('omits decimals for whole riyals and keeps them otherwise', () {
      expect(formatSar(125000, 'en'), '1,250 SAR');
      expect(formatSar(3746, 'en'), '37.46 SAR');
      expect(formatSar(5, 'en'), '0.05 SAR');
    });
  });

  testWidgets('ListingCard shows content and toggles favorite', (tester) async {
    var toggled = 0;
    var tapped = 0;
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 200,
          height: 360,
          child: ListingCard(
            title: 'Toyota Land Cruiser 2019',
            priceHalalas: 18500000,
            subtitle: 'Riyadh · 2 h',
            image: const ColoredBox(color: Colors.grey),
            onTap: () => tapped++,
            onFavoriteToggle: () => toggled++,
            favoriteTooltip: 'Save',
          ),
        ),
      ),
    );

    expect(find.text('Toyota Land Cruiser 2019'), findsOneWidget);
    expect(find.text('185,000 SAR'), findsOneWidget);
    await tester.tap(find.byTooltip('Save'));
    await tester.tap(find.text('Riyadh · 2 h'));
    expect((toggled, tapped), (1, 1));
  });

  testWidgets('ListingCard hides the favorite button without a callback', (tester) async {
    await tester.pumpWidget(
      _host(
        const SizedBox(
          width: 200,
          height: 360,
          child: ListingCard(title: 't', priceHalalas: 100, subtitle: 's', image: SizedBox()),
        ),
      ),
    );
    expect(find.byIcon(Icons.favorite_border), findsNothing);
  });

  testWidgets('StatusView runs its action', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      _host(
        StatusView(
          icon: Icons.wifi_off,
          title: 'No connection',
          message: 'Check your network',
          actionLabel: 'Retry',
          onAction: () => retried = true,
        ),
      ),
    );
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
    expect(find.text('Check your network'), findsOneWidget);
  });

  testWidgets('StepProgress highlights the current step', (tester) async {
    await tester.pumpWidget(_host(const StepProgress(current: 1, labels: ['Photos', 'Details', 'Price'])));
    final details = tester.widget<Text>(find.text('Details'));
    expect(details.style?.fontWeight, FontWeight.w700);
    expect(tester.widget<Text>(find.text('Photos')).style?.fontWeight, isNot(FontWeight.w700));
  });

  testWidgets('Skeleton and OfflineBanner render', (tester) async {
    await tester.pumpWidget(
      _host(
        const Column(
          children: [
            OfflineBanner(message: 'Showing saved results'),
            Skeleton(height: 20, width: 100),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Showing saved results'), findsOneWidget);
    expect(find.byType(Skeleton), findsOneWidget);
  });

  testWidgets('PriceText stays left-to-right in Arabic', (tester) async {
    await tester.pumpWidget(_host(const PriceText(50000), locale: const Locale('ar')));
    expect(tester.widget<Text>(find.byType(Text)).textDirection, TextDirection.ltr);
  });
}
