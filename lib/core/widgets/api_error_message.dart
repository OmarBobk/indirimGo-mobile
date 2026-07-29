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
    return l10n.serverError;
  }
  if (error.kind == ApiErrorKind.rateLimited) {
    final seconds = error.retryAfterSeconds;
    return seconds == null
        ? l10n.tooManyRequests
        : l10n.rateLimitSeconds(seconds);
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
    'unauthenticated' || 'missing_mobile_ability' => l10n.unauthenticated,
    _ => error.message ?? l10n.sessionFailure,
  };
}
