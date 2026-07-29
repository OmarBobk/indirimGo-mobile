import 'package:indirimgo_mobile/core/storage/token_storage.dart';

enum ApiErrorKind {
  validation,
  unauthorized,
  forbidden,
  rateLimited,
  network,
  server,
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
};

class ApiException implements Exception {
  const ApiException({
    required this.kind,
    this.code,
    this.fieldErrors = const {},
    this.statusCode,
    this.retryAfterSeconds,
    this.requestSession,
  });

  final ApiErrorKind kind;
  final String? code;
  final Map<String, List<String>> fieldErrors;
  final int? statusCode;
  final int? retryAfterSeconds;
  final SessionReference? requestSession;

  bool get isAuthoritativeSessionRejection =>
      kind == ApiErrorKind.unauthorized || kind == ApiErrorKind.forbidden;

  bool get isRecoverableSessionFailure =>
      kind == ApiErrorKind.network || kind == ApiErrorKind.server;

  @override
  String toString() => 'ApiException(kind: $kind, statusCode: $statusCode)';
}
