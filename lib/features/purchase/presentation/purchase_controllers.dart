import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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

/// Explicit allowlist for enabling wallet confirm.
///
/// Confirm is allowed only for ordinary ready review, explicit `priceChanged`
/// reconfirmation, or in-session identical-payload `checkout_retry_required`.
bool isCheckoutConfirmEnabled({
  required CheckoutQuote? quote,
  required CheckoutReviewState review,
  DateTime? now,
}) {
  if (quote == null || review.submittingLocked) {
    return false;
  }
  if (!quote.wallet.canAfford) {
    return false;
  }
  final clock = now ?? DateTime.now().toUtc();
  if (quote.isExpiredAt(clock)) {
    return false;
  }
  return switch (review.phase) {
    CheckoutReviewPhase.ready => true,
    CheckoutReviewPhase.priceChanged => true,
    CheckoutReviewPhase.error =>
      review.error?.code == 'checkout_retry_required',
    _ => false,
  };
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
      // Ignore the initial null→authenticated bind; only real switches reset.
      if (previous == null && next != null) {
        return;
      }
      if (previous != next) {
        _activeIdempotencyKey = null;
        _submitInFlight = false;
        state = const CheckoutReviewState.idle();
      }
    });
    return const CheckoutReviewState.idle();
  }

  void resetAfterAcknowledgement() {
    _activeIdempotencyKey = null;
    _submitInFlight = false;
    state = const CheckoutReviewState.idle();
  }

  /// Test-only: drop the in-memory key while leaving the durable store intact.
  @visibleForTesting
  void debugClearActiveIdempotencyKey() {
    _activeIdempotencyKey = null;
  }

  Future<void> ensureFreshQuote({bool force = false}) async {
    final draft = ref.read(purchaseDraftControllerProvider).draft;
    final customerId = ref.read(purchaseCustomerIdProvider);
    if (draft == null || draft.quote == null || customerId == null) {
      return;
    }
    // Never bump the operation epoch while a wallet confirm is in flight.
    if (_submitInFlight || state.phase == CheckoutReviewPhase.submitting) {
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
    if (customerId == null) {
      return null;
    }

    final existing = await _pendingStore.readForCustomer(customerId);
    if (existing != null && existing.hasCompletedAnchor) {
      return _recoverCompletedAnchor(
        customerId: customerId,
        orderNumber: existing.completedOrderNumber!,
      );
    }

    if (!isCheckoutConfirmEnabled(quote: quote, review: state)) {
      if (quote != null && !quote.wallet.canAfford) {
        state = const CheckoutReviewState(
          phase: CheckoutReviewPhase.insufficientBalance,
        );
      } else if (quote != null && quote.isExpiredAt(DateTime.now().toUtc())) {
        await ensureFreshQuote(force: true);
      }
      return null;
    }
    if (draft == null || quote == null) {
      return null;
    }

    _submitInFlight = true;
    final operation = ++_epoch;
    state = const CheckoutReviewState(
      phase: CheckoutReviewPhase.submitting,
      submittingLocked: true,
    );

    try {
      final key = await _resolveIdempotencyKey(customerId);
      _activeIdempotencyKey = key;
      await _pendingStore.writeUnresolved(
        customerId: customerId,
        idempotencyKey: key,
        createdAt: DateTime.now().toUtc(),
      );

      final result = await _repository.checkout(
        item: draft.toLineItem(),
        quoteFingerprint: quote.quoteFingerprint,
        idempotencyKey: key,
      );
      // Must await so finally does not clear the in-flight guard before
      // durable success finalization finishes.
      return await _finalizeSuccessfulCheckout(
        order: result.order,
        customerId: customerId,
        operation: operation,
      );
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.cancelled || operation != _epoch) {
        return null;
      }
      if (await _applyAuthoritativeRejection(error)) {
        state = const CheckoutReviewState.idle();
        return null;
      }
      await _handleCheckoutFailure(error, customerId: customerId);
      return null;
    } finally {
      _submitInFlight = false;
    }
  }

  Future<String> _resolveIdempotencyKey(int customerId) async {
    final active = _activeIdempotencyKey;
    if (active != null && active.isNotEmpty) {
      return active;
    }
    final stored = await _pendingStore.readForCustomer(customerId);
    if (stored != null && stored.hasUnresolvedKey) {
      return stored.idempotencyKey!;
    }
    return generateIdempotencyKey();
  }

  Future<PurchaseReceipt?> _recoverCompletedAnchor({
    required int customerId,
    required String orderNumber,
  }) async {
    final operation = ++_epoch;
    state = const CheckoutReviewState(
      phase: CheckoutReviewPhase.submitting,
      submittingLocked: true,
    );
    try {
      final result = await _repository.fetchOrder(orderNumber);
      if (operation != _epoch || _disposed) {
        return null;
      }
      if (ref.read(purchaseCustomerIdProvider) != customerId) {
        return null;
      }
      ref.read(purchaseDraftControllerProvider.notifier).clear();
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
        state = const CheckoutReviewState.idle();
        return null;
      }
      if (error.kind == ApiErrorKind.notFound ||
          error.code == 'order_not_found') {
        await _pendingStore.clearForCustomer(customerId);
      }
      state = CheckoutReviewState(
        phase: CheckoutReviewPhase.error,
        error: error,
      );
      return null;
    }
  }

  /// Durable success ordering shared by confirm and delayed-response paths.
  Future<PurchaseReceipt?> _finalizeSuccessfulCheckout({
    required PurchaseReceipt order,
    required int customerId,
    required int operation,
  }) async {
    // 1–2. Validate receipt (already parsed) and persist order anchor while key
    // still exists.
    await _pendingStore.markCompleted(
      customerId: customerId,
      orderNumber: order.orderNumber,
    );

    final activeCustomer = ref.read(purchaseCustomerIdProvider);
    if (activeCustomer != customerId) {
      // Delayed A response after switch to B: keep A's anchor, drop only A's key.
      await _pendingStore.clearPendingKey(customerId);
      _activeIdempotencyKey = null;
      return null;
    }
    if (_disposed) {
      await _pendingStore.clearPendingKey(customerId);
      return null;
    }

    // Same customer: establish success when this operation is current, or when
    // UI is still on submitting from this attempt (stale epoch from refresh).
    final canPresentSuccess =
        operation == _epoch || state.phase == CheckoutReviewPhase.submitting;
    if (canPresentSuccess) {
      // 3. Establish in-memory success/receipt state before key removal.
      ref.read(purchaseDraftControllerProvider.notifier).clear();
      unawaited(ref.read(walletSummaryControllerProvider.notifier).refresh());
      state = CheckoutReviewState(
        phase: CheckoutReviewPhase.success,
        receipt: order,
      );
    }

    // 4. Remove raw Idempotency-Key while preserving completed order anchor.
    await _pendingStore.clearPendingKey(customerId);
    _activeIdempotencyKey = null;
    return canPresentSuccess ? order : null;
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
        // Clear in-memory UI only. Never delete another customer's recovery.
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
    final record = await _pendingStore.readForCustomer(customerId);
    if (record == null) {
      state = const CheckoutRecoveryState.idle();
      return;
    }
    if (record.hasCompletedAnchor) {
      await _loadCompletedAnchor(
        customerId: customerId,
        orderNumber: record.completedOrderNumber!,
      );
      return;
    }
    if (record.hasUnresolvedKey) {
      await pollStatus(manual: true);
      return;
    }
    state = const CheckoutRecoveryState.idle();
  }

  Future<void> _loadCompletedAnchor({
    required int customerId,
    required String orderNumber,
  }) async {
    final operation = ++_epoch;
    _stopPolling();
    state = CheckoutRecoveryState(
      phase: CheckoutRecoveryPhase.checking,
      pollCount: state.pollCount,
    );
    try {
      final result = await _repository.fetchOrder(orderNumber);
      if (operation != _epoch || _disposed || !ref.mounted) {
        return;
      }
      if (ref.read(purchaseCustomerIdProvider) != customerId) {
        return;
      }
      ref.read(purchaseDraftControllerProvider.notifier).clear();
      // Keep completed anchor until explicit acknowledgement.
      state = CheckoutRecoveryState(
        phase: CheckoutRecoveryPhase.completed,
        receipt: result.order,
      );
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.cancelled || operation != _epoch) {
        return;
      }
      if (await _applyAuthoritativeRejection(error)) {
        state = const CheckoutRecoveryState.idle();
        return;
      }
      if (error.kind == ApiErrorKind.notFound ||
          error.code == 'order_not_found') {
        await _pendingStore.clearForCustomer(customerId);
        state = const CheckoutRecoveryState(
          phase: CheckoutRecoveryPhase.notFound,
        );
        return;
      }
      // Offline / 5xx retain the anchor for retry.
      state = CheckoutRecoveryState(
        phase: CheckoutRecoveryPhase.error,
        error: error,
      );
    }
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
    final record = await _pendingStore.readForCustomer(customerId);
    if (record == null) {
      _stopPolling();
      state = const CheckoutRecoveryState.idle();
      return;
    }
    if (record.hasCompletedAnchor) {
      await _loadCompletedAnchor(
        customerId: customerId,
        orderNumber: record.completedOrderNumber!,
      );
      return;
    }
    if (!record.hasUnresolvedKey) {
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
        idempotencyKey: record.idempotencyKey!,
        cancelToken: cancelToken,
      );
      if (operation != _epoch || _disposed || !ref.mounted) {
        return;
      }
      await _applyStatus(
        status,
        pollCount: nextPollCount,
        customerId: customerId,
        operation: operation,
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
      if (ref.read(purchaseCustomerIdProvider) != customerId) {
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
    required int operation,
  }) async {
    switch (status.state) {
      case CheckoutStatusState.completed:
        final order = status.order;
        if (order == null) {
          if (ref.read(purchaseCustomerIdProvider) == customerId) {
            state = const CheckoutRecoveryState(
              phase: CheckoutRecoveryPhase.error,
            );
          }
          return;
        }
        await _finalizeCompletedRecovery(
          order: order,
          customerId: customerId,
          operation: operation,
          pollCount: pollCount,
        );
      case CheckoutStatusState.failed:
        if (ref.read(purchaseCustomerIdProvider) != customerId) {
          return;
        }
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
        if (ref.read(purchaseCustomerIdProvider) != customerId) {
          return;
        }
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

  Future<void> _finalizeCompletedRecovery({
    required PurchaseReceipt order,
    required int customerId,
    required int operation,
    required int pollCount,
  }) async {
    await _pendingStore.markCompleted(
      customerId: customerId,
      orderNumber: order.orderNumber,
    );

    final stillSameOperation = operation == _epoch && !_disposed;
    final activeCustomer = ref.read(purchaseCustomerIdProvider);
    if (!stillSameOperation || activeCustomer != customerId) {
      await _pendingStore.clearPendingKey(customerId);
      return;
    }

    _stopPolling();
    ref.read(purchaseDraftControllerProvider.notifier).clear();
    unawaited(ref.read(walletSummaryControllerProvider.notifier).refresh());
    state = CheckoutRecoveryState(
      phase: CheckoutRecoveryPhase.completed,
      receipt: order,
      pollCount: pollCount,
    );
    await _pendingStore.clearPendingKey(customerId);
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

  /// Clears in-memory recovery UI without deleting durable recovery records.
  void acknowledgeTerminal() {
    _stopPolling();
    state = const CheckoutRecoveryState.idle();
  }

  /// Explicit receipt Done/Home acknowledgement. Clears this customer's anchor.
  Future<void> acknowledgeCompletedReceipt() async {
    final customerId = ref.read(purchaseCustomerIdProvider);
    if (customerId != null) {
      await _pendingStore.clearForCustomer(customerId);
    }
    _stopPolling();
    state = const CheckoutRecoveryState.idle();
    ref
        .read(checkoutReviewControllerProvider.notifier)
        .resetAfterAcknowledgement();
  }

  Future<bool> _applyAuthoritativeRejection(ApiException error) {
    return ref
        .read(authControllerProvider.notifier)
        .applyAuthoritativeRejection(error);
  }
}
