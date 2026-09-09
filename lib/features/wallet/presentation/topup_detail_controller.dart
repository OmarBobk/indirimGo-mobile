import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:indirimgo_mobile/core/errors/api_exception.dart';
import 'package:indirimgo_mobile/features/auth/presentation/auth_controller.dart';
import 'package:indirimgo_mobile/features/wallet/domain/wallet_models.dart';
import 'package:indirimgo_mobile/features/wallet/domain/wallet_repository.dart';
import 'package:indirimgo_mobile/features/wallet/presentation/wallet_controllers.dart';

enum TopupDetailPhase { idle, loading, refreshing, ready, error }

class TopupDetailState {
  const TopupDetailState({
    required this.phase,
    this.detail,
    this.error,
    this.customerId,
    this.publicRef,
  });

  const TopupDetailState.initial() : this(phase: TopupDetailPhase.idle);

  final TopupDetailPhase phase;
  final TopupDetail? detail;
  final ApiException? error;
  final int? customerId;
  final String? publicRef;
}

final topupDetailControllerProvider =
    NotifierProvider<TopupDetailController, TopupDetailState>(
      TopupDetailController.new,
    );

class TopupDetailController extends Notifier<TopupDetailState> {
  WalletRepository get _repository => ref.read(walletRepositoryProvider);

  int _epoch = 0;
  CancelToken? _cancelToken;
  bool _disposed = false;
  String? _requestedRef;

  @override
  TopupDetailState build() {
    ref.onDispose(() {
      _disposed = true;
      _epoch += 1;
      _cancelToken?.cancel();
    });
    ref.listen<int?>(walletCustomerIdProvider, (previous, next) {
      if (previous == next) {
        return;
      }
      _cancelToken?.cancel();
      _epoch += 1;
      if (next == null) {
        state = const TopupDetailState.initial();
        return;
      }
      final publicRef = _requestedRef;
      if (publicRef != null) {
        scheduleMicrotask(() {
          if (!_disposed) {
            load(publicRef);
          }
        });
      }
    });
    return const TopupDetailState.initial();
  }

  Future<void> load(String publicRef) {
    _requestedRef = publicRef;
    return _fetch(publicRef, refreshing: false);
  }

  Future<void> refresh() {
    final publicRef = state.publicRef ?? _requestedRef;
    if (publicRef == null) {
      return Future<void>.value();
    }
    return _fetch(publicRef, refreshing: true);
  }

  Future<void> _fetch(String publicRef, {required bool refreshing}) async {
    final customerId = ref.read(walletCustomerIdProvider);
    if (customerId == null) {
      state = const TopupDetailState.initial();
      return;
    }
    final operation = ++_epoch;
    _cancelToken?.cancel();
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    final previous = state.publicRef == publicRef ? state.detail : null;
    state = TopupDetailState(
      phase: refreshing && previous != null
          ? TopupDetailPhase.refreshing
          : TopupDetailPhase.loading,
      detail: previous,
      customerId: customerId,
      publicRef: publicRef,
    );
    try {
      final detail = await _repository.fetchTopup(
        publicRef,
        cancelToken: cancelToken,
      );
      if (operation != _epoch) {
        return;
      }
      state = TopupDetailState(
        phase: TopupDetailPhase.ready,
        detail: detail,
        customerId: customerId,
        publicRef: publicRef,
      );
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.cancelled || operation != _epoch) {
        return;
      }
      if (await ref
          .read(authControllerProvider.notifier)
          .applyAuthoritativeRejection(error)) {
        state = const TopupDetailState.initial();
        return;
      }
      state = TopupDetailState(
        phase: TopupDetailPhase.error,
        detail: previous,
        error: error,
        customerId: customerId,
        publicRef: publicRef,
      );
    }
  }
}
