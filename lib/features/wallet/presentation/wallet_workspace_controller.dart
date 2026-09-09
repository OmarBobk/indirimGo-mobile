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

class WalletWorkspaceState {
  const WalletWorkspaceState({
    required this.phase,
    this.transactions = const [],
    this.topups = const [],
    this.transactionPagination,
    this.topupPagination,
    this.error,
    this.customerId,
  });

  const WalletWorkspaceState.initial() : this(phase: WalletListPhase.idle);

  final WalletListPhase phase;
  final List<WalletTransactionItem> transactions;
  final List<TopupListItem> topups;
  final OffsetPagination? transactionPagination;
  final OffsetPagination? topupPagination;
  final ApiException? error;
  final int? customerId;

  bool get hasContent => transactions.isNotEmpty || topups.isNotEmpty;

  bool get canLoadMoreTransactions =>
      transactionPagination?.hasNextPage == true &&
      phase != WalletListPhase.loading &&
      phase != WalletListPhase.refreshing &&
      phase != WalletListPhase.loadingMore;

  bool get canLoadMoreTopups =>
      topupPagination?.hasNextPage == true &&
      phase != WalletListPhase.loading &&
      phase != WalletListPhase.refreshing &&
      phase != WalletListPhase.loadingMore;
}

final walletWorkspaceControllerProvider =
    NotifierProvider<WalletWorkspaceController, WalletWorkspaceState>(
      WalletWorkspaceController.new,
    );

class WalletWorkspaceController extends Notifier<WalletWorkspaceState> {
  WalletRepository get _repository => ref.read(walletRepositoryProvider);

  int _epoch = 0;
  CancelToken? _cancelToken;
  bool _disposed = false;
  bool _loadMoreInFlight = false;

  @override
  WalletWorkspaceState build() {
    ref.onDispose(() {
      _disposed = true;
      _epoch += 1;
      _cancelToken?.cancel();
      _cancelToken = null;
    });
    ref.listen<int?>(walletCustomerIdProvider, (previous, next) {
      if (previous == next) {
        return;
      }
      _cancelToken?.cancel();
      _cancelToken = null;
      _epoch += 1;
      if (next == null) {
        state = const WalletWorkspaceState.initial();
        return;
      }
      state = WalletWorkspaceState(
        phase: WalletListPhase.loading,
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
      phase: WalletListPhase.loading,
      customerId: customerId,
    );
  }

  Future<void> load() => _fetch(refreshing: false);

  Future<void> refresh() async {
    await Future.wait([
      _fetch(refreshing: true),
      ref.read(walletSummaryControllerProvider.notifier).refresh(),
    ]);
  }

  Future<void> loadMoreTransactions() async {
    final pagination = state.transactionPagination;
    if (!state.canLoadMoreTransactions || pagination == null) {
      return;
    }
    await _loadMore(
      nextTransactionPage: pagination.page + 1,
      nextTopupPage: null,
    );
  }

  Future<void> loadMoreTopups() async {
    final pagination = state.topupPagination;
    if (!state.canLoadMoreTopups || pagination == null) {
      return;
    }
    await _loadMore(
      nextTransactionPage: null,
      nextTopupPage: pagination.page + 1,
    );
  }

  Future<void> _fetch({required bool refreshing}) async {
    final customerId = ref.read(walletCustomerIdProvider);
    if (customerId == null) {
      state = const WalletWorkspaceState.initial();
      return;
    }
    final operation = ++_epoch;
    _cancelToken?.cancel();
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    final previousTransactions = state.transactions;
    final previousTopups = state.topups;
    state = WalletWorkspaceState(
      phase: refreshing && state.hasContent
          ? WalletListPhase.refreshing
          : WalletListPhase.loading,
      transactions: previousTransactions,
      topups: previousTopups,
      transactionPagination: state.transactionPagination,
      topupPagination: state.topupPagination,
      customerId: customerId,
    );
    try {
      final results = await Future.wait([
        _repository.fetchTransactions(page: 1, cancelToken: cancelToken),
        _repository.fetchTopups(page: 1, cancelToken: cancelToken),
      ]);
      if (operation != _epoch) {
        return;
      }
      final transactions = results[0] as WalletTransactionPage;
      final topups = results[1] as TopupListPage;
      state = WalletWorkspaceState(
        phase: WalletListPhase.ready,
        transactions: transactions.items,
        topups: topups.items,
        transactionPagination: transactions.pagination,
        topupPagination: topups.pagination,
        customerId: customerId,
      );
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.cancelled || operation != _epoch) {
        return;
      }
      if (await _applyAuthoritativeRejection(error)) {
        state = const WalletWorkspaceState.initial();
        return;
      }
      state = WalletWorkspaceState(
        phase: WalletListPhase.error,
        transactions: previousTransactions,
        topups: previousTopups,
        transactionPagination: state.transactionPagination,
        topupPagination: state.topupPagination,
        error: error,
        customerId: customerId,
      );
    }
  }

  Future<void> _loadMore({
    required int? nextTransactionPage,
    required int? nextTopupPage,
  }) async {
    final customerId = ref.read(walletCustomerIdProvider);
    if (customerId == null || _loadMoreInFlight) {
      return;
    }
    _loadMoreInFlight = true;
    final operation = _epoch;
    final cancelToken = CancelToken();
    state = WalletWorkspaceState(
      phase: WalletListPhase.loadingMore,
      transactions: state.transactions,
      topups: state.topups,
      transactionPagination: state.transactionPagination,
      topupPagination: state.topupPagination,
      customerId: customerId,
    );
    try {
      final nextTransactions = nextTransactionPage == null
          ? null
          : await _repository.fetchTransactions(
              page: nextTransactionPage,
              cancelToken: cancelToken,
            );
      final nextTopups = nextTopupPage == null
          ? null
          : await _repository.fetchTopups(
              page: nextTopupPage,
              cancelToken: cancelToken,
            );
      if (operation != _epoch) {
        return;
      }
      state = WalletWorkspaceState(
        phase: WalletListPhase.ready,
        transactions: nextTransactions == null
            ? state.transactions
            : _mergeTransactions(state.transactions, nextTransactions.items),
        topups: nextTopups == null
            ? state.topups
            : _mergeTopups(state.topups, nextTopups.items),
        transactionPagination:
            nextTransactions?.pagination ?? state.transactionPagination,
        topupPagination: nextTopups?.pagination ?? state.topupPagination,
        customerId: customerId,
      );
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.cancelled || operation != _epoch) {
        return;
      }
      if (await _applyAuthoritativeRejection(error)) {
        state = const WalletWorkspaceState.initial();
        return;
      }
      state = WalletWorkspaceState(
        phase: WalletListPhase.ready,
        transactions: state.transactions,
        topups: state.topups,
        transactionPagination: state.transactionPagination,
        topupPagination: state.topupPagination,
        error: error,
        customerId: customerId,
      );
    } finally {
      _loadMoreInFlight = false;
    }
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

  Future<bool> _applyAuthoritativeRejection(ApiException error) {
    return ref
        .read(authControllerProvider.notifier)
        .applyAuthoritativeRejection(error);
  }
}
