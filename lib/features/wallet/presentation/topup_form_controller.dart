import 'dart:async';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:indirimgo_mobile/core/errors/api_exception.dart';
import 'package:indirimgo_mobile/core/storage/pending_checkout_store.dart';
import 'package:indirimgo_mobile/core/storage/pending_topup_store.dart';
import 'package:indirimgo_mobile/features/auth/presentation/auth_controller.dart';
import 'package:indirimgo_mobile/features/wallet/domain/wallet_models.dart';
import 'package:indirimgo_mobile/features/wallet/domain/wallet_repository.dart';
import 'package:indirimgo_mobile/features/wallet/presentation/wallet_controllers.dart';
import 'package:indirimgo_mobile/features/wallet/presentation/wallet_workspace_controller.dart';

enum TopupFormPhase {
  idle,
  loadingMethods,
  ready,
  submitting,
  recovering,
  submitted,
  error,
}

class TopupFormState {
  const TopupFormState({
    required this.phase,
    this.amount = '',
    this.currency = 'USD',
    this.paymentMethods = const [],
    this.selectedPaymentMethodId,
    this.proof,
    this.submitted,
    this.error,
    this.amountError = false,
    this.methodError = false,
    this.customerId,
  });

  const TopupFormState.initial() : this(phase: TopupFormPhase.idle);

  final TopupFormPhase phase;
  final String amount;
  final String currency;
  final List<PaymentMethod> paymentMethods;
  final int? selectedPaymentMethodId;
  final SelectedTopupProof? proof;
  final TopupDetail? submitted;
  final ApiException? error;
  final bool amountError;
  final bool methodError;
  final int? customerId;

  bool get isBusy =>
      phase == TopupFormPhase.submitting || phase == TopupFormPhase.recovering;

  PaymentMethod? get selectedMethod {
    final id = selectedPaymentMethodId;
    if (id == null) {
      return null;
    }
    for (final method in paymentMethods) {
      if (method.id == id) {
        return method;
      }
    }
    return null;
  }
}

final topupFormControllerProvider =
    NotifierProvider.autoDispose<TopupFormController, TopupFormState>(
      TopupFormController.new,
    );

class TopupFormController extends Notifier<TopupFormState> {
  WalletRepository get _repository => ref.read(walletRepositoryProvider);
  PendingTopupStore get _store => ref.read(pendingTopupStoreProvider);

  int _epoch = 0;
  CancelToken? _cancelToken;
  bool _disposed = false;
  String? _activeKey;

  @override
  TopupFormState build() {
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
      _activeKey = null;
      _epoch += 1;
      if (next == null) {
        state = const TopupFormState.initial();
        return;
      }
      state = TopupFormState(
        phase: TopupFormPhase.loadingMethods,
        customerId: next,
      );
      scheduleMicrotask(() {
        if (!_disposed) {
          bootstrap();
        }
      });
    });
    final customerId = ref.read(walletCustomerIdProvider);
    if (customerId == null) {
      return const TopupFormState.initial();
    }
    scheduleMicrotask(() {
      if (!_disposed) {
        bootstrap();
      }
    });
    return TopupFormState(
      phase: TopupFormPhase.loadingMethods,
      customerId: customerId,
    );
  }

  Future<void> bootstrap() async {
    final customerId = ref.read(walletCustomerIdProvider);
    if (customerId == null) {
      state = const TopupFormState.initial();
      return;
    }
    final operation = ++_epoch;
    _cancelToken?.cancel();
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    state = TopupFormState(
      phase: TopupFormPhase.loadingMethods,
      amount: state.amount,
      currency: state.currency,
      proof: state.proof,
      customerId: customerId,
    );
    try {
      final methods = await _repository.fetchPaymentMethods(
        cancelToken: cancelToken,
      );
      if (operation != _epoch) {
        return;
      }
      final selected =
          state.selectedPaymentMethodId ??
          (methods.isNotEmpty ? methods.first.id : null);
      state = TopupFormState(
        phase: TopupFormPhase.ready,
        amount: state.amount,
        currency: state.currency,
        paymentMethods: methods,
        selectedPaymentMethodId: selected,
        proof: state.proof,
        customerId: customerId,
      );
      await _recoverIfNeeded(customerId, operation);
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.cancelled || operation != _epoch) {
        return;
      }
      if (await _reject(error)) {
        state = const TopupFormState.initial();
        return;
      }
      state = TopupFormState(
        phase: TopupFormPhase.error,
        amount: state.amount,
        currency: state.currency,
        proof: state.proof,
        error: error,
        customerId: customerId,
      );
    }
  }

  void setAmount(String value) {
    state = TopupFormState(
      phase: state.phase,
      amount: value,
      currency: state.currency,
      paymentMethods: state.paymentMethods,
      selectedPaymentMethodId: state.selectedPaymentMethodId,
      proof: state.proof,
      submitted: state.submitted,
      error: state.error,
      amountError: false,
      methodError: state.methodError,
      customerId: state.customerId,
    );
  }

  void setCurrency(String value) {
    if (!supportedTopupCurrencies.contains(value)) {
      return;
    }
    state = TopupFormState(
      phase: state.phase,
      amount: state.amount,
      currency: value,
      paymentMethods: state.paymentMethods,
      selectedPaymentMethodId: state.selectedPaymentMethodId,
      proof: state.proof,
      submitted: state.submitted,
      error: state.error,
      customerId: state.customerId,
    );
  }

  void selectPaymentMethod(int id) {
    state = TopupFormState(
      phase: state.phase,
      amount: state.amount,
      currency: state.currency,
      paymentMethods: state.paymentMethods,
      selectedPaymentMethodId: id,
      proof: state.proof,
      submitted: state.submitted,
      error: state.error,
      methodError: false,
      customerId: state.customerId,
    );
  }

  Future<void> pickProof() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) {
      return;
    }
    setProof(
      SelectedTopupProof(
        filename: file.name,
        path: file.path,
        bytes: file.bytes,
      ),
    );
  }

  void setProof(SelectedTopupProof? proof) {
    state = TopupFormState(
      phase: state.phase,
      amount: state.amount,
      currency: state.currency,
      paymentMethods: state.paymentMethods,
      selectedPaymentMethodId: state.selectedPaymentMethodId,
      proof: proof,
      submitted: state.submitted,
      error: state.error,
      customerId: state.customerId,
    );
  }

  Future<TopupDetail?> submit() async {
    final customerId = ref.read(walletCustomerIdProvider);
    if (customerId == null || state.isBusy) {
      return null;
    }
    final amount = state.amount.trim();
    final methodId = state.selectedPaymentMethodId;
    final amountValid = isValidEnteredAmount(amount);
    final methodValid = methodId != null;
    if (!amountValid || !methodValid) {
      state = TopupFormState(
        phase: TopupFormPhase.ready,
        amount: state.amount,
        currency: state.currency,
        paymentMethods: state.paymentMethods,
        selectedPaymentMethodId: methodId,
        proof: state.proof,
        amountError: !amountValid,
        methodError: !methodValid,
        customerId: customerId,
      );
      return null;
    }

    final operation = ++_epoch;
    _cancelToken?.cancel();
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    final key = _activeKey ?? generateIdempotencyKey();
    _activeKey = key;
    state = TopupFormState(
      phase: TopupFormPhase.submitting,
      amount: state.amount,
      currency: state.currency,
      paymentMethods: state.paymentMethods,
      selectedPaymentMethodId: methodId,
      proof: state.proof,
      customerId: customerId,
    );
    await _store.writeUnresolved(
      customerId: customerId,
      idempotencyKey: key,
      createdAt: DateTime.now().toUtc(),
    );
    try {
      final result = await _repository.submitTopup(
        amount: amount,
        currency: state.currency,
        paymentMethodId: methodId,
        idempotencyKey: key,
        proof: state.proof,
        cancelToken: cancelToken,
      );
      if (operation != _epoch) {
        return null;
      }
      await _store.clearForCustomer(customerId);
      _activeKey = null;
      state = TopupFormState(
        phase: TopupFormPhase.submitted,
        amount: state.amount,
        currency: state.currency,
        paymentMethods: state.paymentMethods,
        selectedPaymentMethodId: methodId,
        proof: state.proof,
        submitted: result.topup,
        customerId: customerId,
      );
      await ref.read(walletSummaryControllerProvider.notifier).refresh();
      await ref.read(walletWorkspaceControllerProvider.notifier).refresh();
      return result.topup;
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.cancelled || operation != _epoch) {
        return null;
      }
      if (await _reject(error)) {
        state = const TopupFormState.initial();
        return null;
      }
      if (error.kind == ApiErrorKind.network ||
          error.kind == ApiErrorKind.server ||
          error.code == 'topup_in_progress') {
        state = TopupFormState(
          phase: TopupFormPhase.recovering,
          amount: state.amount,
          currency: state.currency,
          paymentMethods: state.paymentMethods,
          selectedPaymentMethodId: methodId,
          proof: state.proof,
          customerId: customerId,
        );
        return _pollStatus(customerId, key, operation);
      }
      if (error.code == 'idempotency_conflict' ||
          error.code == 'topup_retry_required') {
        return _pollStatus(customerId, key, operation);
      }
      state = TopupFormState(
        phase: TopupFormPhase.ready,
        amount: state.amount,
        currency: state.currency,
        paymentMethods: state.paymentMethods,
        selectedPaymentMethodId: methodId,
        proof: state.proof,
        error: error,
        customerId: customerId,
      );
      return null;
    }
  }

  Future<void> _recoverIfNeeded(int customerId, int operation) async {
    final record = await _store.readForCustomer(customerId);
    if (record == null || operation != _epoch) {
      return;
    }
    _activeKey = record.idempotencyKey;
    state = TopupFormState(
      phase: TopupFormPhase.recovering,
      amount: state.amount,
      currency: state.currency,
      paymentMethods: state.paymentMethods,
      selectedPaymentMethodId: state.selectedPaymentMethodId,
      proof: state.proof,
      customerId: customerId,
    );
    await _pollStatus(customerId, record.idempotencyKey, operation);
  }

  Future<TopupDetail?> _pollStatus(
    int customerId,
    String key,
    int operation,
  ) async {
    try {
      final status = await _repository.fetchTopupStatus(
        idempotencyKey: key,
        cancelToken: _cancelToken,
      );
      if (operation != _epoch) {
        return null;
      }
      if (status.state == TopupStatusState.completed && status.topup != null) {
        await _store.clearForCustomer(customerId);
        _activeKey = null;
        state = TopupFormState(
          phase: TopupFormPhase.submitted,
          amount: state.amount,
          currency: state.currency,
          paymentMethods: state.paymentMethods,
          selectedPaymentMethodId: state.selectedPaymentMethodId,
          proof: state.proof,
          submitted: status.topup,
          customerId: customerId,
        );
        await ref.read(walletSummaryControllerProvider.notifier).refresh();
        await ref.read(walletWorkspaceControllerProvider.notifier).refresh();
        return status.topup;
      }
      if (status.state == TopupStatusState.processing) {
        await Future<void>.delayed(
          Duration(seconds: status.retryAfterSeconds ?? 2),
        );
        if (operation != _epoch) {
          return null;
        }
        return _pollStatus(customerId, key, operation);
      }
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.cancelled || operation != _epoch) {
        return null;
      }
      if (error.code == 'topup_attempt_not_found') {
        await _store.clearForCustomer(customerId);
        _activeKey = null;
      }
      state = TopupFormState(
        phase: TopupFormPhase.ready,
        amount: state.amount,
        currency: state.currency,
        paymentMethods: state.paymentMethods,
        selectedPaymentMethodId: state.selectedPaymentMethodId,
        proof: state.proof,
        error: error,
        customerId: customerId,
      );
    }
    return null;
  }

  Future<bool> _reject(ApiException error) {
    return ref
        .read(authControllerProvider.notifier)
        .applyAuthoritativeRejection(error);
  }
}
