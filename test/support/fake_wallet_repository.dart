import 'package:dio/dio.dart';
import 'package:indirimgo_mobile/core/errors/api_exception.dart';
import 'package:indirimgo_mobile/features/wallet/domain/wallet_models.dart';
import 'package:indirimgo_mobile/features/wallet/domain/wallet_repository.dart';

import 'purchase_fixtures.dart';

class FakeWalletRepository implements WalletRepository {
  FakeWalletRepository({WalletSummary? summary})
    : summary = summary ?? WalletSummary.fromJson(walletSummaryJson());

  WalletSummary summary;
  Object? summaryError;
  Duration? delay;
  int summaryCalls = 0;

  @override
  Future<WalletSummary> fetchSummary({CancelToken? cancelToken}) async {
    summaryCalls += 1;
    if (delay != null) {
      await Future<void>.delayed(delay!);
    }
    if (cancelToken?.isCancelled ?? false) {
      throw const ApiException(kind: ApiErrorKind.cancelled);
    }
    if (summaryError != null) {
      throw summaryError!;
    }
    return summary;
  }
}
