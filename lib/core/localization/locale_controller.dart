import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final localeControllerProvider =
    NotifierProvider<LocaleController, Locale>(LocaleController.new);

class LocaleController extends Notifier<Locale> {
  @override
  Locale build() {
    final deviceLocale = PlatformDispatcher.instance.locale;
    return Locale(deviceLocale.languageCode == 'en' ? 'en' : 'ar');
  }

  void setLocale(Locale locale) {
    state = Locale(locale.languageCode == 'en' ? 'en' : 'ar');
  }

  void toggle() {
    state = Locale(state.languageCode == 'ar' ? 'en' : 'ar');
  }
}
