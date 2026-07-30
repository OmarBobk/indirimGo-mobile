import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indirimgo_mobile/core/localization/generated/app_localizations.dart';
import 'package:indirimgo_mobile/features/catalog/domain/catalog_models.dart';
import 'package:indirimgo_mobile/features/catalog/presentation/widgets/catalog_widgets.dart';

import '../../support/catalog_fixtures.dart';

void main() {
  Widget wrap(Widget child, {Locale locale = const Locale('ar')}) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Directionality(
        textDirection: locale.languageCode == 'ar'
            ? TextDirection.rtl
            : TextDirection.ltr,
        child: Scaffold(body: child),
      ),
    );
  }

  testWidgets('customer-visible prices render LTR inside Arabic RTL', (
    tester,
  ) async {
    final fixed = Money.fromJson(moneyJson(formatted: r'$5.00'));
    final minimum = Money.fromJson(
      moneyJson(amount: '1.00', formatted: r'$1.00'),
    );
    final fromPrice = Money.fromJson(
      moneyJson(amount: '12.50', formatted: '₺425.00'),
    );

    await tester.pumpWidget(
      wrap(
        Column(
          children: [
            CatalogPriceText(
              key: const Key('fixed-price'),
              pricesVisible: true,
              money: fixed,
            ),
            CatalogPriceText(
              key: const Key('custom-minimum-price'),
              pricesVisible: true,
              money: minimum,
              prefix: 'Minimum ',
            ),
            CatalogPriceText(
              key: const Key('package-from-price'),
              pricesVisible: true,
              money: fromPrice,
              prefix: 'From ',
            ),
          ],
        ),
      ),
    );

    for (final key in [
      'fixed-price',
      'custom-minimum-price',
      'package-from-price',
    ]) {
      final text = tester.widget<Text>(
        find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)),
      );
      expect(text.textDirection, TextDirection.ltr, reason: key);
    }

    expect(
      tester
          .widget<Directionality>(find.byType(Directionality).first)
          .textDirection,
      TextDirection.rtl,
    );
  });
}
