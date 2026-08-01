import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indirimgo_mobile/core/config/app_config.dart';
import 'package:indirimgo_mobile/core/errors/api_exception.dart';
import 'package:indirimgo_mobile/core/network/api_client.dart';
import 'package:indirimgo_mobile/core/storage/token_storage.dart';
import 'package:indirimgo_mobile/features/purchase/data/remote_purchase_repository.dart';
import 'package:indirimgo_mobile/features/purchase/domain/purchase_models.dart';
import 'package:indirimgo_mobile/features/wallet/data/remote_wallet_repository.dart';

import '../../support/fakes.dart';
import '../../support/purchase_fixtures.dart';

void main() {
  late InMemoryTokenStorage storage;
  late _QueueAdapter adapter;
  late ApiClient apiClient;
  late RemotePurchaseRepository purchase;
  late RemoteWalletRepository wallet;

  setUp(() {
    storage = InMemoryTokenStorage(sampleStoredSession());
    adapter = _QueueAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1/'));
    dio.httpClientAdapter = adapter;
    apiClient = ApiClient(
      config: AppConfig(
        apiBaseUrl: 'https://api.example.test/api/v1',
        buildMode: AppBuildMode.release,
      ),
      tokenStorage: storage,
      locale: 'ar',
      dio: dio,
    );
    purchase = RemotePurchaseRepository(apiClient: apiClient);
    wallet = RemoteWalletRepository(apiClient: apiClient);
  });

  test('quote posts exactly one item and parses money strings', () async {
    adapter.enqueue(200, checkoutQuoteJson());
    final quote = await purchase.quote(
      const CheckoutLineItemRequest(
        productId: 901,
        packageId: 42,
        quantity: 2,
        requirements: {'id': 'player-1'},
      ),
    );
    expect(quote.total.amount, '20.00');
    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, 'checkout/quote');
    final body = _requestBody(request);
    expect(body['items'], isA<List>());
    expect((body['items']! as List), hasLength(1));
    expect(request.headers['Idempotency-Key'], isNull);
  });

  test('checkout attaches Idempotency-Key and fingerprint', () async {
    adapter.enqueue(200, checkoutSuccessJson());
    await purchase.checkout(
      item: const CheckoutLineItemRequest(productId: 901, quantity: 1),
      quoteFingerprint: 'quote-fingerprint-example-123456',
      idempotencyKey: 'ig-test-key',
    );
    final request = adapter.requests.single;
    expect(request.path, 'checkout');
    expect(request.headers['Idempotency-Key'], 'ig-test-key');
    final body = _requestBody(request);
    expect(body['quote_fingerprint'], 'quote-fingerprint-example-123456');
    expect((body['items']! as List), hasLength(1));
  });

  test('status uses Idempotency-Key header only', () async {
    adapter.enqueue(202, checkoutStatusProcessingJson());
    final status = await purchase.checkoutStatus(idempotencyKey: 'ig-status');
    expect(status.state, CheckoutStatusState.processing);
    expect(adapter.requests.single.headers['Idempotency-Key'], 'ig-status');
    expect(adapter.requests.single.path, 'checkout/status');
    expect(adapter.requests.single.uri.query, isEmpty);
  });

  test('wallet summary path and owned receipt lookup', () async {
    adapter.enqueue(200, walletSummaryJson());
    final summary = await wallet.fetchSummary();
    expect(summary.availableToSpend.amount, '42.50');
    expect(adapter.requests.single.path, 'wallet/summary');

    adapter.enqueue(200, checkoutSuccessJson());
    final order = await purchase.fetchOrder('ORD-2026-000001');
    expect(order.order.orderNumber, 'ORD-2026-000001');
    expect(adapter.requests.last.path, 'orders/ORD-2026-000001');
  });

  test('maps purchase error codes including price_changed details', () async {
    adapter.enqueueError(409, {
      'message': 'changed',
      'code': 'price_changed',
      'details': {'current_quote': checkoutQuoteJson()['data']},
    });
    try {
      await purchase.checkout(
        item: const CheckoutLineItemRequest(productId: 901),
        quoteFingerprint: 'quote-fingerprint-example-123456',
        idempotencyKey: 'ig-key',
      );
      fail('expected ApiException');
    } on ApiException catch (error) {
      expect(error.kind, ApiErrorKind.conflict);
      expect(error.code, 'price_changed');
      expect(error.details?['current_quote'], isA<Map>());
      expect(error.toString(), isNot(contains('quote-fingerprint')));
    }
  });

  test(
    'maps insufficient balance, in progress, retry required, 429, network',
    () async {
      Future<void> expectCode(
        int status,
        String code,
        ApiErrorKind kind,
      ) async {
        adapter.enqueueError(status, {'message': 'x', 'code': code});
        try {
          await purchase.checkout(
            item: const CheckoutLineItemRequest(productId: 901),
            quoteFingerprint: 'quote-fingerprint-example-123456',
            idempotencyKey: 'ig-key',
          );
          fail('expected $code');
        } on ApiException catch (error) {
          expect(error.code, code);
          expect(error.kind, kind);
        }
      }

      await expectCode(
        422,
        'insufficient_wallet_balance',
        ApiErrorKind.validation,
      );
      await expectCode(409, 'purchasing_unavailable', ApiErrorKind.conflict);
      await expectCode(409, 'idempotency_conflict', ApiErrorKind.conflict);
      await expectCode(409, 'checkout_retry_required', ApiErrorKind.conflict);
      await expectCode(429, 'too_many_requests', ApiErrorKind.rateLimited);

      adapter.enqueue(202, {
        'message': 'in progress',
        'code': 'checkout_in_progress',
      });
      try {
        await purchase.checkout(
          item: const CheckoutLineItemRequest(productId: 901),
          quoteFingerprint: 'quote-fingerprint-example-123456',
          idempotencyKey: 'ig-key',
        );
        fail('expected in progress');
      } on ApiException catch (error) {
        expect(error.code, 'checkout_in_progress');
        expect(error.statusCode, 202);
      }

      adapter.enqueueNetworkError();
      expect(
        () => purchase.quote(const CheckoutLineItemRequest(productId: 901)),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.network,
          ),
        ),
      );
    },
  );

  test('requirement values are absent from exception strings', () async {
    adapter.enqueueError(422, {
      'message': 'invalid',
      'errors': {
        'items.0.requirements.id': ['bad'],
      },
    });
    try {
      await purchase.quote(
        const CheckoutLineItemRequest(
          productId: 901,
          requirements: {'id': 'super-secret'},
        ),
      );
      fail('expected validation');
    } on ApiException catch (error) {
      expect(error.fieldErrors['items.0.requirements.id'], ['invalid']);
      expect(error.toString(), isNot(contains('super-secret')));
      expect(error.fieldErrors.toString(), isNot(contains('super-secret')));
    }
  });
}

Map<String, Object?> _requestBody(RequestOptions request) {
  final data = request.data;
  if (data is Map<String, Object?>) {
    return data;
  }
  if (data is Map) {
    return data.map((key, value) => MapEntry('$key', value));
  }
  if (data is String) {
    return (jsonDecode(data) as Map).map(
      (key, value) => MapEntry('$key', value),
    );
  }
  throw StateError('Unsupported request body type: ${data.runtimeType}');
}

class _QueuedResponse {
  _QueuedResponse.success(this.statusCode, this.body) : isNetworkError = false;
  _QueuedResponse.error(this.statusCode, this.body) : isNetworkError = false;
  _QueuedResponse.network()
    : statusCode = 0,
      body = const {},
      isNetworkError = true;

  final int statusCode;
  final Map<String, Object?> body;
  final bool isNetworkError;
}

class _QueueAdapter implements HttpClientAdapter {
  final List<_QueuedResponse> _queue = [];
  final List<RequestOptions> requests = [];

  void enqueue(int status, Map<String, Object?> body) {
    _queue.add(_QueuedResponse.success(status, body));
  }

  void enqueueError(int status, Map<String, Object?> body) {
    _queue.add(_QueuedResponse.error(status, body));
  }

  void enqueueNetworkError() {
    _queue.add(_QueuedResponse.network());
  }

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (_queue.isEmpty) {
      throw StateError('No queued response for ${options.path}');
    }
    final next = _queue.removeAt(0);
    if (next.isNetworkError) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    final payload = jsonEncode(next.body);
    if (next.statusCode >= 400) {
      throw DioException(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: next.statusCode,
          data: next.body,
          headers: Headers.fromMap({
            if (next.statusCode == 429) 'retry-after': ['3'],
          }),
        ),
        type: DioExceptionType.badResponse,
      );
    }
    return ResponseBody.fromString(
      payload,
      next.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
