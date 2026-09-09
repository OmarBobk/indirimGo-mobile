import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:indirimgo_mobile/core/network/api_client.dart';
import 'package:indirimgo_mobile/features/wallet/domain/wallet_models.dart';
import 'package:indirimgo_mobile/features/wallet/domain/wallet_repository.dart';

final remoteWalletRepositoryProvider = Provider<WalletRepository>((ref) {
  return RemoteWalletRepository(apiClient: ref.watch(apiClientProvider));
});

class RemoteWalletRepository implements WalletRepository {
  RemoteWalletRepository({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<WalletSummary> fetchSummary({CancelToken? cancelToken}) async {
    final response = await apiClient.get(
      'wallet/summary',
      cancelToken: cancelToken,
    );
    _requireStatus(response, 200, 'wallet-summary');
    return WalletSummary.fromJson(response.data);
  }

  @override
  Future<WalletTransactionPage> fetchTransactions({
    int page = 1,
    int perPage = walletPageSize,
    CancelToken? cancelToken,
  }) async {
    final response = await apiClient.get(
      'wallet/transactions',
      queryParameters: {'page': page, 'per_page': perPage},
      cancelToken: cancelToken,
    );
    _requireStatus(response, 200, 'wallet-transactions');
    return WalletTransactionPage.fromJson(response.data);
  }

  @override
  Future<List<PaymentMethod>> fetchPaymentMethods({
    CancelToken? cancelToken,
  }) async {
    final response = await apiClient.get(
      'wallet/payment-methods',
      cancelToken: cancelToken,
    );
    _requireStatus(response, 200, 'wallet-payment-methods');
    final data = response.data['data'];
    if (data is! List) {
      throw const FormatException('Payment methods data must be a list.');
    }
    return [
      for (final item in data)
        PaymentMethod.fromJson(_asObjectMap(item, 'payment_method')),
    ];
  }

  @override
  Future<TopupListPage> fetchTopups({
    int page = 1,
    int perPage = walletPageSize,
    CancelToken? cancelToken,
  }) async {
    final response = await apiClient.get(
      'wallet/topups',
      queryParameters: {'page': page, 'per_page': perPage},
      cancelToken: cancelToken,
    );
    _requireStatus(response, 200, 'wallet-topups');
    return TopupListPage.fromJson(response.data);
  }

  @override
  Future<TopupDetail> fetchTopup(
    String publicRef, {
    CancelToken? cancelToken,
  }) async {
    final response = await apiClient.get(
      'wallet/topups/$publicRef',
      cancelToken: cancelToken,
    );
    _requireStatus(response, 200, 'wallet-topup-detail');
    final data = response.data['data'];
    return TopupDetail.fromJson(_asObjectMap(data, 'data'));
  }

  @override
  Future<TopupSubmitResult> submitTopup({
    required String amount,
    required String currency,
    required int paymentMethodId,
    required String idempotencyKey,
    SelectedTopupProof? proof,
    CancelToken? cancelToken,
  }) async {
    final fields = <String, String>{
      'amount': amount,
      'currency': currency,
      'payment_method_id': '$paymentMethodId',
    };
    MultipartFile? proofFile;
    final selected = proof;
    if (selected != null) {
      if (selected.bytes != null) {
        proofFile = MultipartFile.fromBytes(
          selected.bytes!,
          filename: selected.filename,
        );
      } else if (selected.path != null && selected.path!.isNotEmpty) {
        proofFile = await MultipartFile.fromFile(
          selected.path!,
          filename: selected.filename,
        );
      }
    }
    final response = await apiClient.postMultipart(
      'wallet/topups',
      fields: fields,
      files: {if (proofFile != null) 'proof': proofFile},
      headers: {'Idempotency-Key': idempotencyKey},
      cancelToken: cancelToken,
    );
    if (response.statusCode != 200) {
      throw FormatException(
        'The wallet-topup-submit response used an unsupported status.',
      );
    }
    return TopupSubmitResult.fromJson(response.data);
  }

  @override
  Future<TopupStatusResult> fetchTopupStatus({
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    final response = await apiClient.get(
      'wallet/topups/status',
      headers: {'Idempotency-Key': idempotencyKey},
      cancelToken: cancelToken,
    );
    if (response.statusCode != 200 && response.statusCode != 202) {
      throw const FormatException(
        'The wallet-topup-status response used an unsupported status.',
      );
    }
    return TopupStatusResult.fromResponse(
      statusCode: response.statusCode,
      json: response.data,
    );
  }
}

void _requireStatus(ApiResponse response, int expected, String operation) {
  if (response.statusCode != expected) {
    throw FormatException(
      'The $operation response used an unsupported status.',
    );
  }
}

Map<String, Object?> _asObjectMap(Object? value, String label) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((mapKey, mapValue) => MapEntry('$mapKey', mapValue));
  }
  throw FormatException('$label must be an object.');
}
