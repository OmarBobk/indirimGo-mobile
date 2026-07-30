import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:indirimgo_mobile/core/errors/api_exception.dart';
import 'package:indirimgo_mobile/features/auth/presentation/auth_controller.dart';
import 'package:indirimgo_mobile/features/catalog/domain/catalog_models.dart';
import 'package:indirimgo_mobile/features/catalog/domain/catalog_repository.dart';

/// OpenAPI `q` maximum length (Unicode code points).
const catalogSearchQueryMaxLength = 100;

/// Clamps user or programmatic search input to the OpenAPI maximum.
///
/// Typed input is also bounded by [LengthLimitingTextInputFormatter] /
/// `TextField.maxLength`, which enforce grapheme clusters in the UI layer.
String clampCatalogSearchInput(String value) {
  final runes = value.runes;
  if (runes.length <= catalogSearchQueryMaxLength) {
    return value;
  }
  return String.fromCharCodes(runes.take(catalogSearchQueryMaxLength));
}

/// Customer id currently owning personalized catalog state, or null.
///
/// Null whenever auth is not fully [AuthPhase.authenticated] so logout,
/// session rejection, and customer switches clear catalog immediately.
final catalogCustomerIdProvider = Provider<int?>((ref) {
  final auth = ref.watch(authControllerProvider);
  if (auth.phase != AuthPhase.authenticated) {
    return null;
  }
  return auth.user?.id;
});

enum CatalogLoadPhase { idle, loading, refreshing, ready, empty, error }

class CatalogHomeState {
  const CatalogHomeState({
    required this.phase,
    this.home,
    this.error,
    this.customerId,
  });

  const CatalogHomeState.initial()
    : this(phase: CatalogLoadPhase.idle, customerId: null);

  final CatalogLoadPhase phase;
  final CatalogHome? home;
  final ApiException? error;
  final int? customerId;

  bool get hasContent => home != null;
}

final catalogHomeControllerProvider =
    NotifierProvider<CatalogHomeController, CatalogHomeState>(
      CatalogHomeController.new,
    );

class CatalogHomeController extends Notifier<CatalogHomeState> {
  CatalogRepository get _repository => ref.read(catalogRepositoryProvider);

  int _epoch = 0;
  CancelToken? _cancelToken;
  bool _disposed = false;

  @override
  CatalogHomeState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _epoch += 1;
      _cancelToken?.cancel('dispose');
      _cancelToken = null;
    });

    ref.listen<int?>(catalogCustomerIdProvider, (previous, next) {
      if (previous == next) {
        return;
      }
      _cancelInFlight();
      if (next == null) {
        state = const CatalogHomeState.initial();
        return;
      }
      state = CatalogHomeState(
        phase: CatalogLoadPhase.loading,
        customerId: next,
      );
      unawaited(load());
    });

    final customerId = ref.read(catalogCustomerIdProvider);
    if (customerId == null) {
      return const CatalogHomeState.initial();
    }
    scheduleMicrotask(() {
      if (!_disposed) {
        unawaited(load());
      }
    });
    return CatalogHomeState(
      phase: CatalogLoadPhase.loading,
      customerId: customerId,
    );
  }

  Future<void> load({bool refresh = false}) async {
    final customerId = ref.read(catalogCustomerIdProvider);
    if (customerId == null) {
      state = const CatalogHomeState.initial();
      return;
    }
    if (!refresh && _cancelToken != null && !_cancelToken!.isCancelled) {
      return;
    }

    final operation = ++_epoch;
    _cancelToken?.cancel('superseded');
    final token = CancelToken();
    _cancelToken = token;

    final keep = refresh ? state.home : null;
    state = CatalogHomeState(
      phase: refresh && keep != null
          ? CatalogLoadPhase.refreshing
          : CatalogLoadPhase.loading,
      home: keep,
      customerId: customerId,
    );

    try {
      final home = await _repository.fetchHome(cancelToken: token);
      if (!_isCurrent(operation, customerId)) {
        return;
      }
      state = CatalogHomeState(
        phase: CatalogLoadPhase.ready,
        home: home,
        customerId: customerId,
      );
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.cancelled) {
        return;
      }
      if (await _applyAuthoritativeRejection(error)) {
        if (_isCurrent(operation, customerId) ||
            ref.read(catalogCustomerIdProvider) == null) {
          state = const CatalogHomeState.initial();
        }
        return;
      }
      if (!_isCurrent(operation, customerId)) {
        return;
      }
      state = CatalogHomeState(
        phase: CatalogLoadPhase.error,
        home: keep,
        error: error,
        customerId: customerId,
      );
    } on Object {
      if (!_isCurrent(operation, customerId)) {
        return;
      }
      state = CatalogHomeState(
        phase: CatalogLoadPhase.error,
        home: keep,
        error: const ApiException(kind: ApiErrorKind.unknown),
        customerId: customerId,
      );
    } finally {
      if (identical(_cancelToken, token)) {
        _cancelToken = null;
      }
    }
  }

  Future<void> refresh() => load(refresh: true);

  Future<void> retry() => load();

  Future<bool> _applyAuthoritativeRejection(ApiException error) async {
    if (!error.isAuthoritativeSessionRejection) {
      return false;
    }
    return ref
        .read(authControllerProvider.notifier)
        .applyAuthoritativeRejection(error);
  }

  bool _isCurrent(int operation, int customerId) {
    return !_disposed &&
        operation == _epoch &&
        ref.read(catalogCustomerIdProvider) == customerId;
  }

  void _cancelInFlight() {
    _epoch += 1;
    _cancelToken?.cancel('customer-switch');
    _cancelToken = null;
  }
}

enum PackageListPhase {
  idle,
  loading,
  refreshing,
  loadingMore,
  ready,
  empty,
  error,
}

class PackageListState {
  const PackageListState({
    required this.phase,
    required this.query,
    this.packages = const [],
    this.pricesVisible = true,
    this.pagination,
    this.error,
    this.loadMoreError,
    this.customerId,
    this.searchInput = '',
    this.categoryName,
  });

  PackageListState.initial({int? categoryId, String? q, String? categoryName})
    : this(
        phase: PackageListPhase.idle,
        query: PackageListQuery(categoryId: categoryId, q: q),
        searchInput: q ?? '',
        categoryName: categoryId != null ? categoryName : null,
      );

  final PackageListPhase phase;
  final PackageListQuery query;
  final List<PackageSummary> packages;
  final bool pricesVisible;
  final OffsetPagination? pagination;
  final ApiException? error;
  final ApiException? loadMoreError;
  final int? customerId;
  final String searchInput;

  /// Server category name for the active filter chip, when known.
  final String? categoryName;

  bool get canLoadMore =>
      pagination != null &&
      pagination!.hasNextPage &&
      phase != PackageListPhase.loadingMore &&
      phase != PackageListPhase.loading &&
      phase != PackageListPhase.refreshing;

  bool get hasContent => packages.isNotEmpty;
}

final packageListControllerProvider =
    NotifierProvider<PackageListController, PackageListState>(
      PackageListController.new,
    );

class PackageListController extends Notifier<PackageListState> {
  CatalogRepository get _repository => ref.read(catalogRepositoryProvider);

  int _epoch = 0;
  CancelToken? _cancelToken;
  Timer? _debounce;
  bool _disposed = false;
  bool _loadMoreInFlight = false;

  @override
  PackageListState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _epoch += 1;
      _debounce?.cancel();
      _cancelToken?.cancel('dispose');
      _cancelToken = null;
    });

    ref.listen<int?>(catalogCustomerIdProvider, (previous, next) {
      if (previous == next) {
        return;
      }
      _cancelInFlight();
      if (next == null) {
        state = PackageListState.initial();
        return;
      }
      state = PackageListState(
        phase: PackageListPhase.loading,
        query: state.query.copyWith(page: 1),
        searchInput: state.searchInput,
        categoryName: state.categoryName,
        customerId: next,
      );
      unawaited(_fetch(reset: true));
    });

    return PackageListState.initial();
  }

  /// Applies route/query bootstrap once (category + optional search).
  void bootstrap({int? categoryId, String? q, String? categoryName}) {
    final customerId = ref.read(catalogCustomerIdProvider);
    final trimmed = q == null ? null : clampCatalogSearchInput(q).trim();
    final nextQuery = PackageListQuery(
      categoryId: categoryId,
      q: (trimmed != null && trimmed.length >= 2) ? trimmed : null,
    );
    final resolvedName = categoryId != null ? categoryName : null;
    final sameFilters =
        state.query.categoryId == nextQuery.categoryId &&
        state.query.q == nextQuery.q &&
        state.customerId == customerId &&
        state.categoryName == resolvedName &&
        state.hasContent;
    if (sameFilters) {
      return;
    }
    state = PackageListState(
      phase: PackageListPhase.loading,
      query: nextQuery,
      searchInput: trimmed ?? '',
      categoryName: resolvedName,
      customerId: customerId,
    );
    unawaited(_fetch(reset: true));
  }

  void onSearchChanged(String value) {
    final clamped = clampCatalogSearchInput(value);
    state = PackageListState(
      phase: state.phase,
      query: state.query,
      packages: state.packages,
      pricesVisible: state.pricesVisible,
      pagination: state.pagination,
      error: state.error,
      loadMoreError: state.loadMoreError,
      customerId: state.customerId,
      searchInput: clamped,
      categoryName: state.categoryName,
    );
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      submitSearch(clamped, fromDebounce: true);
    });
  }

  void submitSearch(String value, {bool fromDebounce = false}) {
    if (!fromDebounce) {
      _debounce?.cancel();
    }
    final clamped = clampCatalogSearchInput(value);
    final trimmed = clamped.trim();
    if (trimmed.length == 1) {
      // Do not request for a single character; keep current query/results.
      state = PackageListState(
        phase: state.phase,
        query: state.query,
        packages: state.packages,
        pricesVisible: state.pricesVisible,
        pagination: state.pagination,
        error: state.error,
        loadMoreError: state.loadMoreError,
        customerId: state.customerId,
        searchInput: clamped,
        categoryName: state.categoryName,
      );
      return;
    }
    final nextQ = trimmed.isEmpty ? null : trimmed;
    if (state.query.q == nextQ && state.hasContent) {
      return;
    }
    state = PackageListState(
      phase: PackageListPhase.loading,
      query: state.query.copyWith(q: nextQ, clearQ: nextQ == null, page: 1),
      searchInput: clamped,
      categoryName: state.categoryName,
      customerId: ref.read(catalogCustomerIdProvider),
    );
    unawaited(_fetch(reset: true));
  }

  void setCategory(int? categoryId, {String? categoryName}) {
    if (state.query.categoryId == categoryId && state.hasContent) {
      return;
    }
    state = PackageListState(
      phase: PackageListPhase.loading,
      query: state.query.copyWith(
        categoryId: categoryId,
        clearCategoryId: categoryId == null,
        page: 1,
      ),
      searchInput: state.searchInput,
      categoryName: categoryId != null ? categoryName : null,
      customerId: ref.read(catalogCustomerIdProvider),
    );
    unawaited(_fetch(reset: true));
  }

  void clearCategory() => setCategory(null);

  Future<void> refresh() async {
    if (state.phase == PackageListPhase.loading ||
        state.phase == PackageListPhase.refreshing) {
      return;
    }
    state = PackageListState(
      phase: state.hasContent
          ? PackageListPhase.refreshing
          : PackageListPhase.loading,
      query: state.query.copyWith(page: 1),
      packages: state.packages,
      pricesVisible: state.pricesVisible,
      pagination: state.pagination,
      searchInput: state.searchInput,
      categoryName: state.categoryName,
      customerId: ref.read(catalogCustomerIdProvider),
    );
    await _fetch(reset: true, preserveOnError: true);
  }

  Future<void> retry() async {
    state = PackageListState(
      phase: PackageListPhase.loading,
      query: state.query.copyWith(page: 1),
      searchInput: state.searchInput,
      categoryName: state.categoryName,
      customerId: ref.read(catalogCustomerIdProvider),
    );
    await _fetch(reset: true);
  }

  Future<void> loadMore() async {
    if (!state.canLoadMore || _loadMoreInFlight) {
      return;
    }
    final pagination = state.pagination;
    if (pagination == null) {
      return;
    }
    _loadMoreInFlight = true;
    final customerId = ref.read(catalogCustomerIdProvider);
    final operation = ++_epoch;
    _cancelToken?.cancel('superseded');
    final token = CancelToken();
    _cancelToken = token;

    final nextPage = pagination.page + 1;
    state = PackageListState(
      phase: PackageListPhase.loadingMore,
      query: state.query.copyWith(page: nextPage),
      packages: state.packages,
      pricesVisible: state.pricesVisible,
      pagination: state.pagination,
      searchInput: state.searchInput,
      categoryName: state.categoryName,
      customerId: customerId,
    );

    try {
      final page = await _repository.fetchPackages(
        state.query,
        cancelToken: token,
      );
      if (!_isCurrent(operation, customerId)) {
        return;
      }
      final existingIds = {for (final item in state.packages) item.id};
      final appended = [
        ...state.packages,
        for (final item in page.packages)
          if (!existingIds.contains(item.id)) item,
      ];
      state = PackageListState(
        phase: appended.isEmpty
            ? PackageListPhase.empty
            : PackageListPhase.ready,
        query: state.query.copyWith(page: page.pagination.page),
        packages: appended,
        pricesVisible: page.pricesVisible,
        pagination: page.pagination,
        searchInput: state.searchInput,
        categoryName: state.categoryName,
        customerId: customerId,
      );
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.cancelled) {
        return;
      }
      if (await _applyAuthoritativeRejection(error)) {
        if (_isCurrent(operation, customerId) ||
            ref.read(catalogCustomerIdProvider) == null) {
          state = PackageListState.initial(
            categoryId: state.query.categoryId,
            q: state.query.q,
            categoryName: state.categoryName,
          );
        }
        return;
      }
      if (!_isCurrent(operation, customerId)) {
        return;
      }
      state = PackageListState(
        phase: PackageListPhase.ready,
        query: state.query.copyWith(page: pagination.page),
        packages: state.packages,
        pricesVisible: state.pricesVisible,
        pagination: pagination,
        loadMoreError: error,
        searchInput: state.searchInput,
        categoryName: state.categoryName,
        customerId: customerId,
      );
    } on Object {
      if (!_isCurrent(operation, customerId)) {
        return;
      }
      state = PackageListState(
        phase: PackageListPhase.ready,
        query: state.query.copyWith(page: pagination.page),
        packages: state.packages,
        pricesVisible: state.pricesVisible,
        pagination: pagination,
        loadMoreError: const ApiException(kind: ApiErrorKind.unknown),
        searchInput: state.searchInput,
        categoryName: state.categoryName,
        customerId: customerId,
      );
    } finally {
      _loadMoreInFlight = false;
      if (identical(_cancelToken, token)) {
        _cancelToken = null;
      }
    }
  }

  Future<void> retryLoadMore() => loadMore();

  Future<void> _fetch({
    required bool reset,
    bool preserveOnError = false,
  }) async {
    final customerId = ref.read(catalogCustomerIdProvider);
    if (customerId == null) {
      state = PackageListState.initial(
        categoryId: state.query.categoryId,
        q: state.query.q,
        categoryName: state.categoryName,
      );
      return;
    }

    final operation = ++_epoch;
    _cancelToken?.cancel('superseded');
    final token = CancelToken();
    _cancelToken = token;
    final preserved = preserveOnError
        ? state.packages
        : const <PackageSummary>[];
    final preservedPrices = preserveOnError ? state.pricesVisible : true;
    final preservedPagination = preserveOnError ? state.pagination : null;

    try {
      final page = await _repository.fetchPackages(
        state.query.copyWith(page: 1),
        cancelToken: token,
      );
      if (!_isCurrent(operation, customerId)) {
        return;
      }
      state = PackageListState(
        phase: page.packages.isEmpty
            ? PackageListPhase.empty
            : PackageListPhase.ready,
        query: state.query.copyWith(page: page.pagination.page),
        packages: page.packages,
        pricesVisible: page.pricesVisible,
        pagination: page.pagination,
        searchInput: state.searchInput,
        categoryName: state.categoryName,
        customerId: customerId,
      );
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.cancelled) {
        return;
      }
      if (await _applyAuthoritativeRejection(error)) {
        if (_isCurrent(operation, customerId) ||
            ref.read(catalogCustomerIdProvider) == null) {
          state = PackageListState.initial(
            categoryId: state.query.categoryId,
            q: state.query.q,
            categoryName: state.categoryName,
          );
        }
        return;
      }
      if (!_isCurrent(operation, customerId)) {
        return;
      }
      state = PackageListState(
        phase: PackageListPhase.error,
        query: state.query,
        packages: preserved,
        pricesVisible: preservedPrices,
        pagination: preservedPagination,
        error: error,
        searchInput: state.searchInput,
        categoryName: state.categoryName,
        customerId: customerId,
      );
    } on Object {
      if (!_isCurrent(operation, customerId)) {
        return;
      }
      state = PackageListState(
        phase: PackageListPhase.error,
        query: state.query,
        packages: preserved,
        pricesVisible: preservedPrices,
        pagination: preservedPagination,
        error: const ApiException(kind: ApiErrorKind.unknown),
        searchInput: state.searchInput,
        categoryName: state.categoryName,
        customerId: customerId,
      );
    } finally {
      if (identical(_cancelToken, token)) {
        _cancelToken = null;
      }
    }
  }

  Future<bool> _applyAuthoritativeRejection(ApiException error) async {
    if (!error.isAuthoritativeSessionRejection) {
      return false;
    }
    return ref
        .read(authControllerProvider.notifier)
        .applyAuthoritativeRejection(error);
  }

  bool _isCurrent(int operation, int? customerId) {
    return !_disposed &&
        operation == _epoch &&
        ref.read(catalogCustomerIdProvider) == customerId;
  }

  void _cancelInFlight() {
    _epoch += 1;
    _debounce?.cancel();
    _cancelToken?.cancel('customer-switch');
    _cancelToken = null;
    _loadMoreInFlight = false;
  }
}

enum PackageDetailPhase { idle, loading, ready, notFound, error }

class PackageDetailState {
  const PackageDetailState({
    required this.phase,
    required this.packageId,
    this.result,
    this.error,
    this.customerId,
  });

  final PackageDetailPhase phase;
  final int packageId;
  final PackageDetailResult? result;
  final ApiException? error;
  final int? customerId;
}

final packageDetailControllerProvider = NotifierProvider.autoDispose
    .family<PackageDetailController, PackageDetailState, int>(
      PackageDetailController.new,
    );

class PackageDetailController extends Notifier<PackageDetailState> {
  PackageDetailController(this.packageId);

  final int packageId;

  CatalogRepository get _repository => ref.read(catalogRepositoryProvider);

  int _epoch = 0;
  CancelToken? _cancelToken;
  bool _disposed = false;

  @override
  PackageDetailState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _epoch += 1;
      _cancelToken?.cancel('dispose');
      _cancelToken = null;
    });

    ref.listen<int?>(catalogCustomerIdProvider, (previous, next) {
      if (previous == next) {
        return;
      }
      _cancelInFlight();
      if (next == null) {
        state = PackageDetailState(
          phase: PackageDetailPhase.idle,
          packageId: packageId,
        );
        return;
      }
      unawaited(load());
    });

    scheduleMicrotask(() {
      if (!_disposed) {
        unawaited(load());
      }
    });
    return PackageDetailState(
      phase: PackageDetailPhase.loading,
      packageId: packageId,
      customerId: ref.read(catalogCustomerIdProvider),
    );
  }

  Future<void> load() async {
    final customerId = ref.read(catalogCustomerIdProvider);
    if (customerId == null) {
      state = PackageDetailState(
        phase: PackageDetailPhase.idle,
        packageId: packageId,
      );
      return;
    }
    if (packageId < 1) {
      state = PackageDetailState(
        phase: PackageDetailPhase.notFound,
        packageId: packageId,
        error: const ApiException(
          kind: ApiErrorKind.notFound,
          code: 'package_not_found',
          statusCode: 404,
        ),
        customerId: customerId,
      );
      return;
    }

    final operation = ++_epoch;
    _cancelToken?.cancel('superseded');
    final token = CancelToken();
    _cancelToken = token;
    state = PackageDetailState(
      phase: PackageDetailPhase.loading,
      packageId: packageId,
      customerId: customerId,
    );

    try {
      final result = await _repository.fetchPackage(
        packageId,
        cancelToken: token,
      );
      if (!_isCurrent(operation, customerId)) {
        return;
      }
      state = PackageDetailState(
        phase: PackageDetailPhase.ready,
        packageId: packageId,
        result: result,
        customerId: customerId,
      );
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.cancelled) {
        return;
      }
      if (await _applyAuthoritativeRejection(error)) {
        if (_isCurrent(operation, customerId) ||
            ref.read(catalogCustomerIdProvider) == null) {
          state = PackageDetailState(
            phase: PackageDetailPhase.idle,
            packageId: packageId,
          );
        }
        return;
      }
      if (!_isCurrent(operation, customerId)) {
        return;
      }
      final notFound =
          error.kind == ApiErrorKind.notFound ||
          error.code == 'package_not_found';
      state = PackageDetailState(
        phase: notFound
            ? PackageDetailPhase.notFound
            : PackageDetailPhase.error,
        packageId: packageId,
        error: error,
        customerId: customerId,
      );
    } on Object {
      if (!_isCurrent(operation, customerId)) {
        return;
      }
      state = PackageDetailState(
        phase: PackageDetailPhase.error,
        packageId: packageId,
        error: const ApiException(kind: ApiErrorKind.unknown),
        customerId: customerId,
      );
    } finally {
      if (identical(_cancelToken, token)) {
        _cancelToken = null;
      }
    }
  }

  Future<void> retry() => load();

  Future<bool> _applyAuthoritativeRejection(ApiException error) async {
    if (!error.isAuthoritativeSessionRejection) {
      return false;
    }
    return ref
        .read(authControllerProvider.notifier)
        .applyAuthoritativeRejection(error);
  }

  bool _isCurrent(int operation, int customerId) {
    return !_disposed &&
        operation == _epoch &&
        ref.read(catalogCustomerIdProvider) == customerId;
  }

  void _cancelInFlight() {
    _epoch += 1;
    _cancelToken?.cancel('customer-switch');
    _cancelToken = null;
  }
}
