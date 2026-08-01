import 'package:dio/dio.dart';
import 'package:indirimgo_mobile/core/errors/api_exception.dart';
import 'package:indirimgo_mobile/features/purchase/domain/purchase_models.dart';
import 'package:indirimgo_mobile/features/purchase/domain/purchase_repository.dart';

import 'purchase_fixtures.dart';

class FakePurchaseRepository implements PurchaseRepository {
  FakePurchaseRepository({
    CheckoutQuote? quote,
    CheckoutResult? checkoutResult,
    CheckoutStatus? status,
    CheckoutResult? orderResult,
  }) : quoteResult = quote ?? sampleCheckoutQuote,
       checkoutResult = checkoutResult ?? sampleCheckoutResult,
       statusResult =
           status ??
           CheckoutStatus.fromResponse(
             statusCode: 200,
             json: checkoutStatusCompletedJson(),
           ),
       orderResult = orderResult ?? sampleCheckoutResult;

  CheckoutQuote quoteResult;
  CheckoutResult checkoutResult;
  CheckoutStatus statusResult;
  CheckoutResult orderResult;

  Object? quoteError;
  Object? checkoutError;
  Object? statusError;
  Object? orderError;

  Duration? quoteDelay;
  Duration? checkoutDelay;
  Duration? statusDelay;

  int quoteCalls = 0;
  int checkoutCalls = 0;
  int statusCalls = 0;
  int orderCalls = 0;

  final List<CheckoutLineItemRequest> quoteItems = [];
  final List<String> checkoutKeys = [];
  final List<String> statusKeys = [];
  final List<Map<String, Object?>> checkoutPayloads = [];

  Future<CheckoutQuote> Function(CheckoutLineItemRequest item)? quoteHandler;
  Future<CheckoutResult> Function({
    required CheckoutLineItemRequest item,
    required String quoteFingerprint,
    required String idempotencyKey,
  })?
  checkoutHandler;

  @override
  Future<CheckoutQuote> quote(
    CheckoutLineItemRequest item, {
    CancelToken? cancelToken,
  }) async {
    quoteCalls += 1;
    quoteItems.add(item);
    if (quoteDelay != null) {
      await Future<void>.delayed(quoteDelay!);
    }
    _throwIfCancelled(cancelToken);
    if (quoteError != null) {
      throw quoteError!;
    }
    if (quoteHandler != null) {
      return quoteHandler!(item);
    }
    return quoteResult;
  }

  @override
  Future<CheckoutResult> checkout({
    required CheckoutLineItemRequest item,
    required String quoteFingerprint,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    checkoutCalls += 1;
    checkoutKeys.add(idempotencyKey);
    checkoutPayloads.add({
      'product_id': item.productId,
      'has_fingerprint': quoteFingerprint.isNotEmpty,
      'item_count': 1,
    });
    if (checkoutDelay != null) {
      await Future<void>.delayed(checkoutDelay!);
    }
    _throwIfCancelled(cancelToken);
    if (checkoutError != null) {
      throw checkoutError!;
    }
    if (checkoutHandler != null) {
      return checkoutHandler!(
        item: item,
        quoteFingerprint: quoteFingerprint,
        idempotencyKey: idempotencyKey,
      );
    }
    return checkoutResult;
  }

  @override
  Future<CheckoutStatus> checkoutStatus({
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    statusCalls += 1;
    statusKeys.add(idempotencyKey);
    if (statusDelay != null) {
      await Future<void>.delayed(statusDelay!);
    }
    _throwIfCancelled(cancelToken);
    if (statusError != null) {
      throw statusError!;
    }
    return statusResult;
  }

  @override
  Future<CheckoutResult> fetchOrder(
    String orderNumber, {
    CancelToken? cancelToken,
  }) async {
    orderCalls += 1;
    _throwIfCancelled(cancelToken);
    if (orderError != null) {
      throw orderError!;
    }
    return orderResult;
  }

  void _throwIfCancelled(CancelToken? cancelToken) {
    if (cancelToken?.isCancelled ?? false) {
      throw const ApiException(kind: ApiErrorKind.cancelled);
    }
  }
}
