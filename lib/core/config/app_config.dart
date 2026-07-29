import 'package:flutter_riverpod/flutter_riverpod.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  throw StateError('AppConfig must be provided at the application boundary.');
});

class AppConfig {
  const AppConfig._(this.apiBaseUri);

  factory AppConfig({required String apiBaseUrl}) {
    final value = apiBaseUrl.trim();
    if (value.isEmpty) {
      throw const FormatException(
        'API_BASE_URL is missing. Pass it with --dart-define.',
      );
    }

    final parsed = Uri.tryParse(value);
    if (parsed == null ||
        !parsed.hasScheme ||
        !parsed.hasAuthority ||
        !const {'http', 'https'}.contains(parsed.scheme) ||
        parsed.userInfo.isNotEmpty ||
        parsed.query.isNotEmpty ||
        parsed.fragment.isNotEmpty) {
      throw const FormatException(
        'API_BASE_URL must be an absolute HTTP(S) URL without credentials, '
        'query parameters, or fragments.',
      );
    }

    final segments = parsed.pathSegments
        .where((part) => part.isNotEmpty)
        .toList();
    while (segments.length >= 4 &&
        segments[segments.length - 4] == 'api' &&
        segments[segments.length - 3] == 'v1' &&
        segments[segments.length - 2] == 'api' &&
        segments[segments.length - 1] == 'v1') {
      segments.removeRange(segments.length - 2, segments.length);
    }

    if (segments.isEmpty) {
      segments.addAll(const ['api', 'v1']);
    } else if (segments.length < 2 ||
        segments[segments.length - 2] != 'api' ||
        segments.last != 'v1') {
      throw const FormatException('API_BASE_URL path must end with /api/v1.');
    }

    return AppConfig._(
      parsed.replace(
        pathSegments: [...segments, ''],
        query: null,
        fragment: null,
      ),
    );
  }

  factory AppConfig.fromEnvironment() {
    return AppConfig(apiBaseUrl: const String.fromEnvironment('API_BASE_URL'));
  }

  final Uri apiBaseUri;

  String get apiBaseUrl => apiBaseUri.toString();
}
