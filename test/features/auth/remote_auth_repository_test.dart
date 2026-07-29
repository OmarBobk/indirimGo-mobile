import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indirimgo_mobile/core/config/app_config.dart';
import 'package:indirimgo_mobile/core/errors/api_exception.dart';
import 'package:indirimgo_mobile/core/network/api_client.dart';
import 'package:indirimgo_mobile/core/storage/token_storage.dart';
import 'package:indirimgo_mobile/features/auth/data/remote_auth_repository.dart';
import 'package:indirimgo_mobile/features/auth/domain/auth_models.dart';

void main() {
  late QueueAdapter adapter;
  late InMemoryTokenStorage storage;
  late ApiClient client;
  late RemoteAuthRepository repository;

  setUp(() {
    adapter = QueueAdapter();
    storage = InMemoryTokenStorage();
    final dio = Dio()..httpClientAdapter = adapter;
    client = ApiClient(
      config: AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
      tokenStorage: storage,
      locale: 'ar',
      dio: dio,
    );
    repository = RemoteAuthRepository(
      apiClient: client,
      tokenStorage: storage,
    );
  });

  test('200 login stores the Sanctum token and sends required headers', () async {
    adapter.enqueue(200, authenticationJson);

    final outcome = await repository.login(
      username: 'omar',
      password: 'password-value',
    );

    expect(outcome, isA<LoginAuthenticated>());
    expect(storage.session?.token, '7|plain-token');
    expect(adapter.requests.single.path, 'auth/login');
    expect(adapter.requests.single.headers['Accept'], 'application/json');
    expect(adapter.requests.single.headers['Accept-Language'], 'ar');
    expect(adapter.requests.single.headers['Authorization'], isNull);
  });

  test('202 login returns an in-memory challenge without storing it', () async {
    adapter.enqueue(202, {
      'data': {
        'two_factor_required': true,
        'challenge_token': 'opaque-challenge-value',
        'expires_at': '2026-08-01T12:00:00Z',
      },
    });

    final outcome = await repository.login(
      username: 'omar',
      password: 'password-value',
    );

    expect(outcome, isA<LoginTwoFactorRequired>());
    expect(storage.session, isNull);
  });

  test('authenticator and recovery completion use exact contract fields', () async {
    final challenge = TwoFactorChallenge(
      token: 'opaque-challenge',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
    );
    adapter
      ..enqueue(200, authenticationJson)
      ..enqueue(200, authenticationJson);

    await repository.completeTwoFactorWithAuthenticator(
      challenge: challenge,
      code: '123456',
    );
    await repository.completeTwoFactorWithRecoveryCode(
      challenge: challenge,
      recoveryCode: 'recovery-value',
    );

    expect(adapter.requests[0].data, {
      'challenge_token': 'opaque-challenge',
      'code': '123456',
    });
    expect(adapter.requests[1].data, {
      'challenge_token': 'opaque-challenge',
      'recovery_code': 'recovery-value',
    });
    expect(storage.session?.token, '7|plain-token');
  });

  test('maps 401 and clears the rejected token', () async {
    storage.session = storedSession;
    adapter.enqueue(401, {'message': 'Unauthenticated.', 'code': 'unauthenticated'});

    await expectLater(
      repository.fetchCurrentUser(),
      throwsA(
        isA<ApiException>().having(
          (error) => error.kind,
          'kind',
          ApiErrorKind.unauthorized,
        ),
      ),
    );
    expect(storage.session, isNull);
  });

  test('maps 403 422 and 429 with field and retry details', () async {
    adapter
      ..enqueue(403, {
        'message': 'Forbidden',
        'code': 'customer_role_required',
      })
      ..enqueue(422, {
        'message': 'Invalid',
        'errors': {
          'username': ['Required'],
        },
      })
      ..enqueue(
        429,
        {'message': 'Wait', 'code': 'too_many_requests'},
        headers: {
          'retry-after': ['18'],
        },
      );

    await expectLater(
      client.get('me'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.kind,
          'kind',
          ApiErrorKind.forbidden,
        ),
      ),
    );
    await expectLater(
      client.post('auth/login'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.fieldErrors['username'],
          'username errors',
          ['Required'],
        ),
      ),
    );
    await expectLater(
      client.post('auth/login'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.retryAfterSeconds,
          'retry seconds',
          18,
        ),
      ),
    );
  });

  test('retains token on offline timeout and server failures', () async {
    for (final failure in [
      DioExceptionType.connectionError,
      DioExceptionType.connectionTimeout,
    ]) {
      storage.session = storedSession;
      adapter.enqueueFailure(failure);
      await expectLater(
        client.get('me'),
        throwsA(isA<ApiException>()),
      );
      expect(storage.session?.token, storedSession.token);
    }

    storage.session = storedSession;
    adapter.enqueue(503, {'message': 'Unavailable'});
    await expectLater(client.get('me'), throwsA(isA<ApiException>()));
    expect(storage.session?.token, storedSession.token);
  });

  test('logout clears after confirmation but keeps token when offline', () async {
    storage.session = storedSession;
    adapter.enqueue(200, {
      'data': {'message': 'Logged out successfully.'},
    });
    await repository.logout();
    expect(storage.session, isNull);

    storage.session = storedSession;
    adapter.enqueueFailure(DioExceptionType.connectionError);
    await expectLater(repository.logout(), throwsA(isA<ApiException>()));
    expect(storage.session?.token, storedSession.token);
  });

  test('exception strings do not expose server messages or bearer tokens', () async {
    storage.session = storedSession;
    adapter.enqueue(422, {
      'message': 'Leaked 7|sensitive-token',
      'code': 'invalid_credentials',
    });

    try {
      await client.post('auth/login');
      fail('Expected request to fail');
    } on ApiException catch (error) {
      expect(error.toString(), isNot(contains('sensitive-token')));
      expect(error.toString(), isNot(contains('Leaked')));
    }
  });
}

final storedSession = StoredSession(
  token: '7|stored-token',
  expiresAt: DateTime.utc(2026, 8, 28),
);

final authenticationJson = <String, Object?>{
  'data': {
    'token': {
      'access_token': '7|plain-token',
      'token_type': 'Bearer',
      'expires_at': '2026-08-28T12:00:00Z',
    },
    'user': {
      'id': 7,
      'name': 'Omar Customer',
      'username': 'omar',
      'email': 'omar@example.com',
      'phone': null,
      'country_code': null,
      'locale': 'ar',
      'preferred_currency': 'USD',
      'timezone': null,
      'profile_photo_url': null,
      'email_verified_at': null,
    },
  },
};

class QueueAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final List<_QueuedResponse> _responses = [];

  void enqueue(
    int statusCode,
    Object body, {
    Map<String, List<String>> headers = const {},
  }) {
    _responses.add(
      _QueuedResponse(statusCode: statusCode, body: body, headers: headers),
    );
  }

  void enqueueFailure(DioExceptionType type) {
    _responses.add(_QueuedResponse(failureType: type));
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final queued = _responses.removeAt(0);
    if (queued.failureType case final type?) {
      throw DioException(
        requestOptions: options,
        type: type,
        error: const SocketException('offline'),
      );
    }
    return ResponseBody.fromString(
      jsonEncode(queued.body),
      queued.statusCode!,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...queued.headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _QueuedResponse {
  const _QueuedResponse({
    this.statusCode,
    this.body,
    this.headers = const {},
    this.failureType,
  });

  final int? statusCode;
  final Object? body;
  final Map<String, List<String>> headers;
  final DioExceptionType? failureType;
}
