import 'package:flutter_test/flutter_test.dart';
import 'package:indirimgo_mobile/core/errors/api_exception.dart';

void main() {
  test('401 is always an authoritative session rejection', () {
    expect(
      const ApiException(
        kind: ApiErrorKind.unauthorized,
        statusCode: 401,
      ).isAuthoritativeSessionRejection,
      isTrue,
    );
  });

  test('allowlisted 403 codes end the session', () {
    for (final code in authoritativeSessionRejectionCodes) {
      expect(
        ApiException(
          kind: ApiErrorKind.forbidden,
          code: code,
          statusCode: 403,
        ).isAuthoritativeSessionRejection,
        isTrue,
        reason: code,
      );
    }
  });

  test('generic 403 without allowlisted code retains the session', () {
    expect(
      const ApiException(
        kind: ApiErrorKind.forbidden,
        statusCode: 403,
      ).isAuthoritativeSessionRejection,
      isFalse,
    );
    expect(
      const ApiException(
        kind: ApiErrorKind.forbidden,
        code: 'resource_forbidden',
        statusCode: 403,
      ).isAuthoritativeSessionRejection,
      isFalse,
    );
  });

  test('offline and 5xx are not session-ending', () {
    expect(
      const ApiException(
        kind: ApiErrorKind.network,
      ).isAuthoritativeSessionRejection,
      isFalse,
    );
    expect(
      const ApiException(
        kind: ApiErrorKind.server,
        statusCode: 503,
      ).isAuthoritativeSessionRejection,
      isFalse,
    );
  });
}
