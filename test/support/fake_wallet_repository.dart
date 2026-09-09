import 'package:dio/dio.dart';
import 'package:indirimgo_mobile/core/errors/api_exception.dart';
import 'package:indirimgo_mobile/features/catalog/domain/catalog_models.dart';
import 'package:indirimgo_mobile/features/wallet/domain/wallet_models.dart';
import 'package:indirimgo_mobile/features/wallet/domain/wallet_repository.dart';

import 'wallet_fixtures.dart';

class FakeWalletRepository implements WalletRepository {
  FakeWalletRepository({
    WalletSummary? summary,
    WalletTransactionPage? transactions,
    TopupListPage? topups,
    List<PaymentMethod>? paymentMethods,
  }) : summary = summary ?? WalletSummary.fromJson(walletSummaryJson()),
       transactions =
           transactions ??
           const WalletTransactionPage(
             items: [],
             pagination: OffsetPagination(
               page: 1,
               perPage: walletPageSize,
               total: 0,
               lastPage: 1,
             ),
           ),
       topups =
           topups ??
           const TopupListPage(
             items: [],
             pagination: OffsetPagination(
               page: 1,
               perPage: walletPageSize,
               total: 0,
               lastPage: 1,
             ),
           ),
       paymentMethods =
           paymentMethods ?? [PaymentMethod.fromJson(paymentMethodJson())];

  WalletSummary summary;
  Object? summaryError;
  Duration? delay;
  int summaryCalls = 0;

  WalletTransactionPage transactions;
  final Map<int, WalletTransactionPage> transactionPages = {};
  Object? transactionsError;
  int transactionCalls = 0;

  TopupListPage topups;
  final Map<int, TopupListPage> topupPages = {};
  Object? topupsError;
  int topupListCalls = 0;

  List<PaymentMethod> paymentMethods;
  Object? paymentMethodsError;
  int paymentMethodCalls = 0;

  final Map<String, TopupDetail> details = {};
  Object? detailError;
  int detailCalls = 0;

  TopupSubmitResult? submitResult;
  Object? submitError;
  int submitCalls = 0;
  String? lastAmount;
  String? lastCurrency;
  int? lastPaymentMethodId;
  String? lastIdempotencyKey;
  SelectedTopupProof? lastProof;

  TopupStatusResult? statusResult;
  Object? statusError;
  int statusCalls = 0;
  String? lastStatusKey;

  @override
  Future<WalletSummary> fetchSummary({CancelToken? cancelToken}) async {
    summaryCalls += 1;
    await _wait(cancelToken);
    if (summaryError != null) {
      throw summaryError!;
    }
    return summary;
  }

  @override
  Future<WalletTransactionPage> fetchTransactions({
    int page = 1,
    int perPage = walletPageSize,
    CancelToken? cancelToken,
  }) async {
    transactionCalls += 1;
    await _wait(cancelToken);
    if (transactionsError != null) {
      throw transactionsError!;
    }
    return transactionPages[page] ?? transactions;
  }

  @override
  Future<List<PaymentMethod>> fetchPaymentMethods({
    CancelToken? cancelToken,
  }) async {
    paymentMethodCalls += 1;
    await _wait(cancelToken);
    if (paymentMethodsError != null) {
      throw paymentMethodsError!;
    }
    return paymentMethods;
  }

  @override
  Future<TopupListPage> fetchTopups({
    int page = 1,
    int perPage = walletPageSize,
    CancelToken? cancelToken,
  }) async {
    topupListCalls += 1;
    await _wait(cancelToken);
    if (topupsError != null) {
      throw topupsError!;
    }
    return topupPages[page] ?? topups;
  }

  @override
  Future<TopupDetail> fetchTopup(
    String publicRef, {
    CancelToken? cancelToken,
  }) async {
    detailCalls += 1;
    await _wait(cancelToken);
    if (detailError != null) {
      throw detailError!;
    }
    final detail = details[publicRef];
    if (detail != null) {
      return detail;
    }
    return TopupDetail.fromJson(topupDetailJson(publicRef: publicRef));
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
    submitCalls += 1;
    lastAmount = amount;
    lastCurrency = currency;
    lastPaymentMethodId = paymentMethodId;
    lastIdempotencyKey = idempotencyKey;
    lastProof = proof;
    await _wait(cancelToken);
    if (submitError != null) {
      throw submitError!;
    }
    final result =
        submitResult ?? TopupSubmitResult.fromJson(topupSubmitSuccessJson());
    details[result.topup.publicRef] = result.topup;
    return result;
  }

  @override
  Future<TopupStatusResult> fetchTopupStatus({
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    statusCalls += 1;
    lastStatusKey = idempotencyKey;
    await _wait(cancelToken);
    if (statusError != null) {
      throw statusError!;
    }
    return statusResult ??
        TopupStatusResult.fromResponse(
          statusCode: 200,
          json: topupStatusCompletedJson(),
        );
  }

  Future<void> _wait(CancelToken? cancelToken) async {
    if (delay != null) {
      await Future<void>.delayed(delay!);
    }
    if (cancelToken?.isCancelled ?? false) {
      throw const ApiException(kind: ApiErrorKind.cancelled);
    }
  }
}
