import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indirimgo_mobile/core/config/app_config.dart';
import 'package:indirimgo_mobile/core/errors/api_exception.dart';
import 'package:indirimgo_mobile/core/network/api_client.dart';
import 'package:indirimgo_mobile/core/storage/token_storage.dart';
import 'package:indirimgo_mobile/features/orders/data/remote_order_repository.dart';
import 'package:indirimgo_mobile/features/orders/domain/order_models.dart';

import '../../support/fakes.dart';
import '../../support/order_fixtures.dart';

void main() {
  late _QueueAdapter adapter;
  late RemoteOrderRepository repository;

  setUp(() {
    adapter = _QueueAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1/'));
    dio.httpClientAdapter = adapter;
    final client = ApiClient(
      config: AppConfig(
        apiBaseUrl: 'https://api.example.test/api/v1',
        buildMode: AppBuildMode.release,
      ),
      tokenStorage: InMemoryTokenStorage(sampleStoredSession()),
      locale: 'ar',
      dio: dio,
    );
    repository = RemoteOrderRepository(apiClient: client);
  });

  test('uses exact list path, page and per_page', () async {
    adapter.enqueue(200, orderListPageJson(page: 2, lastPage: 2));
    final page = await repository.fetchOrders(const OrderListQuery(page: 2));
    expect(page.orders.single.orderNumber, 'ORD-2026-000001');
    final request = adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.path, 'orders');
    expect(request.queryParameters, {'page': 2, 'per_page': 20});
  });

  test('uses owned detail path and CheckoutSuccess parsing', () async {
    adapter.enqueue(200, orderDetailJson());
    final result = await repository.fetchOrder('ORD-2026-000001');
    expect(result.order.fulfillmentStatus, 'completed');
    expect(adapter.requests.single.path, 'orders/ORD-2026-000001');
    expect(adapter.requests.single.queryParameters, isEmpty);
  });

  test('maps HTTP and network failures without raw response data', () async {
    final cases = <(int, ApiErrorKind)>[
      (401, ApiErrorKind.unauthorized),
      (403, ApiErrorKind.forbidden),
      (404, ApiErrorKind.notFound),
      (422, ApiErrorKind.validation),
      (429, ApiErrorKind.rateLimited),
      (503, ApiErrorKind.server),
    ];
    for (final item in cases) {
      adapter.enqueueError(item.$1);
      await expectLater(
        repository.fetchOrders(const OrderListQuery()),
        throwsA(
          isA<ApiException>()
              .having((error) => error.kind, 'kind', item.$2)
              .having(
                (error) => error.toString(),
                'safe exception',
                isNot(contains('private-order')),
              ),
        ),
      );
    }
    adapter.enqueueNetworkError();
    await expectLater(
      repository.fetchOrder('ORD-2026-000001'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.kind,
          'kind',
          ApiErrorKind.network,
        ),
      ),
    );
  });
}

class _QueuedResponse {
  const _QueuedResponse(this.statusCode, this.network);

  final int statusCode;
  final bool network;
}

class _QueueAdapter implements HttpClientAdapter {
  final List<_QueuedResponse> _queue = [];
  final List<RequestOptions> requests = [];

  void enqueue(int statusCode, Map<String, Object?> body) {
    _bodies.add(body);
    _queue.add(_QueuedResponse(statusCode, false));
  }

  void enqueueError(int statusCode) {
    _bodies.add({
      'message': 'private-order-data-must-not-surface',
      'code': statusCode == 404 ? 'order_not_found' : 'private-order',
    });
    _queue.add(_QueuedResponse(statusCode, false));
  }

  void enqueueNetworkError() {
    _bodies.add(const {});
    _queue.add(const _QueuedResponse(0, true));
  }

  final List<Map<String, Object?>> _bodies = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final next = _queue.removeAt(0);
    final body = _bodies.removeAt(0);
    if (next.network) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    if (next.statusCode >= 400) {
      throw DioException(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: next.statusCode,
          data: body,
          headers: Headers.fromMap({
            if (next.statusCode == 429) 'retry-after': ['3'],
          }),
        ),
        type: DioExceptionType.badResponse,
      );
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      next.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
