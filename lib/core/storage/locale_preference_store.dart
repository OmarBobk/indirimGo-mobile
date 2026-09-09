import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted UI language choice. Not a customer or session secret.
enum LocalePreference {
  system,
  ar,
  en;

  static const storageKey = 'locale.preference';

  static LocalePreference parse(String? raw) {
    return switch (raw) {
      'ar' => LocalePreference.ar,
      'en' => LocalePreference.en,
      'system' => LocalePreference.system,
      _ => LocalePreference.system,
    };
  }

  String get storageValue => name;
}

abstract interface class LocalePreferenceStore {
  Future<LocalePreference> read();

  Future<void> write(LocalePreference preference);
}

class InMemoryLocalePreferenceStore implements LocalePreferenceStore {
  InMemoryLocalePreferenceStore({this.preference = LocalePreference.system});

  LocalePreference preference;
  Object? readError;

  @override
  Future<LocalePreference> read() async {
    final error = readError;
    if (error != null) {
      throw error;
    }
    return preference;
  }

  @override
  Future<void> write(LocalePreference value) async {
    preference = value;
  }
}

class SharedPreferencesLocaleStore implements LocalePreferenceStore {
  SharedPreferencesLocaleStore(this._prefs);

  final SharedPreferencesWithCache _prefs;

  static Future<SharedPreferencesLocaleStore> create() async {
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: {LocalePreference.storageKey},
      ),
    );
    return SharedPreferencesLocaleStore(prefs);
  }

  @override
  Future<LocalePreference> read() async {
    return LocalePreference.parse(
      _prefs.getString(LocalePreference.storageKey),
    );
  }

  @override
  Future<void> write(LocalePreference preference) async {
    await _prefs.setString(
      LocalePreference.storageKey,
      preference.storageValue,
    );
  }
}

final localePreferenceStoreProvider = Provider<LocalePreferenceStore>((ref) {
  throw StateError('localePreferenceStoreProvider must be overridden.');
});
