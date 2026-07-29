import 'dart:async';
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
      config: AppConfig(
        apiBaseUrl: 'https://api.example.test/api/v1',
        buildMode: AppBuildMode.release,
      ),
      tokenStorage: storage,
      locale: 'ar',
      dio: dio,
    );
    repository = RemoteAuthRepository(apiClient: client, tokenStorage: storage);
  });

  test(
    '200 login stores the Sanctum token and sends required headers',
    () async {
      adapter.enqueue(200, authenticationJson);

      final outcome = await repository.login(
        username: 'omar',
        password: 'password-value',
      );

      expect(outcome, isA<LoginAuthenticated>());
      expect(storage.session?.token, '7|plain-token');
      expect(adapter.requests.single.path, 'auth/login');
      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.data, {
        'username': 'omar',
        'password': 'password-value',
      });
      expect(adapter.requests.single.headers['Accept'], 'application/json');
      expect(adapter.requests.single.headers['Accept-Language'], 'ar');
      expect(adapter.requests.single.headers['Authorization'], isNull);
    },
  );

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
    final challenge = (outcome as LoginTwoFactorRequired).challenge;
    expect(challenge.token, 'opaque-challenge-value');
    expect(challenge.expiresAt, DateTime.utc(2026, 8, 1, 12));
    expect(storage.session, isNull);
  });

  test('login enforces OpenAPI 200 and 202 response schemas', () async {
    adapter
      ..enqueue(200, {
        'data': {
          'two_factor_required': true,
          'challenge_token': 'wrong-status-challenge',
          'expires_at': '2026-08-01T12:00:00Z',
        },
      })
      ..enqueue(202, authenticationJson);

    await expectLater(
      repository.login(username: 'omar', password: 'password-value'),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      repository.login(username: 'omar', password: 'password-value'),
      throwsA(isA<FormatException>()),
    );
    expect(storage.session, isNull);
  });

  test(
    'authenticator and recovery completion use exact contract fields',
    () async {
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
    },
  );

  test('two-factor token responses require HTTP 200', () async {
    final challenge = TwoFactorChallenge(
      token: 'opaque-challenge',
      expiresAt: DateTime.utc(2026, 8, 1),
    );
    adapter.enqueue(202, authenticationJson);

    await expectLater(
      repository.completeTwoFactorWithAuthenticator(
        challenge: challenge,
        code: '123456',
      ),
      throwsA(isA<FormatException>()),
    );
    expect(storage.session, isNull);
  });

  test('maps 401 and clears the rejected token', () async {
    storage.session = storedSession;
    adapter.enqueue(401, {
      'message': 'Unauthenticated.',
      'code': 'unauthenticated',
    });

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
      ..enqueue(403, {'message': 'Forbidden', 'code': 'customer_role_required'})
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
          ['invalid'],
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
      await expectLater(client.get('me'), throwsA(isA<ApiException>()));
      expect(storage.session?.token, storedSession.token);
    }

    storage.session = storedSession;
    adapter.enqueue(503, {'message': 'Unavailable'});
    await expectLater(client.get('me'), throwsA(isA<ApiException>()));
    expect(storage.session?.token, storedSession.token);
  });

  test(
    'logout clears after confirmation but keeps token when offline',
    () async {
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
    },
  );

  test(
    'logout clears matching sessions on authoritative 401 and 403',
    () async {
      storage.session = storedSession;
      adapter.enqueue(401, {
        'message': 'Unauthenticated.',
        'code': 'unauthenticated',
      });
      await expectLater(repository.logout(), throwsA(isA<ApiException>()));
      expect(storage.session, isNull);

      storage.session = storedSession;
      adapter.enqueue(403, {
        'message': 'Forbidden.',
        'code': 'missing_mobile_ability',
      });
      await expectLater(repository.logout(), throwsA(isA<ApiException>()));
      expect(storage.session, isNull);
    },
  );

  test('a delayed token-A 401 cannot clear token B', () async {
    final tokenA = storedSession;
    final tokenB = StoredSession(
      token: '8|new-session-token',
      expiresAt: DateTime.utc(2026, 9, 1),
    );
    storage.session = tokenA;
    final controlled = adapter.enqueueControlled();

    final oldRequest = client.get('me');
    await _waitForRequests(adapter, 1);
    await storage.write(tokenB);
    final expectation = expectLater(
      oldRequest,
      throwsA(
        isA<ApiException>().having(
          (error) => error.kind,
          'kind',
          ApiErrorKind.unauthorized,
        ),
      ),
    );
    controlled.complete(401, {
      'message': 'Unauthenticated.',
      'code': 'unauthenticated',
    });
    await expectation;

    expect(storage.session?.token, tokenB.token);
  });

  test('simultaneous 401 responses clear a matching session once', () async {
    storage.session = storedSession;
    final first = adapter.enqueueControlled();
    final second = adapter.enqueueControlled();

    final firstRequest = client.get('me');
    final secondRequest = client.get('me');
    await _waitForRequests(adapter, 2);
    final firstExpectation = expectLater(
      firstRequest,
      throwsA(isA<ApiException>()),
    );
    final secondExpectation = expectLater(
      secondRequest,
      throwsA(isA<ApiException>()),
    );
    first.complete(401, {
      'message': 'Unauthenticated.',
      'code': 'unauthenticated',
    });
    second.complete(401, {
      'message': 'Unauthenticated.',
      'code': 'unauthenticated',
    });

    await Future.wait([firstExpectation, secondExpectation]);
    expect(storage.session, isNull);
    expect(storage.clearCount, 1);
  });

  test('storage clear failure preserves the original 401', () async {
    final failingStorage = FailingClearTokenStorage(storedSession);
    final failingClient = ApiClient(
      config: AppConfig(
        apiBaseUrl: 'https://api.example.test/api/v1',
        buildMode: AppBuildMode.release,
      ),
      tokenStorage: failingStorage,
      locale: 'en',
      dio: Dio()..httpClientAdapter = adapter,
    );
    final failingRepository = RemoteAuthRepository(
      apiClient: failingClient,
      tokenStorage: failingStorage,
    );
    adapter.enqueue(401, {
      'message': 'sensitive-original-message',
      'code': 'unauthenticated',
    });

    await expectLater(
      failingRepository.fetchCurrentUser(),
      throwsA(
        isA<ApiException>().having(
          (error) => error.kind,
          'original error kind',
          ApiErrorKind.unauthorized,
        ),
      ),
    );
    expect(failingStorage.session?.token, storedSession.token);
  });

  test(
    'unknown server content never survives mapping or diagnostics',
    () async {
      storage.session = storedSession;
      adapter.enqueue(422, {
        'message': 'message-sensitive-sentinel',
        'code': 'code-sensitive-sentinel',
        'errors': {
          'username': ['field-sensitive-sentinel'],
          'unexpected_field': ['unexpected-sensitive-sentinel'],
        },
      });

      try {
        await client.post('auth/login');
        fail('Expected request to fail');
      } on ApiException catch (error) {
        expect(error.code, isNull);
        expect(error.fieldErrors, {
          'username': ['invalid'],
        });
        for (final sentinel in [
          'message-sensitive-sentinel',
          'code-sensitive-sentinel',
          'field-sensitive-sentinel',
          'unexpected-sensitive-sentinel',
          storedSession.token,
        ]) {
          expect(error.toString(), isNot(contains(sentinel)));
        }
      }
    },
  );
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
  final List<Future<_QueuedResponse>> _responses = [];

  void enqueue(
    int statusCode,
    Object body, {
    Map<String, List<String>> headers = const {},
  }) {
    _responses.add(
      Future.value(
        _QueuedResponse(statusCode: statusCode, body: body, headers: headers),
      ),
    );
  }

  void enqueueFailure(DioExceptionType type) {
    _responses.add(Future.value(_QueuedResponse(failureType: type)));
  }

  ControlledResponse enqueueControlled() {
    final response = ControlledResponse();
    _responses.add(response._completion.future);
    return response;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final queued = await _responses.removeAt(0);
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

final class ControlledResponse {
  final _completion = Completer<_QueuedResponse>();

  void complete(
    int statusCode,
    Object body, {
    Map<String, List<String>> headers = const {},
  }) {
    _completion.complete(
      _QueuedResponse(statusCode: statusCode, body: body, headers: headers),
    );
  }
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

final class FailingClearTokenStorage extends InMemoryTokenStorage {
  FailingClearTokenStorage(super.session);

  @override
  Future<bool> clearIfCurrent(SessionReference reference) {
    throw StateError('storage-clear-sensitive-sentinel');
  }
}

Future<void> _waitForRequests(QueueAdapter adapter, int count) async {
  while (adapter.requests.length < count) {
    await Future<void>.delayed(Duration.zero);
  }
}
