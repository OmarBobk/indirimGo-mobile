import 'package:flutter_riverpod/flutter_riverpod.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  throw StateError('AppConfig must be provided at the application boundary.');
});

enum AppBuildMode { debug, profile, release }

class AppConfig {
  const AppConfig._(this.apiBaseUri, this.buildMode);

  factory AppConfig({
    required String apiBaseUrl,
    required AppBuildMode buildMode,
  }) {
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

    if (parsed.scheme == 'http' &&
        (buildMode != AppBuildMode.debug ||
            !_debugHttpHosts.contains(parsed.host.toLowerCase()))) {
      throw const FormatException(
        'HTTP API_BASE_URL is allowed only in debug builds for an approved '
        'local emulator or loopback host.',
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
      buildMode,
    );
  }

  factory AppConfig.fromEnvironment({required AppBuildMode buildMode}) {
    return AppConfig(
      apiBaseUrl: const String.fromEnvironment('API_BASE_URL'),
      buildMode: buildMode,
    );
  }

  final Uri apiBaseUri;
  final AppBuildMode buildMode;

  String get apiBaseUrl => apiBaseUri.toString();
}

const _debugHttpHosts = {'10.0.2.2', '127.0.0.1', 'localhost'};
