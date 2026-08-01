import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:indirimgo_mobile/core/errors/api_exception.dart';
import 'package:indirimgo_mobile/core/network/api_client.dart';
import 'package:indirimgo_mobile/features/purchase/domain/purchase_models.dart';
import 'package:indirimgo_mobile/features/purchase/domain/purchase_repository.dart';

final remotePurchaseRepositoryProvider = Provider<PurchaseRepository>((ref) {
  return RemotePurchaseRepository(apiClient: ref.watch(apiClientProvider));
});

class RemotePurchaseRepository implements PurchaseRepository {
  RemotePurchaseRepository({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<CheckoutQuote> quote(
    CheckoutLineItemRequest item, {
    CancelToken? cancelToken,
  }) async {
    final response = await apiClient.post(
      'checkout/quote',
      data: {
        'items': [item.toJson()],
      },
      cancelToken: cancelToken,
    );
    _requireStatus(response, 200, 'checkout-quote');
    return CheckoutQuote.fromSuccessJson(response.data);
  }

  @override
  Future<CheckoutResult> checkout({
    required CheckoutLineItemRequest item,
    required String quoteFingerprint,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    final response = await apiClient.post(
      'checkout',
      data: {
        'items': [item.toJson()],
        'quote_fingerprint': quoteFingerprint,
      },
      headers: {'Idempotency-Key': idempotencyKey},
      cancelToken: cancelToken,
    );
    if (response.statusCode == 202) {
      throw ApiException(
        kind: ApiErrorKind.conflict,
        code: _codeFromBody(response.data) ?? 'checkout_in_progress',
        statusCode: 202,
        requestSession: response.requestSession,
      );
    }
    _requireStatus(response, 200, 'checkout');
    return CheckoutResult.fromJson(response.data);
  }

  @override
  Future<CheckoutStatus> checkoutStatus({
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    final response = await apiClient.get(
      'checkout/status',
      headers: {'Idempotency-Key': idempotencyKey},
      cancelToken: cancelToken,
    );
    if (response.statusCode == 200 || response.statusCode == 202) {
      return CheckoutStatus.fromResponse(
        statusCode: response.statusCode,
        json: response.data,
      );
    }
    throw FormatException(
      'The checkout-status response used an unsupported status.',
    );
  }

  @override
  Future<CheckoutResult> fetchOrder(
    String orderNumber, {
    CancelToken? cancelToken,
  }) async {
    final response = await apiClient.get(
      'orders/$orderNumber',
      cancelToken: cancelToken,
    );
    _requireStatus(response, 200, 'order-show');
    return CheckoutResult.fromJson(response.data);
  }
}

void _requireStatus(ApiResponse response, int expected, String operation) {
  if (response.statusCode != expected) {
    throw FormatException(
      'The $operation response used an unsupported status.',
    );
  }
}

String? _codeFromBody(Map<String, Object?> body) {
  final code = body['code'];
  return code is String && stableApiErrorCodes.contains(code) ? code : null;
}
