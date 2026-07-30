import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:indirimgo_mobile/core/network/api_client.dart';
import 'package:indirimgo_mobile/features/catalog/domain/catalog_models.dart';
import 'package:indirimgo_mobile/features/catalog/domain/catalog_repository.dart';

final remoteCatalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return RemoteCatalogRepository(apiClient: ref.watch(apiClientProvider));
});

class RemoteCatalogRepository implements CatalogRepository {
  const RemoteCatalogRepository({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<CatalogHome> fetchHome({CancelToken? cancelToken}) async {
    final response = await apiClient.get(
      'catalog/home',
      cancelToken: cancelToken,
    );
    _requireStatus(response, 200, 'catalog-home');
    return CatalogHome.fromJson(response.data);
  }

  @override
  Future<PackageListPage> fetchPackages(
    PackageListQuery query, {
    CancelToken? cancelToken,
  }) async {
    final response = await apiClient.get(
      'packages',
      queryParameters: query.toQueryParameters(),
      cancelToken: cancelToken,
    );
    _requireStatus(response, 200, 'package-list');
    return PackageListPage.fromJson(response.data);
  }

  @override
  Future<PackageDetailResult> fetchPackage(
    int packageId, {
    CancelToken? cancelToken,
  }) async {
    final response = await apiClient.get(
      'packages/$packageId',
      cancelToken: cancelToken,
    );
    _requireStatus(response, 200, 'package-detail');
    return PackageDetailResult.fromJson(response.data);
  }
}

void _requireStatus(ApiResponse response, int expected, String operation) {
  if (response.statusCode != expected) {
    throw FormatException(
      'The $operation response used an unsupported status.',
    );
  }
}
