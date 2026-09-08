import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indirimgo_mobile/core/localization/generated/app_localizations.dart';
import 'package:indirimgo_mobile/core/widgets/catalog_media_frame.dart';

void main() {
  testWidgets('placeholder and error fallback stay square', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CatalogMediaFrame(
            imageUrl: null,
            size: 72,
            semanticLabel: 'Package image',
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
    expect(tester.getSize(find.byType(CatalogMediaFrame)), const Size(72, 72));
  });

  test('provider identity is stable for the same URL and decode size', () {
    final url = Uri.parse('https://cdn.example.test/logo.png');
    final first = CatalogMediaFrame.providerFor(
      imageUrl: url,
      logicalSize: 72,
      devicePixelRatio: 2,
    );
    final second = CatalogMediaFrame.providerFor(
      imageUrl: url,
      logicalSize: 72,
      devicePixelRatio: 2,
    );
    final other = CatalogMediaFrame.providerFor(
      imageUrl: url,
      logicalSize: 96,
      devicePixelRatio: 2,
    );
    expect(first, equals(second));
    expect(first, isNot(equals(other)));
    expect(first, isA<ResizeImage>());
  });

  testWidgets('detail artwork uses contain rather than a fixed cover height', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: SizedBox(
            width: 200,
            child: CatalogDetailArtwork(imageUrl: null),
          ),
        ),
      ),
    );
    expect(find.byType(AspectRatio), findsOneWidget);
    expect(find.byType(CatalogMediaFrame), findsOneWidget);
    expect(
      tester.getSize(find.byType(CatalogMediaFrame)).longestSide,
      lessThanOrEqualTo(CatalogDetailArtwork.maxLogicalSize + 0.5),
    );
  });
}
