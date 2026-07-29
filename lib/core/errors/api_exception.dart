enum ApiErrorKind {
  validation,
  unauthorized,
  forbidden,
  rateLimited,
  network,
  server,
  unknown,
}

class ApiException implements Exception {
  const ApiException({
    required this.kind,
    this.code,
    this.message,
    this.fieldErrors = const {},
    this.statusCode,
    this.retryAfterSeconds,
  });

  final ApiErrorKind kind;
  final String? code;
  final String? message;
  final Map<String, List<String>> fieldErrors;
  final int? statusCode;
  final int? retryAfterSeconds;

  bool get isAuthoritativeSessionRejection =>
      kind == ApiErrorKind.unauthorized || kind == ApiErrorKind.forbidden;

  bool get isRecoverableSessionFailure =>
      kind == ApiErrorKind.network || kind == ApiErrorKind.server;

  @override
  String toString() =>
      'ApiException(kind: $kind, code: $code, statusCode: $statusCode)';
}
