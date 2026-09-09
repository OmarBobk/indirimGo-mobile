import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:indirimgo_mobile/features/wallet/domain/wallet_models.dart';

abstract interface class WalletRepository {
  Future<WalletSummary> fetchSummary({CancelToken? cancelToken});

  Future<WalletTransactionPage> fetchTransactions({
    int page = 1,
    int perPage = walletPageSize,
    CancelToken? cancelToken,
  });

  Future<List<PaymentMethod>> fetchPaymentMethods({CancelToken? cancelToken});

  Future<TopupListPage> fetchTopups({
    int page = 1,
    int perPage = walletPageSize,
    CancelToken? cancelToken,
  });

  Future<TopupDetail> fetchTopup(String publicRef, {CancelToken? cancelToken});

  Future<TopupSubmitResult> submitTopup({
    required String amount,
    required String currency,
    required int paymentMethodId,
    required String idempotencyKey,
    SelectedTopupProof? proof,
    CancelToken? cancelToken,
  });

  Future<TopupStatusResult> fetchTopupStatus({
    required String idempotencyKey,
    CancelToken? cancelToken,
  });
}

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  throw UnimplementedError(
    'walletRepositoryProvider must be overridden in main or tests.',
  );
});
