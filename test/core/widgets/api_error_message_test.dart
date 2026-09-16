import 'package:flutter_test/flutter_test.dart';
import 'package:indirimgo_mobile/core/errors/api_exception.dart';
import 'package:indirimgo_mobile/core/localization/generated/app_localizations_ar.dart';
import 'package:indirimgo_mobile/core/localization/generated/app_localizations_en.dart';
import 'package:indirimgo_mobile/core/widgets/api_error_message.dart';

void main() {
  test('generic 404 is not package wording in English or Arabic', () {
    const error = ApiException(kind: ApiErrorKind.notFound, statusCode: 404);
    final en = AppLocalizationsEn();
    final ar = AppLocalizationsAr();
    expect(localizedApiError(en, error), en.sessionFailure);
    expect(localizedApiError(en, error), isNot(en.packageNotFound));
    expect(localizedApiError(ar, error), ar.sessionFailure);
    expect(localizedApiError(ar, error), isNot(ar.packageNotFound));
  });

  test('package, order, and top-up 404 codes keep their own copy', () {
    final en = AppLocalizationsEn();
    expect(
      localizedApiError(
        en,
        const ApiException(
          kind: ApiErrorKind.notFound,
          code: 'package_not_found',
        ),
      ),
      en.packageNotFound,
    );
    expect(
      localizedApiError(
        en,
        const ApiException(
          kind: ApiErrorKind.notFound,
          code: 'order_not_found',
        ),
      ),
      en.orderNotFound,
    );
    expect(
      localizedApiError(
        en,
        const ApiException(
          kind: ApiErrorKind.notFound,
          code: 'topup_not_found',
        ),
      ),
      en.topupNotFound,
    );
  });
}
