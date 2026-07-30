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
import 'package:indirimgo_mobile/features/catalog/data/remote_catalog_repository.dart';
import 'package:indirimgo_mobile/features/catalog/domain/catalog_models.dart';

import '../../support/catalog_fixtures.dart';

void main() {
  late _QueueAdapter adapter;
  late InMemoryTokenStorage storage;
  late ApiClient client;
  late RemoteCatalogRepository repository;

  setUp(() async {
    adapter = _QueueAdapter();
    storage = InMemoryTokenStorage();
    await storage.write(
      StoredSession(
        token: '7|catalog-token',
        expiresAt: DateTime.utc(2026, 8, 28),
      ),
    );
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
    repository = RemoteCatalogRepository(apiClient: client);
  });

  test('home uses GET catalog/home with auth and locale headers', () async {
    adapter.enqueue(200, catalogHomeJson());

    final home = await repository.fetchHome();

    expect(home.featuredPackages, isNotEmpty);
    expect(adapter.requests.single.path, 'catalog/home');
    expect(adapter.requests.single.method, 'GET');
    expect(adapter.requests.single.headers['Accept'], 'application/json');
    expect(adapter.requests.single.headers['Accept-Language'], 'ar');
    expect(
      adapter.requests.single.headers['Authorization'],
      'Bearer 7|catalog-token',
    );
  });

  test('list sends category_id, q, page, and per_page', () async {
    adapter.enqueue(200, packageListJson());

    await repository.fetchPackages(
      const PackageListQuery(categoryId: 3, q: 'game', page: 2, perPage: 10),
    );

    expect(adapter.requests.single.path, 'packages');
    expect(adapter.requests.single.queryParameters, {
      'page': 2,
      'per_page': 10,
      'category_id': 3,
      'q': 'game',
    });
  });

  test('detail uses numeric package id path', () async {
    adapter.enqueue(200, packageDetailJson());
    final result = await repository.fetchPackage(42);
    expect(result.package.id, 42);
    expect(adapter.requests.single.path, 'packages/42');
  });

  test('maps 401/403/404/422/429 and offline failures', () async {
    adapter
      ..enqueue(401, {'message': 'Unauthenticated.', 'code': 'unauthenticated'})
      ..enqueue(403, {'message': 'nope', 'code': 'missing_mobile_ability'})
      ..enqueue(404, {
        'message': 'Package not found.',
        'code': 'package_not_found',
      })
      ..enqueue(422, {
        'message': 'invalid',
        'errors': {
          'q': ['too short'],
          'secret': ['leak'],
        },
      })
      ..enqueue(
        429,
        {'message': 'slow', 'code': 'too_many_requests'},
        headers: {
          'retry-after': ['12'],
        },
      )
      ..enqueueFailure(DioExceptionType.connectionError)
      ..enqueue(500, {'message': 'boom'});

    await expectLater(
      repository.fetchHome(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.kind,
          'kind',
          ApiErrorKind.unauthorized,
        ),
      ),
    );
    expect(storage.session, isNull);
    await storage.write(
      StoredSession(
        token: '7|catalog-token',
        expiresAt: DateTime.utc(2026, 8, 28),
      ),
    );
    await expectLater(
      repository.fetchPackages(const PackageListQuery()),
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          'missing_mobile_ability',
        ),
      ),
    );
    expect(storage.session, isNull);
    await storage.write(
      StoredSession(
        token: '7|catalog-token',
        expiresAt: DateTime.utc(2026, 8, 28),
      ),
    );
    await expectLater(
      repository.fetchPackage(99),
      throwsA(
        isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.notFound)
            .having((e) => e.code, 'code', 'package_not_found'),
      ),
    );
    try {
      await repository.fetchPackages(const PackageListQuery(q: 'x'));
      fail('expected validation');
    } on ApiException catch (error) {
      expect(error.kind, ApiErrorKind.validation);
      expect(error.fieldErrors['q'], ['invalid']);
      expect(error.fieldErrors.containsKey('secret'), isFalse);
      expect(error.toString(), isNot(contains('too short')));
      expect(error.toString(), isNot(contains('5.00')));
    }
    await expectLater(
      repository.fetchHome(),
      throwsA(
        isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.rateLimited)
            .having((e) => e.retryAfterSeconds, 'retry', 12),
      ),
    );
    await expectLater(
      repository.fetchHome(),
      throwsA(
        isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.network),
      ),
    );
    await expectLater(
      repository.fetchHome(),
      throwsA(
        isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.server),
      ),
    );
    expect(storage.session?.token, '7|catalog-token');
  });

  test('cancel token maps to cancelled without clearing session', () async {
    final token = CancelToken();
    final controlled = adapter.enqueueControlled();
    final future = repository.fetchHome(cancelToken: token);
    await _waitForRequests(adapter, 1);
    token.cancel('test');
    controlled.complete(200, catalogHomeJson());
    await expectLater(
      future,
      throwsA(
        isA<ApiException>().having(
          (e) => e.kind,
          'kind',
          ApiErrorKind.cancelled,
        ),
      ),
    );
    expect(storage.session?.token, '7|catalog-token');
  });

  test('401 clears only the matching session token', () async {
    adapter.enqueue(401, {
      'message': 'Unauthenticated.',
      'code': 'unauthenticated',
    });
    await expectLater(repository.fetchHome(), throwsA(isA<ApiException>()));
    expect(storage.session, isNull);
  });
}

class _QueueAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final List<Future<_Queued>> _responses = [];

  void enqueue(
    int statusCode,
    Object body, {
    Map<String, List<String>> headers = const {},
  }) {
    _responses.add(
      Future.value(
        _Queued(statusCode: statusCode, body: body, headers: headers),
      ),
    );
  }

  void enqueueFailure(DioExceptionType type) {
    _responses.add(Future.value(_Queued(failureType: type)));
  }

  _Controlled enqueueControlled() {
    final response = _Controlled();
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
    if (cancelFuture != null) {
      unawaited(
        cancelFuture.then((_) {
          if (!options.cancelToken!.isCancelled) {
            // Dio marks the token cancelled before cancelFuture completes.
          }
        }),
      );
    }
    if (options.cancelToken?.isCancelled == true) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
      );
    }
    final queued = await _responses.removeAt(0);
    if (options.cancelToken?.isCancelled == true) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
      );
    }
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

final class _Controlled {
  final _completion = Completer<_Queued>();

  void complete(
    int statusCode,
    Object body, {
    Map<String, List<String>> headers = const {},
  }) {
    _completion.complete(
      _Queued(statusCode: statusCode, body: body, headers: headers),
    );
  }
}

class _Queued {
  const _Queued({
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

Future<void> _waitForRequests(_QueueAdapter adapter, int count) async {
  while (adapter.requests.length < count) {
    await Future<void>.delayed(Duration.zero);
  }
}
