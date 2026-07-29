import 'package:flutter_test/flutter_test.dart';
import 'package:indirimgo_mobile/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('accepts approved local HTTP hosts only in debug', () {
      for (final host in ['10.0.2.2', '127.0.0.1', 'localhost']) {
        final config = AppConfig(
          apiBaseUrl: 'http://$host:8000',
          buildMode: AppBuildMode.debug,
        );

        expect(config.apiBaseUrl, 'http://$host:8000/api/v1/');
      }
    });

    test('rejects arbitrary HTTP hosts and non-debug HTTP', () {
      expect(
        () => AppConfig(
          apiBaseUrl: 'http://example.test/api/v1',
          buildMode: AppBuildMode.debug,
        ),
        throwsA(isA<FormatException>()),
      );
      for (final mode in [AppBuildMode.profile, AppBuildMode.release]) {
        expect(
          () => AppConfig(
            apiBaseUrl: 'http://10.0.2.2:8000/api/v1',
            buildMode: mode,
          ),
          throwsA(isA<FormatException>()),
        );
      }
    });

    test('accepts HTTPS in every build mode', () {
      for (final mode in AppBuildMode.values) {
        final config = AppConfig(
          apiBaseUrl: 'https://api.example.test/api/v1',
          buildMode: mode,
        );
        expect(config.apiBaseUri.scheme, 'https');
      }
    });

    test('removes trailing and repeated path slashes', () {
      final config = AppConfig(
        apiBaseUrl: 'http://10.0.2.2:8000//api//v1//',
        buildMode: AppBuildMode.debug,
      );

      expect(config.apiBaseUrl, 'http://10.0.2.2:8000/api/v1/');
    });

    test('collapses an accidental repeated api v1 suffix', () {
      final config = AppConfig(
        apiBaseUrl: 'https://example.test/api/v1/api/v1',
        buildMode: AppBuildMode.release,
      );

      expect(config.apiBaseUrl, 'https://example.test/api/v1/');
    });

    test('rejects missing and unsafe definitions', () {
      expect(
        () => AppConfig(apiBaseUrl: '', buildMode: AppBuildMode.debug),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => AppConfig(
          apiBaseUrl: 'example.test/api/v1',
          buildMode: AppBuildMode.release,
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => AppConfig(
          apiBaseUrl: 'https://user:pass@example.test/api/v1',
          buildMode: AppBuildMode.release,
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => AppConfig(
          apiBaseUrl: 'https://example.test/other',
          buildMode: AppBuildMode.release,
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
