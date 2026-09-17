import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:indirimgo_mobile/core/errors/api_exception.dart';
import 'package:indirimgo_mobile/features/auth/presentation/auth_controller.dart';
import 'package:indirimgo_mobile/features/catalog/domain/catalog_models.dart';
import 'package:indirimgo_mobile/features/wallet/domain/wallet_models.dart';
import 'package:indirimgo_mobile/features/wallet/domain/wallet_repository.dart';
import 'package:indirimgo_mobile/features/wallet/presentation/wallet_controllers.dart';

enum WalletListPhase { idle, loading, refreshing, loadingMore, ready, error }

class WalletHistorySection<T> {
  const WalletHistorySection({
    required this.phase,
    this.items = const [],
    this.pagination,
    this.error,
    this.loadMoreError,
  });

  final WalletListPhase phase;
  final List<T> items;
  final OffsetPagination? pagination;
  final ApiException? error;
  final ApiException? loadMoreError;

  bool get hasContent => items.isNotEmpty;

  bool get isLoadingInitial =>
      (phase == WalletListPhase.idle || phase == WalletListPhase.loading) &&
      !hasContent;

  bool get showEmpty =>
      phase == WalletListPhase.ready && items.isEmpty && error == null;

  bool get showError => phase == WalletListPhase.error && !hasContent;

  bool get showRefreshError => error != null && hasContent;

  bool get canLoadMore =>
      pagination?.hasNextPage == true &&
      phase != WalletListPhase.loading &&
      phase != WalletListPhase.refreshing &&
      phase != WalletListPhase.loadingMore &&
      loadMoreError == null;

  bool get canRetryLoadMore =>
      pagination?.hasNextPage == true &&
      loadMoreError != null &&
      phase != WalletListPhase.loadingMore;
}

class WalletWorkspaceState {
  const WalletWorkspaceState({
    required this.topupSection,
    required this.transactionSection,
    this.customerId,
  });

  const WalletWorkspaceState.initial()
    : topupSection = const WalletHistorySection(phase: WalletListPhase.idle),
      transactionSection = const WalletHistorySection(
        phase: WalletListPhase.idle,
      ),
      customerId = null;

  final WalletHistorySection<TopupListItem> topupSection;
  final WalletHistorySection<WalletTransactionItem> transactionSection;
  final int? customerId;

  List<TopupListItem> get topups => topupSection.items;

  List<WalletTransactionItem> get transactions => transactionSection.items;

  bool get hasContent =>
      topupSection.hasContent || transactionSection.hasContent;

  bool get isRefreshing =>
      topupSection.phase == WalletListPhase.refreshing ||
      transactionSection.phase == WalletListPhase.refreshing;

  bool get canLoadMoreTransactions => transactionSection.canLoadMore;

  bool get canLoadMoreTopups => topupSection.canLoadMore;
}

final walletWorkspaceControllerProvider =
    NotifierProvider<WalletWorkspaceController, WalletWorkspaceState>(
      WalletWorkspaceController.new,
    );

class WalletWorkspaceController extends Notifier<WalletWorkspaceState> {
  WalletRepository get _repository => ref.read(walletRepositoryProvider);

  int _topupEpoch = 0;
  int _transactionEpoch = 0;
  CancelToken? _topupCancelToken;
  CancelToken? _transactionCancelToken;
  bool _disposed = false;
  bool _topupLoadMoreInFlight = false;
  bool _transactionLoadMoreInFlight = false;

  @override
  WalletWorkspaceState build() {
    ref.onDispose(() {
      _disposed = true;
      _topupEpoch += 1;
      _transactionEpoch += 1;
      _topupCancelToken?.cancel();
      _transactionCancelToken?.cancel();
      _topupCancelToken = null;
      _transactionCancelToken = null;
    });
    ref.listen<int?>(walletCustomerIdProvider, (previous, next) {
      if (previous == next) {
        return;
      }
      _cancelAll();
      if (next == null) {
        state = const WalletWorkspaceState.initial();
        return;
      }
      state = WalletWorkspaceState(
        topupSection: const WalletHistorySection(
          phase: WalletListPhase.loading,
        ),
        transactionSection: const WalletHistorySection(
          phase: WalletListPhase.loading,
        ),
        customerId: next,
      );
      scheduleMicrotask(() {
        if (!_disposed) {
          load();
        }
      });
    });
    final customerId = ref.read(walletCustomerIdProvider);
    if (customerId == null) {
      return const WalletWorkspaceState.initial();
    }
    scheduleMicrotask(() {
      if (!_disposed) {
        load();
      }
    });
    return WalletWorkspaceState(
      topupSection: const WalletHistorySection(phase: WalletListPhase.loading),
      transactionSection: const WalletHistorySection(
        phase: WalletListPhase.loading,
      ),
      customerId: customerId,
    );
  }

  Future<void> load() => Future.wait([
    _fetchTopups(refreshing: false),
    _fetchTransactions(refreshing: false),
  ]);

  Future<void> refresh() async {
    await Future.wait([
      _fetchTopups(refreshing: true),
      _fetchTransactions(refreshing: true),
      ref.read(walletSummaryControllerProvider.notifier).refresh(),
    ]);
  }

  Future<void> retryTopups() =>
      _fetchTopups(refreshing: state.topupSection.hasContent);

  Future<void> retryTransactions() =>
      _fetchTransactions(refreshing: state.transactionSection.hasContent);

  Future<void> loadMoreTransactions() async {
    final pagination = state.transactionSection.pagination;
    if (pagination == null ||
        !pagination.hasNextPage ||
        _transactionLoadMoreInFlight ||
        state.transactionSection.phase == WalletListPhase.loading ||
        state.transactionSection.phase == WalletListPhase.refreshing) {
      return;
    }
    await _loadMoreTransactions(pagination.page + 1);
  }

  Future<void> loadMoreTopups() async {
    final pagination = state.topupSection.pagination;
    if (pagination == null ||
        !pagination.hasNextPage ||
        _topupLoadMoreInFlight ||
        state.topupSection.phase == WalletListPhase.loading ||
        state.topupSection.phase == WalletListPhase.refreshing) {
      return;
    }
    await _loadMoreTopups(pagination.page + 1);
  }

  Future<void> _fetchTopups({required bool refreshing}) async {
    final customerId = ref.read(walletCustomerIdProvider);
    if (customerId == null) {
      state = const WalletWorkspaceState.initial();
      return;
    }
    final operation = ++_topupEpoch;
    _topupCancelToken?.cancel();
    final cancelToken = CancelToken();
    _topupCancelToken = cancelToken;
    final previous = state.topupSection;
    state = WalletWorkspaceState(
      topupSection: WalletHistorySection(
        phase: refreshing && previous.hasContent
            ? WalletListPhase.refreshing
            : WalletListPhase.loading,
        items: previous.items,
        pagination: previous.pagination,
      ),
      transactionSection: state.transactionSection,
      customerId: customerId,
    );
    try {
      final page = await _repository.fetchTopups(
        page: 1,
        cancelToken: cancelToken,
      );
      if (operation != _topupEpoch) {
        return;
      }
      state = WalletWorkspaceState(
        topupSection: WalletHistorySection(
          phase: WalletListPhase.ready,
          items: page.items,
          pagination: page.pagination,
        ),
        transactionSection: state.transactionSection,
        customerId: customerId,
      );
    } catch (error) {
      await _applySectionFailure(
        error: error,
        operation: operation,
        epoch: _topupEpoch,
        previous: previous,
        customerId: customerId,
        update: (section) => state = WalletWorkspaceState(
          topupSection: section,
          transactionSection: state.transactionSection,
          customerId: customerId,
        ),
      );
    }
  }

  Future<void> _fetchTransactions({required bool refreshing}) async {
    final customerId = ref.read(walletCustomerIdProvider);
    if (customerId == null) {
      state = const WalletWorkspaceState.initial();
      return;
    }
    final operation = ++_transactionEpoch;
    _transactionCancelToken?.cancel();
    final cancelToken = CancelToken();
    _transactionCancelToken = cancelToken;
    final previous = state.transactionSection;
    state = WalletWorkspaceState(
      topupSection: state.topupSection,
      transactionSection: WalletHistorySection(
        phase: refreshing && previous.hasContent
            ? WalletListPhase.refreshing
            : WalletListPhase.loading,
        items: previous.items,
        pagination: previous.pagination,
      ),
      customerId: customerId,
    );
    try {
      final page = await _repository.fetchTransactions(
        page: 1,
        cancelToken: cancelToken,
      );
      if (operation != _transactionEpoch) {
        return;
      }
      state = WalletWorkspaceState(
        topupSection: state.topupSection,
        transactionSection: WalletHistorySection(
          phase: WalletListPhase.ready,
          items: page.items,
          pagination: page.pagination,
        ),
        customerId: customerId,
      );
    } catch (error) {
      await _applySectionFailure(
        error: error,
        operation: operation,
        epoch: _transactionEpoch,
        previous: previous,
        customerId: customerId,
        update: (section) => state = WalletWorkspaceState(
          topupSection: state.topupSection,
          transactionSection: section,
          customerId: customerId,
        ),
      );
    }
  }

  Future<void> _loadMoreTopups(int nextPage) async {
    final customerId = ref.read(walletCustomerIdProvider);
    if (customerId == null || _topupLoadMoreInFlight) {
      return;
    }
    _topupLoadMoreInFlight = true;
    final operation = _topupEpoch;
    final cancelToken = CancelToken();
    state = WalletWorkspaceState(
      topupSection: WalletHistorySection(
        phase: WalletListPhase.loadingMore,
        items: state.topupSection.items,
        pagination: state.topupSection.pagination,
      ),
      transactionSection: state.transactionSection,
      customerId: customerId,
    );
    try {
      final next = await _repository.fetchTopups(
        page: nextPage,
        cancelToken: cancelToken,
      );
      if (operation != _topupEpoch) {
        return;
      }
      state = WalletWorkspaceState(
        topupSection: WalletHistorySection(
          phase: WalletListPhase.ready,
          items: _mergeTopups(state.topupSection.items, next.items),
          pagination: next.pagination,
        ),
        transactionSection: state.transactionSection,
        customerId: customerId,
      );
    } catch (error) {
      await _applyLoadMoreFailure(
        error: error,
        operation: operation,
        epoch: _topupEpoch,
        customerId: customerId,
        update: (loadMoreError) => state = WalletWorkspaceState(
          topupSection: WalletHistorySection(
            phase: WalletListPhase.ready,
            items: state.topupSection.items,
            pagination: state.topupSection.pagination,
            loadMoreError: loadMoreError,
          ),
          transactionSection: state.transactionSection,
          customerId: customerId,
        ),
      );
    } finally {
      _topupLoadMoreInFlight = false;
    }
  }

  Future<void> _loadMoreTransactions(int nextPage) async {
    final customerId = ref.read(walletCustomerIdProvider);
    if (customerId == null || _transactionLoadMoreInFlight) {
      return;
    }
    _transactionLoadMoreInFlight = true;
    final operation = _transactionEpoch;
    final cancelToken = CancelToken();
    state = WalletWorkspaceState(
      topupSection: state.topupSection,
      transactionSection: WalletHistorySection(
        phase: WalletListPhase.loadingMore,
        items: state.transactionSection.items,
        pagination: state.transactionSection.pagination,
      ),
      customerId: customerId,
    );
    try {
      final next = await _repository.fetchTransactions(
        page: nextPage,
        cancelToken: cancelToken,
      );
      if (operation != _transactionEpoch) {
        return;
      }
      state = WalletWorkspaceState(
        topupSection: state.topupSection,
        transactionSection: WalletHistorySection(
          phase: WalletListPhase.ready,
          items: _mergeTransactions(state.transactionSection.items, next.items),
          pagination: next.pagination,
        ),
        customerId: customerId,
      );
    } catch (error) {
      await _applyLoadMoreFailure(
        error: error,
        operation: operation,
        epoch: _transactionEpoch,
        customerId: customerId,
        update: (loadMoreError) => state = WalletWorkspaceState(
          topupSection: state.topupSection,
          transactionSection: WalletHistorySection(
            phase: WalletListPhase.ready,
            items: state.transactionSection.items,
            pagination: state.transactionSection.pagination,
            loadMoreError: loadMoreError,
          ),
          customerId: customerId,
        ),
      );
    } finally {
      _transactionLoadMoreInFlight = false;
    }
  }

  Future<void> _applySectionFailure<T>({
    required Object error,
    required int operation,
    required int epoch,
    required WalletHistorySection<T> previous,
    required int customerId,
    required void Function(WalletHistorySection<T> section) update,
  }) async {
    final mapped = recoverableWalletError(error);
    if (mapped.kind == ApiErrorKind.cancelled || operation != epoch) {
      return;
    }
    if (await _applyAuthoritativeRejection(mapped)) {
      state = const WalletWorkspaceState.initial();
      return;
    }
    update(
      WalletHistorySection(
        phase: WalletListPhase.error,
        items: previous.items,
        pagination: previous.pagination,
        error: mapped,
      ),
    );
  }

  Future<void> _applyLoadMoreFailure({
    required Object error,
    required int operation,
    required int epoch,
    required int customerId,
    required void Function(ApiException loadMoreError) update,
  }) async {
    final mapped = recoverableWalletError(error);
    if (mapped.kind == ApiErrorKind.cancelled || operation != epoch) {
      return;
    }
    if (await _applyAuthoritativeRejection(mapped)) {
      state = const WalletWorkspaceState.initial();
      return;
    }
    update(mapped);
  }

  List<WalletTransactionItem> _mergeTransactions(
    List<WalletTransactionItem> current,
    List<WalletTransactionItem> incoming,
  ) {
    final seen = {for (final item in current) item.publicRef};
    return [
      ...current,
      for (final item in incoming)
        if (seen.add(item.publicRef)) item,
    ];
  }

  List<TopupListItem> _mergeTopups(
    List<TopupListItem> current,
    List<TopupListItem> incoming,
  ) {
    final seen = {for (final item in current) item.publicRef};
    return [
      ...current,
      for (final item in incoming)
        if (seen.add(item.publicRef)) item,
    ];
  }

  void _cancelAll() {
    _topupCancelToken?.cancel();
    _transactionCancelToken?.cancel();
    _topupCancelToken = null;
    _transactionCancelToken = null;
    _topupEpoch += 1;
    _transactionEpoch += 1;
  }

  Future<bool> _applyAuthoritativeRejection(ApiException error) {
    return ref
        .read(authControllerProvider.notifier)
        .applyAuthoritativeRejection(error);
  }
}
