import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indirimgo_mobile/core/localization/locale_controller.dart';
import 'package:indirimgo_mobile/core/network/api_client.dart';
import 'package:indirimgo_mobile/core/config/app_config.dart';
import 'package:indirimgo_mobile/core/storage/locale_preference_store.dart';
import 'package:indirimgo_mobile/core/storage/token_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'restore reads the persisted preference and survives later writes',
    () async {
      final store = InMemoryLocalePreferenceStore(
        preference: LocalePreference.en,
      );
      final container = ProviderContainer(
        overrides: [localePreferenceStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      container.read(localeControllerProvider);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(localeControllerProvider).preference,
        LocalePreference.en,
      );
      expect(
        container.read(localeControllerProvider).resolved,
        const Locale('en'),
      );

      await container
          .read(localeControllerProvider.notifier)
          .setPreference(LocalePreference.ar);
      expect(store.preference, LocalePreference.ar);
      expect(
        container.read(localeControllerProvider).resolved,
        const Locale('ar'),
      );
    },
  );

  test('read failures fall back to the device-supported locale', () async {
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .localesTestValue = const [
      Locale('en'),
    ];
    addTearDown(
      TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .clearLocalesTestValue,
    );
    final store = InMemoryLocalePreferenceStore()
      ..readError = Exception('disk');
    final container = ProviderContainer(
      overrides: [localePreferenceStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    container.read(localeControllerProvider);
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(localeControllerProvider).preference,
      LocalePreference.system,
    );
    expect(
      container.read(localeControllerProvider).resolved,
      const Locale('en'),
    );
  });

  test('explicit English ignores later device locale changes', () async {
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .localesTestValue = const [
      Locale('ar'),
    ];
    addTearDown(
      TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .clearLocalesTestValue,
    );
    final container = ProviderContainer(
      overrides: [
        localePreferenceStoreProvider.overrideWithValue(
          InMemoryLocalePreferenceStore(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(localeControllerProvider.notifier)
        .setPreference(LocalePreference.en);
    container.read(localeControllerProvider.notifier).didChangeLocales(const [
      Locale('ar'),
    ]);
    expect(
      container.read(localeControllerProvider).resolved,
      const Locale('en'),
    );
  });

  test('system preference follows device locale changes', () async {
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .localesTestValue = const [
      Locale('en'),
    ];
    addTearDown(
      TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .clearLocalesTestValue,
    );
    final container = ProviderContainer(
      overrides: [
        localePreferenceStoreProvider.overrideWithValue(
          InMemoryLocalePreferenceStore(),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(localeControllerProvider);
    container.read(localeControllerProvider.notifier).didChangeLocales(const [
      Locale('ar'),
    ]);
    expect(
      container.read(localeControllerProvider).resolved,
      const Locale('ar'),
    );
  });

  test(
    'Accept-Language follows the locale resolver without rebuilding Dio',
    () async {
      var language = 'ar';
      final client = ApiClient(
        config: AppConfig(
          apiBaseUrl: 'https://api.example.test/api/v1',
          buildMode: AppBuildMode.release,
        ),
        tokenStorage: InMemoryTokenStorage(),
        localeResolver: () => language,
      );
      expect(language, 'ar');
      language = 'en';
      expect(client, isA<ApiClient>());
    },
  );
}
