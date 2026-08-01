import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:indirimgo_mobile/core/errors/api_exception.dart';
import 'package:indirimgo_mobile/features/auth/presentation/auth_controller.dart';
import 'package:indirimgo_mobile/features/wallet/domain/wallet_models.dart';
import 'package:indirimgo_mobile/features/wallet/domain/wallet_repository.dart';

enum WalletLoadPhase { idle, loading, refreshing, ready, error }

class WalletSummaryState {
  const WalletSummaryState({
    required this.phase,
    this.summary,
    this.error,
    this.customerId,
  });

  const WalletSummaryState.initial() : this(phase: WalletLoadPhase.idle);

  final WalletLoadPhase phase;
  final WalletSummary? summary;
  final ApiException? error;
  final int? customerId;

  bool get hasContent => summary != null;
}

final walletCustomerIdProvider = Provider<int?>((ref) {
  final auth = ref.watch(authControllerProvider);
  if (auth.phase != AuthPhase.authenticated) {
    return null;
  }
  return auth.user?.id;
});

final walletSummaryControllerProvider =
    NotifierProvider<WalletSummaryController, WalletSummaryState>(
      WalletSummaryController.new,
    );

class WalletSummaryController extends Notifier<WalletSummaryState> {
  WalletRepository get _repository => ref.read(walletRepositoryProvider);

  int _epoch = 0;
  CancelToken? _cancelToken;
  bool _disposed = false;

  @override
  WalletSummaryState build() {
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
        state = const WalletSummaryState.initial();
        return;
      }
      state = WalletSummaryState(
        phase: WalletLoadPhase.loading,
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
      return const WalletSummaryState.initial();
    }
    scheduleMicrotask(() {
      if (!_disposed) {
        load();
      }
    });
    return WalletSummaryState(
      phase: WalletLoadPhase.loading,
      customerId: customerId,
    );
  }

  Future<void> load() => _fetch(refreshing: false);

  Future<void> refresh() => _fetch(refreshing: true);

  Future<void> _fetch({required bool refreshing}) async {
    final customerId = ref.read(walletCustomerIdProvider);
    if (customerId == null) {
      state = const WalletSummaryState.initial();
      return;
    }
    final operation = ++_epoch;
    _cancelToken?.cancel();
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    final previous = state.summary;
    state = WalletSummaryState(
      phase: refreshing && previous != null
          ? WalletLoadPhase.refreshing
          : WalletLoadPhase.loading,
      summary: previous,
      customerId: customerId,
    );
    try {
      final summary = await _repository.fetchSummary(cancelToken: cancelToken);
      if (operation != _epoch) {
        return;
      }
      state = WalletSummaryState(
        phase: WalletLoadPhase.ready,
        summary: summary,
        customerId: customerId,
      );
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.cancelled || operation != _epoch) {
        return;
      }
      if (await _applyAuthoritativeRejection(error)) {
        state = const WalletSummaryState.initial();
        return;
      }
      state = WalletSummaryState(
        phase: WalletLoadPhase.error,
        summary: previous,
        error: error,
        customerId: customerId,
      );
    }
  }

  Future<bool> _applyAuthoritativeRejection(ApiException error) {
    return ref
        .read(authControllerProvider.notifier)
        .applyAuthoritativeRejection(error);
  }
}
