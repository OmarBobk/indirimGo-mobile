import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:indirimgo_mobile/core/config/app_config.dart';
import 'package:indirimgo_mobile/core/errors/api_exception.dart';
import 'package:indirimgo_mobile/core/localization/locale_controller.dart';
import 'package:indirimgo_mobile/core/storage/token_storage.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    config: ref.watch(appConfigProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
    locale: ref.watch(localeControllerProvider).languageCode,
  );
});

class ApiClient {
  ApiClient({
    required AppConfig config,
    required TokenStorage tokenStorage,
    required String locale,
    Dio? dio,
  }) : _tokenStorage = tokenStorage,
       _dio =
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
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.headers[Headers.acceptHeader] = Headers.jsonContentType;
          options.headers['Accept-Language'] = locale;
          final session = await _tokenStorage.read();
          if (session != null) {
            options.headers['Authorization'] = 'Bearer ${session.token}';
          } else {
            options.headers.remove('Authorization');
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            await _tokenStorage.clear();
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;
  final TokenStorage _tokenStorage;

  Future<Map<String, Object?>> get(String path) =>
      _request(path, method: 'GET');

  Future<Map<String, Object?>> post(
    String path, {
    Map<String, Object?>? data,
  }) => _request(path, method: 'POST', data: data);

  Future<Map<String, Object?>> _request(
    String path, {
    required String method,
    Map<String, Object?>? data,
  }) async {
    try {
      final response = await _dio.request<Object?>(
        path,
        data: data,
        options: Options(method: method),
      );
      return _asJsonMap(response.data);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  ApiException _mapDioException(DioException error) {
    final statusCode = error.response?.statusCode;
    final body = _optionalJsonMap(error.response?.data);
    final code = body?['code'] is String ? body!['code'] as String : null;
    final message = body?['message'] is String ? body!['message'] as String : null;
    final fieldErrors = _parseFieldErrors(body?['errors']);

    if (statusCode == 401) {
      return ApiException(
        kind: ApiErrorKind.unauthorized,
        code: code,
        message: message,
        statusCode: statusCode,
      );
    }
    if (statusCode == 403) {
      return ApiException(
        kind: ApiErrorKind.forbidden,
        code: code,
        message: message,
        statusCode: statusCode,
      );
    }
    if (statusCode == 422) {
      return ApiException(
        kind: ApiErrorKind.validation,
        code: code,
        message: message,
        fieldErrors: fieldErrors,
        statusCode: statusCode,
      );
    }
    if (statusCode == 429) {
      return ApiException(
        kind: ApiErrorKind.rateLimited,
        code: code ?? 'too_many_requests',
        message: message,
        statusCode: statusCode,
        retryAfterSeconds: int.tryParse(
          error.response?.headers.value('retry-after') ?? '',
        ),
      );
    }
    if (statusCode != null && statusCode >= 500) {
      return ApiException(
        kind: ApiErrorKind.server,
        code: code,
        statusCode: statusCode,
      );
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.error is SocketException) {
      return const ApiException(kind: ApiErrorKind.network);
    }
    return ApiException(
      kind: ApiErrorKind.unknown,
      code: code,
      statusCode: statusCode,
    );
  }
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
      if (entry.value is List)
        entry.key: [
          for (final message in entry.value! as List)
            if (message is String) message,
        ],
  };
}
