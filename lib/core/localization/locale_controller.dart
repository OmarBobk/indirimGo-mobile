import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final localeControllerProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

Locale resolveSupportedLocale(Iterable<Locale>? preferredLocales) {
  for (final locale in preferredLocales ?? const <Locale>[]) {
    if (locale.languageCode == 'ar' || locale.languageCode == 'en') {
      return Locale(locale.languageCode);
    }
  }
  return const Locale('ar');
}

class LocaleController extends Notifier<Locale> {
  @override
  Locale build() {
    return resolveSupportedLocale(
      WidgetsBinding.instance.platformDispatcher.locales,
    );
  }

  void setLocale(Locale locale) {
    state = resolveSupportedLocale([locale]);
  }

  void toggle() {
    state = Locale(state.languageCode == 'ar' ? 'en' : 'ar');
  }
}
