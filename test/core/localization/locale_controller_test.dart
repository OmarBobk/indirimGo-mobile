import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indirimgo_mobile/core/localization/generated/app_localizations_ar.dart';
import 'package:indirimgo_mobile/core/localization/generated/app_localizations_en.dart';
import 'package:indirimgo_mobile/core/localization/locale_controller.dart';

void main() {
  test('locale resolution uses the first supported preferred locale', () {
    expect(
      resolveSupportedLocale(const [Locale('tr'), Locale('en')]),
      const Locale('en'),
    );
    expect(
      resolveSupportedLocale(const [Locale('fr'), Locale('ar')]),
      const Locale('ar'),
    );
    expect(resolveSupportedLocale(const [Locale('tr')]), const Locale('ar'));
  });

  test('English retry timing uses singular and plural forms', () {
    final l10n = AppLocalizationsEn();

    expect(l10n.rateLimitSeconds(0), 'Try again now.');
    expect(l10n.rateLimitSeconds(1), 'Try again in 1 second.');
    expect(l10n.rateLimitSeconds(2), 'Try again in 2 seconds.');
  });

  test('Arabic retry timing uses its ICU plural categories', () {
    final l10n = AppLocalizationsAr();

    expect(l10n.rateLimitSeconds(0), 'يمكنك المحاولة الآن.');
    expect(l10n.rateLimitSeconds(1), 'حاول مجدداً بعد ثانية واحدة.');
    expect(l10n.rateLimitSeconds(2), 'حاول مجدداً بعد ثانيتين.');
    expect(l10n.rateLimitSeconds(3), 'حاول مجدداً بعد 3 ثوانٍ.');
    expect(l10n.rateLimitSeconds(11), 'حاول مجدداً بعد 11 ثانيةً.');
    expect(l10n.rateLimitSeconds(100), 'حاول مجدداً بعد 100 ثانية.');
  });
}
