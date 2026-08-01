import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:indirimgo_mobile/features/wallet/domain/wallet_models.dart';

abstract interface class WalletRepository {
  Future<WalletSummary> fetchSummary({CancelToken? cancelToken});
}

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  throw UnimplementedError(
    'walletRepositoryProvider must be overridden in main or tests.',
  );
});
