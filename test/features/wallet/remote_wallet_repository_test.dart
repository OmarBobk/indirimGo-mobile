import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indirimgo_mobile/core/config/app_config.dart';
import 'package:indirimgo_mobile/core/network/api_client.dart';
import 'package:indirimgo_mobile/core/storage/token_storage.dart';
import 'package:indirimgo_mobile/features/wallet/data/remote_wallet_repository.dart';
import 'package:indirimgo_mobile/features/wallet/domain/wallet_models.dart';

import '../../support/fakes.dart';
import '../../support/wallet_fixtures.dart';

void main() {
  late InMemoryTokenStorage storage;
  late _QueueAdapter adapter;
  late RemoteWalletRepository wallet;

  setUp(() {
    storage = InMemoryTokenStorage(sampleStoredSession());
    adapter = _QueueAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1/'));
    dio.httpClientAdapter = adapter;
    wallet = RemoteWalletRepository(
      apiClient: ApiClient(
        config: AppConfig(
          apiBaseUrl: 'https://api.example.test/api/v1',
          buildMode: AppBuildMode.release,
        ),
        tokenStorage: storage,
        locale: 'ar',
        dio: dio,
      ),
    );
  });

  test('reads summary, history, methods and owned detail', () async {
    adapter.enqueue(
      200,
      walletSummaryJson(pendingTopupPublicRef: 'TUP-ABC123'),
    );
    adapter.enqueue(200, walletTransactionPageJson());
    adapter.enqueue(200, paymentMethodListJson());
    adapter.enqueue(
      200,
      topupListPageJson(pendingTopupPublicRef: 'TUP-ABC123'),
    );
    adapter.enqueue(200, topupDetailSuccessJson());

    final summary = await wallet.fetchSummary();
    expect(summary.pendingTopupPublicRef, 'TUP-ABC123');
    expect(adapter.requests[0].path, 'wallet/summary');

    final transactions = await wallet.fetchTransactions();
    expect(transactions.items.single.amount.amount, '25.00');
    expect(adapter.requests[1].path, 'wallet/transactions');

    final methods = await wallet.fetchPaymentMethods();
    expect(methods.single.id, 11);
    expect(adapter.requests[2].path, 'wallet/payment-methods');

    final topups = await wallet.fetchTopups();
    expect(topups.items.single.credited, isFalse);
    expect(adapter.requests[3].path, 'wallet/topups');

    final detail = await wallet.fetchTopup('TUP-ABC123');
    expect(detail.publicRef, 'TUP-ABC123');
    expect(adapter.requests[4].path, 'wallet/topups/TUP-ABC123');
  });

  test(
    'submit posts multipart with explicit currency and idempotency key',
    () async {
      adapter.enqueue(200, topupSubmitSuccessJson());
      final result = await wallet.submitTopup(
        amount: '100.00',
        currency: 'TRY',
        paymentMethodId: 11,
        idempotencyKey: 'ig-topup-key',
        proof: const SelectedTopupProof(
          filename: 'receipt.pdf',
          bytes: [1, 2, 3],
        ),
      );
      expect(result.pendingUntilAdminApproval, isTrue);
      expect(result.topup.credited, isFalse);
      final request = adapter.requests.single;
      expect(request.path, 'wallet/topups');
      expect(request.method, 'POST');
      expect(request.headers['Idempotency-Key'], 'ig-topup-key');
      expect(request.data, isA<FormData>());
      final form = request.data! as FormData;
      final fields = {for (final field in form.fields) field.key: field.value};
      expect(fields['amount'], '100.00');
      expect(fields['currency'], 'TRY');
      expect(fields['payment_method_id'], '11');
      expect(form.files.single.key, 'proof');
    },
  );

  test('status recovery uses the same idempotency header', () async {
    adapter.enqueue(200, topupStatusCompletedJson());
    final status = await wallet.fetchTopupStatus(idempotencyKey: 'ig-status');
    expect(status.state, TopupStatusState.completed);
    expect(status.topup?.pendingUntilAdminApproval, isTrue);
    expect(adapter.requests.single.path, 'wallet/topups/status');
    expect(adapter.requests.single.headers['Idempotency-Key'], 'ig-status');
  });
}

class _QueuedResponse {
  _QueuedResponse.success(this.statusCode, this.body);

  final int statusCode;
  final Map<String, Object?> body;
}

class _QueueAdapter implements HttpClientAdapter {
  final List<_QueuedResponse> _queue = [];
  final List<RequestOptions> requests = [];

  void enqueue(int status, Map<String, Object?> body) {
    _queue.add(_QueuedResponse.success(status, body));
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
    return ResponseBody.fromString(
      jsonEncode(next.body),
      next.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
