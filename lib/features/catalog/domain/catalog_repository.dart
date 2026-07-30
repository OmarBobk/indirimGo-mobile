import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:indirimgo_mobile/features/catalog/domain/catalog_models.dart';

abstract interface class CatalogRepository {
  Future<CatalogHome> fetchHome({CancelToken? cancelToken});

  Future<PackageListPage> fetchPackages(
    PackageListQuery query, {
    CancelToken? cancelToken,
  });

  Future<PackageDetailResult> fetchPackage(
    int packageId, {
    CancelToken? cancelToken,
  });
}

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  throw UnimplementedError(
    'catalogRepositoryProvider must be overridden in main or tests.',
  );
});
