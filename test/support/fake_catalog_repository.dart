import 'package:dio/dio.dart';
import 'package:indirimgo_mobile/core/errors/api_exception.dart';
import 'package:indirimgo_mobile/features/catalog/domain/catalog_models.dart';
import 'package:indirimgo_mobile/features/catalog/domain/catalog_repository.dart';

import 'catalog_fixtures.dart';

class FakeCatalogRepository implements CatalogRepository {
  FakeCatalogRepository({
    CatalogHome? home,
    List<PackageSummary>? packages,
    PackageDetailResult? detail,
  }) : home = home ?? sampleCatalogHome,
       packages = packages ?? samplePackageSummaries,
       detail = detail ?? samplePackageDetailResult;

  CatalogHome home;
  List<PackageSummary> packages;
  PackageDetailResult detail;

  Object? homeError;
  Object? listError;
  Object? detailError;
  Object? loadMoreError;

  Duration? homeDelay;
  Duration? listDelay;
  Duration? detailDelay;

  int homeCalls = 0;
  int listCalls = 0;
  int detailCalls = 0;
  final List<PackageListQuery> listQueries = [];
  final List<int> detailIds = [];
  final List<CancelToken?> homeTokens = [];
  final List<CancelToken?> listTokens = [];

  /// When set, [fetchPackages] returns this page for page > 1.
  PackageListPage? nextPage;

  @override
  Future<CatalogHome> fetchHome({CancelToken? cancelToken}) async {
    homeCalls += 1;
    homeTokens.add(cancelToken);
    if (homeDelay != null) {
      await Future<void>.delayed(homeDelay!);
    }
    _throwIfCancelled(cancelToken);
    if (homeError case final error?) {
      throw error;
    }
    return home;
  }

  @override
  Future<PackageListPage> fetchPackages(
    PackageListQuery query, {
    CancelToken? cancelToken,
  }) async {
    listCalls += 1;
    listQueries.add(query);
    listTokens.add(cancelToken);
    if (listDelay != null) {
      await Future<void>.delayed(listDelay!);
    }
    _throwIfCancelled(cancelToken);
    if (query.page > 1) {
      if (loadMoreError case final error?) {
        throw error;
      }
      return nextPage ??
          PackageListPage(
            packages: const [],
            pricesVisible: home.pricesVisible,
            pagination: OffsetPagination(
              page: query.page,
              perPage: query.perPage,
              total: packages.length,
              lastPage: query.page,
            ),
          );
    }
    if (listError case final error?) {
      throw error;
    }

    var filtered = List<PackageSummary>.from(packages);
    if (query.categoryId != null) {
      filtered = [
        for (final item in filtered)
          if (item.category?.id == query.categoryId) item,
      ];
    }
    if (query.q != null) {
      final needle = query.q!.toLowerCase();
      filtered = [
        for (final item in filtered)
          if (item.name.toLowerCase().contains(needle)) item,
      ];
    }
    final lastPage = filtered.isEmpty
        ? 1
        : ((filtered.length - 1) ~/ query.perPage) + 1;
    final start = (query.page - 1) * query.perPage;
    final end = (start + query.perPage).clamp(0, filtered.length);
    final slice = start >= filtered.length
        ? <PackageSummary>[]
        : filtered.sublist(start, end);
    return PackageListPage(
      packages: slice,
      pricesVisible: home.pricesVisible,
      pagination: OffsetPagination(
        page: query.page,
        perPage: query.perPage,
        total: filtered.length,
        lastPage: lastPage,
      ),
    );
  }

  @override
  Future<PackageDetailResult> fetchPackage(
    int packageId, {
    CancelToken? cancelToken,
  }) async {
    detailCalls += 1;
    detailIds.add(packageId);
    if (detailDelay != null) {
      await Future<void>.delayed(detailDelay!);
    }
    _throwIfCancelled(cancelToken);
    if (detailError case final error?) {
      throw error;
    }
    if (packageId != detail.package.id) {
      throw const ApiException(
        kind: ApiErrorKind.notFound,
        code: 'package_not_found',
        statusCode: 404,
      );
    }
    return detail;
  }

  void _throwIfCancelled(CancelToken? cancelToken) {
    if (cancelToken != null && cancelToken.isCancelled) {
      throw const ApiException(kind: ApiErrorKind.cancelled);
    }
  }
}
