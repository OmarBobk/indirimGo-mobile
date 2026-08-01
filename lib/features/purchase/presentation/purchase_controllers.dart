import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:indirimgo_mobile/core/errors/api_exception.dart';
import 'package:indirimgo_mobile/core/storage/pending_checkout_store.dart';
import 'package:indirimgo_mobile/features/auth/presentation/auth_controller.dart';
import 'package:indirimgo_mobile/features/purchase/domain/purchase_models.dart';
import 'package:indirimgo_mobile/features/purchase/domain/purchase_repository.dart';
import 'package:indirimgo_mobile/features/wallet/presentation/wallet_controllers.dart';

final purchaseCustomerIdProvider = Provider<int?>((ref) {
  final auth = ref.watch(authControllerProvider);
  if (auth.phase != AuthPhase.authenticated) {
    return null;
  }
  return auth.user?.id;
});

enum PurchaseDraftPhase { empty, ready }

class PurchaseDraftState {
  const PurchaseDraftState({required this.phase, this.draft});

  const PurchaseDraftState.empty() : this(phase: PurchaseDraftPhase.empty);

  final PurchaseDraftPhase phase;
  final PurchaseDraft? draft;
}

final purchaseDraftControllerProvider =
    NotifierProvider<PurchaseDraftController, PurchaseDraftState>(
      PurchaseDraftController.new,
    );

class PurchaseDraftController extends Notifier<PurchaseDraftState> {
  @override
  PurchaseDraftState build() {
    ref.listen<int?>(purchaseCustomerIdProvider, (previous, next) {
      if (previous != next) {
        state = const PurchaseDraftState.empty();
      }
    });
    return const PurchaseDraftState.empty();
  }

  void start({
    required int packageId,
    required String packageName,
    required ProductOption product,
    required List<PackageRequirementField> requirements,
    required bool requirementsSupported,
    required bool pricesVisible,
  }) {
    final customerId = ref.read(purchaseCustomerIdProvider);
    if (customerId == null) {
      state = const PurchaseDraftState.empty();
      return;
    }
    final current = state.draft;
    final sameProduct =
        current != null &&
        current.customerId == customerId &&
        current.packageId == packageId &&
        current.product.id == product.id;
    if (sameProduct) {
      // Preserve in-session draft when returning to the same product.
      state = PurchaseDraftState(
        phase: PurchaseDraftPhase.ready,
        draft: current,
      );
      return;
    }
    state = PurchaseDraftState(
      phase: PurchaseDraftPhase.ready,
      draft: PurchaseDraft(
        customerId: customerId,
        packageId: packageId,
        packageName: packageName,
        product: product,
        requirementsSchema: requirements,
        requirementsSupported: requirementsSupported,
        pricesVisible: pricesVisible,
        quantity: product.isFixed ? 1 : null,
        requestedAmount: product.isCustom ? product.customAmount?.min : null,
      ),
    );
  }

  void clear() {
    state = const PurchaseDraftState.empty();
  }

  void updateQuantity(int? quantity) {
    final draft = state.draft;
    if (draft == null) {
      return;
    }
    state = PurchaseDraftState(
      phase: PurchaseDraftPhase.ready,
      draft: draft.copyWith(
        quantity: quantity,
        clearQuantity: quantity == null,
        clearQuote: true,
      ),
    );
  }

  void updateRequestedAmount(int? amount) {
    final draft = state.draft;
    if (draft == null) {
      return;
    }
    state = PurchaseDraftState(
      phase: PurchaseDraftPhase.ready,
      draft: draft.copyWith(
        requestedAmount: amount,
        clearRequestedAmount: amount == null,
        clearQuote: true,
      ),
    );
  }

  void updateRequirementValue(String key, String value) {
    final draft = state.draft;
    if (draft == null) {
      return;
    }
    final next = Map<String, String>.from(draft.requirementValues);
    if (value.isEmpty) {
      next.remove(key);
    } else {
      next[key] = value;
    }
    state = PurchaseDraftState(
      phase: PurchaseDraftPhase.ready,
      draft: draft.copyWith(requirementValues: next, clearQuote: true),
    );
  }

  void setQuote(CheckoutQuote quote) {
    final draft = state.draft;
    if (draft == null) {
      return;
    }
    state = PurchaseDraftState(
      phase: PurchaseDraftPhase.ready,
      draft: draft.copyWith(quote: quote),
    );
  }

  void clearQuote() {
    final draft = state.draft;
    if (draft == null) {
      return;
    }
    state = PurchaseDraftState(
      phase: PurchaseDraftPhase.ready,
      draft: draft.copyWith(clearQuote: true),
    );
  }
}

enum PurchaseFormPhase {
  idle,
  quoting,
  quoted,
  validationError,
  unavailable,
  error,
}

class PurchaseFormState {
  const PurchaseFormState({
    required this.phase,
    this.localFieldErrors = const {},
    this.error,
    this.navigatedToReview = false,
  });

  const PurchaseFormState.idle() : this(phase: PurchaseFormPhase.idle);

  final PurchaseFormPhase phase;
  final Map<String, String> localFieldErrors;
  final ApiException? error;
  final bool navigatedToReview;
}

final purchaseFormControllerProvider =
    NotifierProvider<PurchaseFormController, PurchaseFormState>(
      PurchaseFormController.new,
    );

class PurchaseFormController extends Notifier<PurchaseFormState> {
  PurchaseRepository get _repository => ref.read(purchaseRepositoryProvider);

  int _epoch = 0;
  CancelToken? _cancelToken;
  bool _disposed = false;

  @override
  PurchaseFormState build() {
    ref.onDispose(() {
      _disposed = true;
      _epoch += 1;
      _cancelToken?.cancel();
    });
    ref.listen<int?>(purchaseCustomerIdProvider, (previous, next) {
      if (previous != next) {
        _cancelToken?.cancel();
        state = const PurchaseFormState.idle();
      }
    });
    return const PurchaseFormState.idle();
  }

  void resetNavigationFlag() {
    if (state.navigatedToReview) {
      state = PurchaseFormState(
        phase: state.phase,
        localFieldErrors: state.localFieldErrors,
        error: state.error,
      );
    }
  }

  Map<String, String> validateLocal(PurchaseDraft draft) {
    final errors = <String, String>{};
    if (!draft.requirementsSupported || !draft.pricesVisible) {
      return errors;
    }
    if (draft.isFixed) {
      final quantity = draft.quantity;
      if (quantity == null || quantity < 1 || quantity > purchaseQuantityMax) {
        errors['quantity'] = 'invalid';
      }
    } else {
      final amount = draft.requestedAmount;
      final config = draft.product.customAmount;
      if (amount == null || amount < 1) {
        errors['requested_amount'] = 'invalid';
      } else if (config != null) {
        if (config.min != null && amount < config.min!) {
          errors['requested_amount'] = 'invalid';
        }
        if (config.max != null && amount > config.max!) {
          errors['requested_amount'] = 'invalid';
        }
        if (config.step != null &&
            config.min != null &&
            (amount - config.min!) % config.step! != 0) {
          errors['requested_amount'] = 'invalid';
        }
      }
    }
    for (final field in draft.requirementsSchema) {
      final value = draft.requirementValues[field.key]?.trim() ?? '';
      if (field.required && value.isEmpty) {
        errors['requirement:${field.key}'] = 'required';
      } else if (field.maxLength != null && value.length > field.maxLength!) {
        errors['requirement:${field.key}'] = 'invalid';
      } else if (field.inputType == RequirementInputType.select &&
          value.isNotEmpty &&
          !(field.options ?? const []).contains(value)) {
        errors['requirement:${field.key}'] = 'invalid';
      }
    }
    return errors;
  }

  Future<bool> requestQuote() async {
    final draft = ref.read(purchaseDraftControllerProvider).draft;
    final customerId = ref.read(purchaseCustomerIdProvider);
    if (draft == null || customerId == null) {
      return false;
    }
    if (!draft.pricesVisible || !draft.requirementsSupported) {
      state = const PurchaseFormState(phase: PurchaseFormPhase.unavailable);
      return false;
    }
    final localErrors = validateLocal(draft);
    if (localErrors.isNotEmpty) {
      state = PurchaseFormState(
        phase: PurchaseFormPhase.validationError,
        localFieldErrors: localErrors,
      );
      return false;
    }

    final operation = ++_epoch;
    _cancelToken?.cancel();
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    state = const PurchaseFormState(phase: PurchaseFormPhase.quoting);

    try {
      final quote = await _repository.quote(
        draft.toLineItem(),
        cancelToken: cancelToken,
      );
      if (operation != _epoch || _disposed) {
        return false;
      }
      if (ref.read(purchaseCustomerIdProvider) != customerId) {
        return false;
      }
      ref.read(purchaseDraftControllerProvider.notifier).setQuote(quote);
      state = const PurchaseFormState(
        phase: PurchaseFormPhase.quoted,
        navigatedToReview: true,
      );
      return true;
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.cancelled || operation != _epoch) {
        return false;
      }
      if (await _applyAuthoritativeRejection(error)) {
        state = const PurchaseFormState.idle();
        return false;
      }
      if (error.code == 'purchasing_unavailable') {
        state = PurchaseFormState(
          phase: PurchaseFormPhase.unavailable,
          error: error,
        );
        return false;
      }
      final fieldErrors = _mapServerFieldErrors(error.fieldErrors);
      state = PurchaseFormState(
        phase: fieldErrors.isNotEmpty
            ? PurchaseFormPhase.validationError
            : PurchaseFormPhase.error,
        localFieldErrors: fieldErrors,
        error: error,
      );
      return false;
    }
  }

  Map<String, String> _mapServerFieldErrors(
    Map<String, List<String>> fieldErrors,
  ) {
    final mapped = <String, String>{};
    for (final key in fieldErrors.keys) {
      if (key == 'items.0.quantity' || key.endsWith('.quantity')) {
        mapped['quantity'] = 'invalid';
      } else if (key.contains('requested_amount')) {
        mapped['requested_amount'] = 'invalid';
      } else if (key.contains('requirements.')) {
        final reqKey = key.split('requirements.').last;
        mapped['requirement:$reqKey'] = 'invalid';
      }
    }
    return mapped;
  }

  Future<bool> _applyAuthoritativeRejection(ApiException error) {
    return ref
        .read(authControllerProvider.notifier)
        .applyAuthoritativeRejection(error);
  }
}

enum CheckoutReviewPhase {
  idle,
  refreshingQuote,
  ready,
  submitting,
  priceChanged,
  insufficientBalance,
  unavailable,
  recoveryRequired,
  restartRequired,
  success,
  error,
}

class CheckoutReviewState {
  const CheckoutReviewState({
    required this.phase,
    this.error,
    this.receipt,
    this.submittingLocked = false,
  });

  const CheckoutReviewState.idle() : this(phase: CheckoutReviewPhase.idle);

  final CheckoutReviewPhase phase;
  final ApiException? error;
  final PurchaseReceipt? receipt;
  final bool submittingLocked;
}

final checkoutReviewControllerProvider =
    NotifierProvider<CheckoutReviewController, CheckoutReviewState>(
      CheckoutReviewController.new,
    );

class CheckoutReviewController extends Notifier<CheckoutReviewState> {
  PurchaseRepository get _repository => ref.read(purchaseRepositoryProvider);
  PendingCheckoutStore get _pendingStore =>
      ref.read(pendingCheckoutStoreProvider);

  int _epoch = 0;
  bool _disposed = false;
  bool _submitInFlight = false;
  String? _activeIdempotencyKey;

  @override
  CheckoutReviewState build() {
    ref.onDispose(() {
      _disposed = true;
      _epoch += 1;
      _submitInFlight = false;
    });
    ref.listen<int?>(purchaseCustomerIdProvider, (previous, next) {
      if (previous != next) {
        _activeIdempotencyKey = null;
        _submitInFlight = false;
        state = const CheckoutReviewState.idle();
      }
    });
    return const CheckoutReviewState.idle();
  }

  Future<void> ensureFreshQuote({bool force = false}) async {
    final draft = ref.read(purchaseDraftControllerProvider).draft;
    final customerId = ref.read(purchaseCustomerIdProvider);
    if (draft == null || draft.quote == null || customerId == null) {
      return;
    }
    final quote = draft.quote!;
    final expired = quote.isExpiredAt(DateTime.now().toUtc());
    if (!force && !expired) {
      state = const CheckoutReviewState(phase: CheckoutReviewPhase.ready);
      return;
    }
    final operation = ++_epoch;
    state = const CheckoutReviewState(
      phase: CheckoutReviewPhase.refreshingQuote,
    );
    try {
      final refreshed = await _repository.quote(draft.toLineItem());
      if (operation != _epoch || _disposed) {
        return;
      }
      if (ref.read(purchaseCustomerIdProvider) != customerId) {
        return;
      }
      ref.read(purchaseDraftControllerProvider.notifier).setQuote(refreshed);
      state = CheckoutReviewState(
        phase: refreshed.wallet.canAfford
            ? CheckoutReviewPhase.ready
            : CheckoutReviewPhase.insufficientBalance,
      );
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.cancelled || operation != _epoch) {
        return;
      }
      if (await _applyAuthoritativeRejection(error)) {
        state = const CheckoutReviewState.idle();
        return;
      }
      _mapBusinessError(error);
    }
  }

  Future<PurchaseReceipt?> confirmPurchase() async {
    if (_submitInFlight || state.submittingLocked) {
      return null;
    }
    final draft = ref.read(purchaseDraftControllerProvider).draft;
    final customerId = ref.read(purchaseCustomerIdProvider);
    final quote = draft?.quote;
    if (draft == null || quote == null || customerId == null) {
      return null;
    }
    if (!quote.wallet.canAfford) {
      state = const CheckoutReviewState(
        phase: CheckoutReviewPhase.insufficientBalance,
      );
      return null;
    }
    if (quote.isExpiredAt(DateTime.now().toUtc())) {
      await ensureFreshQuote(force: true);
      return null;
    }

    _submitInFlight = true;
    final operation = ++_epoch;
    state = const CheckoutReviewState(
      phase: CheckoutReviewPhase.submitting,
      submittingLocked: true,
    );

    try {
      final key = _activeIdempotencyKey ?? generateIdempotencyKey();
      _activeIdempotencyKey = key;
      await _pendingStore.write(
        PendingCheckoutAttempt(
          customerId: customerId,
          idempotencyKey: key,
          createdAt: DateTime.now().toUtc(),
        ),
      );

      final result = await _repository.checkout(
        item: draft.toLineItem(),
        quoteFingerprint: quote.quoteFingerprint,
        idempotencyKey: key,
      );
      if (operation != _epoch || _disposed) {
        return null;
      }
      if (ref.read(purchaseCustomerIdProvider) != customerId) {
        return null;
      }
      await _pendingStore.clearForCustomer(customerId);
      _activeIdempotencyKey = null;
      ref.read(purchaseDraftControllerProvider.notifier).clear();
      unawaited(ref.read(walletSummaryControllerProvider.notifier).refresh());
      state = CheckoutReviewState(
        phase: CheckoutReviewPhase.success,
        receipt: result.order,
      );
      return result.order;
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.cancelled || operation != _epoch) {
        return null;
      }
      if (await _applyAuthoritativeRejection(error)) {
        _submitInFlight = false;
        state = const CheckoutReviewState.idle();
        return null;
      }
      await _handleCheckoutFailure(error, customerId: customerId);
      return null;
    } finally {
      _submitInFlight = false;
    }
  }

  Future<void> _handleCheckoutFailure(
    ApiException error, {
    required int customerId,
  }) async {
    switch (error.code) {
      case 'price_changed':
        final refreshed = _quoteFromDetails(error.details);
        if (refreshed != null) {
          ref
              .read(purchaseDraftControllerProvider.notifier)
              .setQuote(refreshed);
        } else {
          ref.read(purchaseDraftControllerProvider.notifier).clearQuote();
        }
        await _pendingStore.clearForCustomer(customerId);
        _activeIdempotencyKey = null;
        state = CheckoutReviewState(
          phase: CheckoutReviewPhase.priceChanged,
          error: error,
        );
      case 'insufficient_wallet_balance':
        state = CheckoutReviewState(
          phase: CheckoutReviewPhase.insufficientBalance,
          error: error,
        );
      case 'purchasing_unavailable':
        await _pendingStore.clearForCustomer(customerId);
        _activeIdempotencyKey = null;
        state = CheckoutReviewState(
          phase: CheckoutReviewPhase.unavailable,
          error: error,
        );
      case 'idempotency_conflict':
      case 'checkout_in_progress':
        state = CheckoutReviewState(
          phase: CheckoutReviewPhase.recoveryRequired,
          error: error,
        );
      case 'checkout_retry_required':
        // Same in-memory session may retry with identical payload + same key.
        state = CheckoutReviewState(
          phase: CheckoutReviewPhase.error,
          error: error,
        );
      default:
        if (error.kind == ApiErrorKind.network ||
            error.kind == ApiErrorKind.server) {
          state = CheckoutReviewState(
            phase: CheckoutReviewPhase.recoveryRequired,
            error: error,
          );
        } else if (error.kind == ApiErrorKind.validation) {
          state = CheckoutReviewState(
            phase: CheckoutReviewPhase.error,
            error: error,
          );
        } else {
          state = CheckoutReviewState(
            phase: CheckoutReviewPhase.error,
            error: error,
          );
        }
    }
  }

  void _mapBusinessError(ApiException error) {
    switch (error.code) {
      case 'purchasing_unavailable':
        state = CheckoutReviewState(
          phase: CheckoutReviewPhase.unavailable,
          error: error,
        );
      case 'insufficient_wallet_balance':
        state = CheckoutReviewState(
          phase: CheckoutReviewPhase.insufficientBalance,
          error: error,
        );
      case 'price_changed':
        final refreshed = _quoteFromDetails(error.details);
        if (refreshed != null) {
          ref
              .read(purchaseDraftControllerProvider.notifier)
              .setQuote(refreshed);
        }
        state = CheckoutReviewState(
          phase: CheckoutReviewPhase.priceChanged,
          error: error,
        );
      default:
        state = CheckoutReviewState(
          phase: CheckoutReviewPhase.error,
          error: error,
        );
    }
  }

  CheckoutQuote? _quoteFromDetails(Map<String, Object?>? details) {
    if (details == null) {
      return null;
    }
    final current = details['current_quote'];
    if (current is! Map) {
      return null;
    }
    try {
      return CheckoutQuote.fromJson(
        current.map((key, value) => MapEntry('$key', value)),
      );
    } on FormatException {
      return null;
    }
  }

  Future<bool> _applyAuthoritativeRejection(ApiException error) {
    return ref
        .read(authControllerProvider.notifier)
        .applyAuthoritativeRejection(error);
  }
}

enum CheckoutRecoveryPhase {
  idle,
  checking,
  processing,
  completed,
  failed,
  retryRequiredRestart,
  notFound,
  error,
}

class CheckoutRecoveryState {
  const CheckoutRecoveryState({
    required this.phase,
    this.receipt,
    this.error,
    this.retryAfterSeconds,
    this.pollCount = 0,
  });

  const CheckoutRecoveryState.idle() : this(phase: CheckoutRecoveryPhase.idle);

  final CheckoutRecoveryPhase phase;
  final PurchaseReceipt? receipt;
  final ApiException? error;
  final int? retryAfterSeconds;
  final int pollCount;

  bool get needsRecoveryRoute =>
      phase == CheckoutRecoveryPhase.checking ||
      phase == CheckoutRecoveryPhase.processing ||
      phase == CheckoutRecoveryPhase.completed ||
      phase == CheckoutRecoveryPhase.failed ||
      phase == CheckoutRecoveryPhase.retryRequiredRestart ||
      phase == CheckoutRecoveryPhase.notFound ||
      phase == CheckoutRecoveryPhase.error;
}

/// Bounded polling cap for unknown-result recovery.
const int checkoutRecoveryMaxPolls = 8;

final checkoutRecoveryControllerProvider =
    NotifierProvider<CheckoutRecoveryController, CheckoutRecoveryState>(
      CheckoutRecoveryController.new,
    );

class CheckoutRecoveryController extends Notifier<CheckoutRecoveryState> {
  PurchaseRepository get _repository => ref.read(purchaseRepositoryProvider);
  PendingCheckoutStore get _pendingStore =>
      ref.read(pendingCheckoutStoreProvider);

  int _epoch = 0;
  CancelToken? _cancelToken;
  Timer? _pollTimer;
  bool _disposed = false;
  bool _requestInFlight = false;

  @override
  CheckoutRecoveryState build() {
    ref.onDispose(() {
      _disposed = true;
      _epoch += 1;
      _cancelToken?.cancel();
      _pollTimer?.cancel();
    });
    ref.listen<int?>(purchaseCustomerIdProvider, (previous, next) {
      _pollTimer?.cancel();
      _cancelToken?.cancel();
      _epoch += 1;
      _requestInFlight = false;
      if (next == null) {
        state = const CheckoutRecoveryState.idle();
        return;
      }
      scheduleMicrotask(() {
        if (!_disposed) {
          checkOnStartup();
        }
      });
    });
    final customerId = ref.read(purchaseCustomerIdProvider);
    if (customerId != null) {
      scheduleMicrotask(() {
        if (!_disposed) {
          checkOnStartup();
        }
      });
    }
    return const CheckoutRecoveryState.idle();
  }

  Future<void> checkOnStartup() async {
    final customerId = ref.read(purchaseCustomerIdProvider);
    if (customerId == null) {
      state = const CheckoutRecoveryState.idle();
      return;
    }
    final pending = await _pendingStore.read();
    if (pending == null) {
      state = const CheckoutRecoveryState.idle();
      return;
    }
    if (pending.customerId != customerId) {
      await _pendingStore.clear();
      state = const CheckoutRecoveryState.idle();
      return;
    }
    await pollStatus(manual: true);
  }

  Future<void> pollStatus({bool manual = false}) async {
    if (_requestInFlight && !manual) {
      return;
    }
    final customerId = ref.read(purchaseCustomerIdProvider);
    if (customerId == null) {
      _stopPolling();
      state = const CheckoutRecoveryState.idle();
      return;
    }
    final pending = await _pendingStore.read();
    if (pending == null || pending.customerId != customerId) {
      if (pending != null && pending.customerId != customerId) {
        await _pendingStore.clear();
      }
      _stopPolling();
      state = const CheckoutRecoveryState.idle();
      return;
    }

    final operation = ++_epoch;
    _cancelToken?.cancel();
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    _requestInFlight = true;
    final nextPollCount = manual ? state.pollCount : state.pollCount + 1;
    state = CheckoutRecoveryState(
      phase: CheckoutRecoveryPhase.checking,
      pollCount: state.pollCount,
    );

    try {
      final status = await _repository.checkoutStatus(
        idempotencyKey: pending.idempotencyKey,
        cancelToken: cancelToken,
      );
      if (operation != _epoch || _disposed || !ref.mounted) {
        return;
      }
      if (ref.read(purchaseCustomerIdProvider) != customerId) {
        return;
      }
      await _applyStatus(
        status,
        pollCount: nextPollCount,
        customerId: customerId,
      );
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.cancelled || operation != _epoch) {
        return;
      }
      if (await _applyAuthoritativeRejection(error)) {
        _stopPolling();
        state = const CheckoutRecoveryState.idle();
        return;
      }
      if (error.code == 'checkout_attempt_not_found' ||
          error.kind == ApiErrorKind.notFound) {
        await _pendingStore.clearForCustomer(customerId);
        _stopPolling();
        state = const CheckoutRecoveryState(
          phase: CheckoutRecoveryPhase.notFound,
        );
        return;
      }
      if (error.code == 'checkout_retry_required') {
        // After restart, requirement values are absent — do not recreate payload.
        await _pendingStore.clearForCustomer(customerId);
        _stopPolling();
        state = CheckoutRecoveryState(
          phase: CheckoutRecoveryPhase.retryRequiredRestart,
          error: error,
        );
        return;
      }
      state = CheckoutRecoveryState(
        phase: CheckoutRecoveryPhase.error,
        error: error,
        pollCount: nextPollCount,
      );
      if (error.kind == ApiErrorKind.network ||
          error.kind == ApiErrorKind.server) {
        _schedulePoll(
          seconds: error.retryAfterSeconds ?? 2,
          pollCount: nextPollCount,
        );
      }
    } finally {
      _requestInFlight = false;
    }
  }

  Future<void> _applyStatus(
    CheckoutStatus status, {
    required int pollCount,
    required int customerId,
  }) async {
    switch (status.state) {
      case CheckoutStatusState.completed:
        final order = status.order;
        if (order == null) {
          state = const CheckoutRecoveryState(
            phase: CheckoutRecoveryPhase.error,
          );
          return;
        }
        await _pendingStore.clearForCustomer(customerId);
        _stopPolling();
        ref.read(purchaseDraftControllerProvider.notifier).clear();
        unawaited(ref.read(walletSummaryControllerProvider.notifier).refresh());
        state = CheckoutRecoveryState(
          phase: CheckoutRecoveryPhase.completed,
          receipt: order,
          pollCount: pollCount,
        );
      case CheckoutStatusState.failed:
        await _pendingStore.clearForCustomer(customerId);
        _stopPolling();
        state = CheckoutRecoveryState(
          phase: CheckoutRecoveryPhase.failed,
          error: ApiException(
            kind: ApiErrorKind.server,
            code: status.code ?? 'checkout_failed',
          ),
          pollCount: pollCount,
        );
      case CheckoutStatusState.processing:
        state = CheckoutRecoveryState(
          phase: CheckoutRecoveryPhase.processing,
          retryAfterSeconds: status.retryAfterSeconds,
          pollCount: pollCount,
        );
        if (pollCount < checkoutRecoveryMaxPolls) {
          _schedulePoll(
            seconds: status.retryAfterSeconds ?? 2,
            pollCount: pollCount,
          );
        }
    }
  }

  void _schedulePoll({required int seconds, required int pollCount}) {
    _pollTimer?.cancel();
    final customerId = ref.read(purchaseCustomerIdProvider);
    if (customerId == null || pollCount >= checkoutRecoveryMaxPolls) {
      return;
    }
    _pollTimer = Timer(Duration(seconds: seconds.clamp(1, 30)), () {
      if (!_disposed && ref.mounted) {
        pollStatus();
      }
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _cancelToken?.cancel();
    _cancelToken = null;
  }

  void acknowledgeTerminal() {
    _stopPolling();
    state = const CheckoutRecoveryState.idle();
  }

  Future<bool> _applyAuthoritativeRejection(ApiException error) {
    return ref
        .read(authControllerProvider.notifier)
        .applyAuthoritativeRejection(error);
  }
}

enum OrderReceiptPhase { idle, loading, ready, notFound, error }

class OrderReceiptState {
  const OrderReceiptState({required this.phase, this.result, this.error});

  const OrderReceiptState.idle() : this(phase: OrderReceiptPhase.idle);

  final OrderReceiptPhase phase;
  final CheckoutResult? result;
  final ApiException? error;
}

final orderReceiptControllerProvider = NotifierProvider.autoDispose
    .family<OrderReceiptController, OrderReceiptState, String>(
      OrderReceiptController.new,
    );

class OrderReceiptController extends Notifier<OrderReceiptState> {
  OrderReceiptController(this.orderNumber);

  final String orderNumber;

  PurchaseRepository get _repository => ref.read(purchaseRepositoryProvider);
  int _epoch = 0;
  CancelToken? _cancelToken;

  @override
  OrderReceiptState build() {
    ref.onDispose(() {
      _epoch += 1;
      _cancelToken?.cancel();
    });
    ref.listen<int?>(purchaseCustomerIdProvider, (previous, next) {
      if (previous != next) {
        _cancelToken?.cancel();
        if (next == null) {
          state = const OrderReceiptState.idle();
        } else {
          load();
        }
      }
    });
    scheduleMicrotask(load);
    return const OrderReceiptState(phase: OrderReceiptPhase.loading);
  }

  Future<void> load() async {
    final customerId = ref.read(purchaseCustomerIdProvider);
    if (customerId == null) {
      state = const OrderReceiptState.idle();
      return;
    }
    if (!_orderNumberPattern.hasMatch(orderNumber)) {
      state = const OrderReceiptState(
        phase: OrderReceiptPhase.notFound,
        error: ApiException(
          kind: ApiErrorKind.notFound,
          code: 'order_not_found',
          statusCode: 404,
        ),
      );
      return;
    }
    final operation = ++_epoch;
    _cancelToken?.cancel();
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    state = const OrderReceiptState(phase: OrderReceiptPhase.loading);
    try {
      final result = await _repository.fetchOrder(
        orderNumber,
        cancelToken: cancelToken,
      );
      if (operation != _epoch) {
        return;
      }
      state = OrderReceiptState(phase: OrderReceiptPhase.ready, result: result);
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.cancelled || operation != _epoch) {
        return;
      }
      if (await ref
          .read(authControllerProvider.notifier)
          .applyAuthoritativeRejection(error)) {
        state = const OrderReceiptState.idle();
        return;
      }
      if (error.kind == ApiErrorKind.notFound ||
          error.code == 'order_not_found') {
        state = OrderReceiptState(
          phase: OrderReceiptPhase.notFound,
          error: error,
        );
        return;
      }
      state = OrderReceiptState(phase: OrderReceiptPhase.error, error: error);
    }
  }
}

final _orderNumberPattern = RegExp(r'^ORD-[A-Za-z0-9\-]+$');
