import 'package:indirimgo_mobile/core/errors/api_exception.dart';
import 'package:indirimgo_mobile/core/localization/generated/app_localizations.dart';

String localizedApiError(AppLocalizations l10n, ApiException? error) {
  if (error == null) {
    return l10n.sessionFailure;
  }
  if (error.kind == ApiErrorKind.network) {
    return l10n.networkError;
  }
  if (error.kind == ApiErrorKind.server) {
    if (error.code == 'checkout_failed') {
      return l10n.checkoutFailed;
    }
    return l10n.serverError;
  }
  if (error.kind == ApiErrorKind.rateLimited) {
    final seconds = error.retryAfterSeconds;
    return seconds == null
        ? l10n.tooManyRequests
        : l10n.rateLimitSeconds(seconds);
  }

  if (error.kind == ApiErrorKind.notFound ||
      error.code == 'package_not_found') {
    if (error.code == 'order_not_found') {
      return l10n.orderNotFound;
    }
    if (error.code == 'topup_not_found' ||
        error.code == 'topup_attempt_not_found' ||
        error.code == 'proof_not_found') {
      if (error.code == 'topup_attempt_not_found') {
        return l10n.topupAttemptNotFoundBody;
      }
      if (error.code == 'proof_not_found') {
        return l10n.proofNotFound;
      }
      return l10n.topupNotFound;
    }
    if (error.code == 'checkout_attempt_not_found') {
      return l10n.checkoutAttemptNotFoundBody;
    }
    return l10n.packageNotFound;
  }
  if (error.kind == ApiErrorKind.validation) {
    if (error.code == 'insufficient_wallet_balance') {
      return l10n.insufficientWalletBalance;
    }
    if (error.code == 'invalid_topup_amount') {
      return l10n.invalidTopupAmount;
    }
    if (error.code == 'topup_request_pending') {
      return l10n.topupRequestPending;
    }
    if (error.code == 'payment_method_unavailable') {
      return l10n.paymentMethodUnavailable;
    }
    if (error.code == 'topup_conversion_unavailable') {
      return l10n.topupConversionUnavailable;
    }
    if (error.code == 'invalid_custom_amount') {
      return l10n.invalidCustomAmount;
    }
    if (error.code == 'product_unavailable') {
      return l10n.productUnavailable;
    }
    if (error.fieldErrors.containsKey('q')) {
      return l10n.searchQueryInvalid;
    }
    if (error.fieldErrors.containsKey('category_id')) {
      return l10n.categoryFilterInvalid;
    }
  }

  return switch (error.code) {
    'invalid_credentials' => l10n.invalidCredentials,
    'account_inactive' => l10n.accountInactive,
    'account_blocked' => l10n.accountBlocked,
    'customer_role_required' => l10n.customerRoleRequired,
    'invalid_two_factor_challenge' => l10n.challengeExpired,
    'invalid_two_factor_code' => l10n.invalidTwoFactorCode,
    'invalid_recovery_code' => l10n.invalidRecoveryCode,
    'two_factor_attempts_exceeded' => l10n.twoFactorAttemptsExceeded,
    'too_many_requests' => l10n.tooManyRequests,
    'package_not_found' => l10n.packageNotFound,
    'purchasing_unavailable' => l10n.purchasingUnavailable,
    'product_unavailable' => l10n.productUnavailable,
    'invalid_custom_amount' => l10n.invalidCustomAmount,
    'price_changed' => l10n.priceChanged,
    'insufficient_wallet_balance' => l10n.insufficientWalletBalance,
    'idempotency_conflict' => l10n.idempotencyConflict,
    'checkout_in_progress' => l10n.checkoutInProgress,
    'checkout_retry_required' => l10n.checkoutRetryRequired,
    'checkout_failed' => l10n.checkoutFailed,
    'checkout_attempt_not_found' => l10n.checkoutAttemptNotFoundBody,
    'order_not_found' => l10n.orderNotFound,
    'topup_request_pending' => l10n.topupRequestPending,
    'topup_not_found' => l10n.topupNotFound,
    'topup_attempt_not_found' => l10n.topupAttemptNotFoundBody,
    'topup_in_progress' => l10n.topupInProgress,
    'topup_retry_required' => l10n.topupRetryRequired,
    'payment_method_unavailable' => l10n.paymentMethodUnavailable,
    'proof_not_found' => l10n.proofNotFound,
    'invalid_topup_amount' => l10n.invalidTopupAmount,
    'topup_conversion_unavailable' => l10n.topupConversionUnavailable,
    'unauthenticated' || 'missing_mobile_ability' => l10n.unauthenticated,
    _ => l10n.sessionFailure,
  };
}
