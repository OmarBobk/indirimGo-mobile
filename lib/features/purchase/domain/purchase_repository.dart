import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:indirimgo_mobile/features/purchase/domain/purchase_models.dart';

abstract interface class PurchaseRepository {
  Future<CheckoutQuote> quote(
    CheckoutLineItemRequest item, {
    CancelToken? cancelToken,
  });

  Future<CheckoutResult> checkout({
    required CheckoutLineItemRequest item,
    required String quoteFingerprint,
    required String idempotencyKey,
    CancelToken? cancelToken,
  });

  Future<CheckoutStatus> checkoutStatus({
    required String idempotencyKey,
    CancelToken? cancelToken,
  });

  Future<CheckoutResult> fetchOrder(
    String orderNumber, {
    CancelToken? cancelToken,
  });
}

final purchaseRepositoryProvider = Provider<PurchaseRepository>((ref) {
  throw UnimplementedError(
    'purchaseRepositoryProvider must be overridden in main or tests.',
  );
});
