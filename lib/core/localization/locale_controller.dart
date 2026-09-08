import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:indirimgo_mobile/core/storage/locale_preference_store.dart';

final localeControllerProvider =
    NotifierProvider<LocaleController, LocaleSettings>(LocaleController.new);

class LocaleSettings {
  const LocaleSettings({required this.preference, required this.resolved});

  final LocalePreference preference;
  final Locale resolved;
}

Locale resolveSupportedLocale(Iterable<Locale>? preferredLocales) {
  for (final locale in preferredLocales ?? const <Locale>[]) {
    if (locale.languageCode == 'ar' || locale.languageCode == 'en') {
      return Locale(locale.languageCode);
    }
  }
  return const Locale('ar');
}

class LocaleController extends Notifier<LocaleSettings>
    with WidgetsBindingObserver {
  bool _userSet = false;

  @override
  LocaleSettings build() {
    _userSet = false;
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(this));
    final initial = LocaleSettings(
      preference: LocalePreference.system,
      resolved: resolveSupportedLocale(
        WidgetsBinding.instance.platformDispatcher.locales,
      ),
    );
    Future<void>.microtask(_restore);
    return initial;
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (state.preference != LocalePreference.system) {
      return;
    }
    state = LocaleSettings(
      preference: LocalePreference.system,
      resolved: resolveSupportedLocale(locales),
    );
  }

  Future<void> setPreference(LocalePreference preference) async {
    _userSet = true;
    state = LocaleSettings(
      preference: preference,
      resolved: _resolvedFor(preference),
    );
    try {
      await ref.read(localePreferenceStoreProvider).write(preference);
    } on Object {
      // Preference write failures must not reset route, auth, or checkout.
    }
  }

  Future<void> _restore() async {
    if (_userSet) {
      return;
    }
    try {
      final stored = await ref.read(localePreferenceStoreProvider).read();
      if (_userSet) {
        return;
      }
      state = LocaleSettings(
        preference: stored,
        resolved: _resolvedFor(stored),
      );
    } on Object {
      state = LocaleSettings(
        preference: LocalePreference.system,
        resolved: resolveSupportedLocale(
          WidgetsBinding.instance.platformDispatcher.locales,
        ),
      );
    }
  }

  Locale _resolvedFor(LocalePreference preference) {
    return switch (preference) {
      LocalePreference.system => resolveSupportedLocale(
        WidgetsBinding.instance.platformDispatcher.locales,
      ),
      LocalePreference.ar => const Locale('ar'),
      LocalePreference.en => const Locale('en'),
    };
  }
}
