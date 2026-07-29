import 'package:flutter_test/flutter_test.dart';
import 'package:indirimgo_mobile/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('normalizes an origin to the v1 API root', () {
      final config = AppConfig(apiBaseUrl: 'http://10.0.2.2:8000');

      expect(config.apiBaseUrl, 'http://10.0.2.2:8000/api/v1/');
    });

    test('removes trailing and repeated path slashes', () {
      final config = AppConfig(apiBaseUrl: 'http://10.0.2.2:8000//api//v1//');

      expect(config.apiBaseUrl, 'http://10.0.2.2:8000/api/v1/');
    });

    test('collapses an accidental repeated api v1 suffix', () {
      final config = AppConfig(
        apiBaseUrl: 'https://example.test/api/v1/api/v1',
      );

      expect(config.apiBaseUrl, 'https://example.test/api/v1/');
    });

    test('rejects missing and unsafe definitions', () {
      expect(() => AppConfig(apiBaseUrl: ''), throwsA(isA<FormatException>()));
      expect(
        () => AppConfig(apiBaseUrl: 'example.test/api/v1'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => AppConfig(apiBaseUrl: 'https://user:pass@example.test/api/v1'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => AppConfig(apiBaseUrl: 'https://example.test/other'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
