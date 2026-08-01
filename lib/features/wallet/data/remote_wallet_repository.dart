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
}

void _requireStatus(ApiResponse response, int expected, String operation) {
  if (response.statusCode != expected) {
    throw FormatException(
      'The $operation response used an unsupported status.',
    );
  }
}
