import 'package:indirimgo_mobile/core/storage/token_storage.dart';

enum ApiErrorKind {
  validation,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  rateLimited,
  network,
  server,
  cancelled,
  unknown,
}

const stableApiErrorCodes = {
  'invalid_credentials',
  'account_inactive',
  'account_blocked',
  'customer_role_required',
  'invalid_two_factor_challenge',
  'invalid_two_factor_code',
  'invalid_recovery_code',
  'two_factor_attempts_exceeded',
  'unauthenticated',
  'missing_mobile_ability',
  'too_many_requests',
  'package_not_found',
  'purchasing_unavailable',
  'product_unavailable',
  'invalid_custom_amount',
  'price_changed',
  'insufficient_wallet_balance',
  'idempotency_conflict',
  'idempotency_key_required',
  'idempotency_key_invalid',
  'checkout_attempt_not_found',
  'checkout_in_progress',
  'checkout_retry_required',
  'checkout_failed',
  'order_not_found',
};

/// Stable API codes that prove the current mobile session cannot continue.
///
/// Used for HTTP 403 classification only. HTTP 401 is always session-ending.
/// Generic/resource 403 responses must not appear here.
const authoritativeSessionRejectionCodes = {
  'account_inactive',
  'account_blocked',
  'customer_role_required',
  'missing_mobile_ability',
  'unauthenticated',
};

class ApiException implements Exception {
  const ApiException({
    required this.kind,
    this.code,
    this.fieldErrors = const {},
    this.statusCode,
    this.retryAfterSeconds,
    this.requestSession,
    this.details,
  });

  final ApiErrorKind kind;
  final String? code;
  final Map<String, List<String>> fieldErrors;
  final int? statusCode;
  final int? retryAfterSeconds;
  final SessionReference? requestSession;

  /// Optional structured API `details`. Never logged or stringified.
  final Map<String, Object?>? details;

  /// Whether this error ends the mobile session for the request's generation.
  ///
  /// Classification uses HTTP status plus allowlisted stable codes only —
  /// never localized or raw server messages.
  bool get isAuthoritativeSessionRejection {
    if (kind == ApiErrorKind.unauthorized || statusCode == 401) {
      return true;
    }
    if (kind == ApiErrorKind.forbidden || statusCode == 403) {
      final code = this.code;
      return code != null && authoritativeSessionRejectionCodes.contains(code);
    }
    return false;
  }

  bool get isRecoverableSessionFailure =>
      kind == ApiErrorKind.network || kind == ApiErrorKind.server;

  @override
  String toString() => 'ApiException(kind: $kind, statusCode: $statusCode)';
}
