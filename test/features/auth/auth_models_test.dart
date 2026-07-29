import 'package:flutter_test/flutter_test.dart';
import 'package:indirimgo_mobile/features/auth/domain/auth_models.dart';

void main() {
  final userJson = <String, Object?>{
    'id': 12,
    'name': 'Customer',
    'username': 'customer',
    'email': 'customer@example.com',
    'phone': null,
    'country_code': '+90',
    'locale': 'ar',
    'preferred_currency': 'USD',
    'timezone': null,
    'profile_photo_url': 'https://example.test/storage/customer.jpg',
    'email_verified_at': null,
  };

  test('parses the exact mobile user contract and ignores additive fields', () {
    final user = MobileUser.fromJson({...userJson, 'future_field': true});

    expect(user.id, 12);
    expect(user.locale, 'ar');
    expect(user.profilePhotoUrl?.host, 'example.test');
  });

  test('fails safely when a required mobile user field is absent', () {
    final incomplete = {...userJson}..remove('preferred_currency');

    expect(
      () => MobileUser.fromJson(incomplete),
      throwsA(isA<FormatException>()),
    );
  });

  test('parses authentication success and validates bearer token fields', () {
    final session = AuthSession.fromJson({
      'data': {
        'token': {
          'access_token': '12|secret',
          'token_type': 'Bearer',
          'expires_at': '2026-08-28T12:00:00Z',
        },
        'user': userJson,
        'future_field': 'ignored',
      },
    });

    expect(session.token.accessToken, '12|secret');
    expect(session.token.expiresAt, DateTime.utc(2026, 8, 28, 12));
    expect(session.user.username, 'customer');
  });

  test('rejects unsupported or missing authentication response fields', () {
    expect(
      () => AuthSession.fromJson({
        'data': {
          'token': {
            'access_token': 'secret',
            'token_type': 'Basic',
            'expires_at': '2026-08-28T12:00:00Z',
          },
          'user': userJson,
        },
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('parses the two-factor challenge response', () {
    final challenge = TwoFactorChallenge.fromJson({
      'data': {
        'two_factor_required': true,
        'challenge_token': 'opaque-challenge',
        'expires_at': '2026-08-01T12:00:00Z',
      },
    });

    expect(challenge.token, 'opaque-challenge');
    expect(challenge.expiresAt, DateTime.utc(2026, 8, 1, 12));
  });
}
