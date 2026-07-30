import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:indirimgo_mobile/core/config/app_config.dart';
import 'package:indirimgo_mobile/core/errors/api_exception.dart';
import 'package:indirimgo_mobile/core/localization/locale_controller.dart';
import 'package:indirimgo_mobile/core/storage/token_storage.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    config: ref.watch(appConfigProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
    locale: ref.watch(localeControllerProvider).languageCode,
  );
  ref.onDispose(client.close);
  return client;
});

final class ApiResponse {
  const ApiResponse({
    required this.statusCode,
    required this.data,
    this.requestSession,
  });

  final int statusCode;
  final Map<String, Object?> data;
  final SessionReference? requestSession;
}

class ApiClient {
  ApiClient({
    required AppConfig config,
    required this.tokenStorage,
    required String locale,
    Dio? dio,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: config.apiBaseUrl,
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 20),
               sendTimeout: const Duration(seconds: 20),
               responseType: ResponseType.json,
             ),
           ) {
    _dio.options.baseUrl = config.apiBaseUrl;
    _dio.options.followRedirects = false;
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.headers[Headers.acceptHeader] = Headers.jsonContentType;
          options.headers['Accept-Language'] = locale;
          final session = await tokenStorage.read();
          if (session != null) {
            options.headers['Authorization'] = 'Bearer ${session.token}';
            options.extra[_requestSessionKey] = session.reference;
          } else {
            options.headers.remove('Authorization');
            options.extra.remove(_requestSessionKey);
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          try {
            if (error.response?.statusCode == 401) {
              final session = _requestSession(error.requestOptions);
              if (session != null) {
                await tokenStorage.clearIfCurrent(session);
              }
            }
          } on Object {
            // The authoritative HTTP response must remain the reported error.
          } finally {
            handler.next(error);
          }
        },
      ),
    );
  }

  final Dio _dio;
  final TokenStorage tokenStorage;

  Future<ApiResponse> get(
    String path, {
    Map<String, Object?>? queryParameters,
    CancelToken? cancelToken,
  }) => _request(
    path,
    method: 'GET',
    queryParameters: queryParameters,
    cancelToken: cancelToken,
  );

  Future<ApiResponse> post(String path, {Map<String, Object?>? data}) =>
      _request(path, method: 'POST', data: data);

  Future<ApiResponse> _request(
    String path, {
    required String method,
    Map<String, Object?>? data,
    Map<String, Object?>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.request<Object?>(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: Options(method: method),
      );
      final statusCode = response.statusCode;
      if (statusCode == null) {
        throw const FormatException('The API response status is missing.');
      }
      return ApiResponse(
        statusCode: statusCode,
        data: _asJsonMap(response.data),
        requestSession: _requestSession(response.requestOptions),
      );
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  ApiException _mapDioException(DioException error) {
    final statusCode = error.response?.statusCode;
    final body = _optionalJsonMap(error.response?.data);
    final rawCode = body?['code'];
    final code = rawCode is String && stableApiErrorCodes.contains(rawCode)
        ? rawCode
        : null;
    final fieldErrors = _parseFieldErrors(body?['errors']);
    final requestSession = _requestSession(error.requestOptions);

    if (error.type == DioExceptionType.cancel) {
      return ApiException(
        kind: ApiErrorKind.cancelled,
        requestSession: requestSession,
      );
    }
    if (statusCode == 401) {
      return ApiException(
        kind: ApiErrorKind.unauthorized,
        code: code,
        statusCode: statusCode,
        requestSession: requestSession,
      );
    }
    if (statusCode == 403) {
      return ApiException(
        kind: ApiErrorKind.forbidden,
        code: code,
        statusCode: statusCode,
        requestSession: requestSession,
      );
    }
    if (statusCode == 404) {
      return ApiException(
        kind: ApiErrorKind.notFound,
        code: code,
        statusCode: statusCode,
        requestSession: requestSession,
      );
    }
    if (statusCode == 422) {
      return ApiException(
        kind: ApiErrorKind.validation,
        code: code,
        fieldErrors: fieldErrors,
        statusCode: statusCode,
        requestSession: requestSession,
      );
    }
    if (statusCode == 429) {
      return ApiException(
        kind: ApiErrorKind.rateLimited,
        code: code ?? 'too_many_requests',
        statusCode: statusCode,
        retryAfterSeconds: int.tryParse(
          error.response?.headers.value('retry-after') ?? '',
        ),
        requestSession: requestSession,
      );
    }
    if (statusCode != null && statusCode >= 500) {
      return ApiException(
        kind: ApiErrorKind.server,
        code: code,
        statusCode: statusCode,
        requestSession: requestSession,
      );
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.error is SocketException) {
      return ApiException(
        kind: ApiErrorKind.network,
        requestSession: requestSession,
      );
    }
    return ApiException(
      kind: ApiErrorKind.unknown,
      code: code,
      statusCode: statusCode,
      requestSession: requestSession,
    );
  }

  void close() => _dio.close(force: true);
}

const _requestSessionKey = 'auth.request_session';

SessionReference? _requestSession(RequestOptions options) {
  final value = options.extra[_requestSessionKey];
  return value is SessionReference ? value : null;
}

Map<String, Object?> _asJsonMap(Object? value) {
  final mapped = _optionalJsonMap(value);
  if (mapped == null) {
    throw const FormatException('The API response must be a JSON object.');
  }
  return mapped;
}

Map<String, Object?>? _optionalJsonMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  return null;
}

Map<String, List<String>> _parseFieldErrors(Object? value) {
  final errors = _optionalJsonMap(value);
  if (errors == null) {
    return const {};
  }

  return {
    for (final entry in errors.entries)
      if (_validationFields.contains(entry.key) &&
          entry.value is List &&
          (entry.value! as List).isNotEmpty)
        entry.key: const ['invalid'],
  };
}

const _validationFields = {
  'username',
  'password',
  'device_name',
  'challenge_token',
  'code',
  'recovery_code',
  'category_id',
  'q',
  'page',
  'per_page',
};
