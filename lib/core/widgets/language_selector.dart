import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:indirimgo_mobile/core/localization/generated/app_localizations.dart';
import 'package:indirimgo_mobile/core/localization/locale_controller.dart';
import 'package:indirimgo_mobile/core/storage/locale_preference_store.dart';

class LanguageSelector extends ConsumerWidget {
  const LanguageSelector({
    super.key,
    this.compact = false,
    this.enabled = true,
  });

  final bool compact;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(localeControllerProvider);
    final items = <(LocalePreference, String)>[
      (LocalePreference.system, l10n.languagePreferenceSystem),
      (LocalePreference.ar, l10n.languagePreferenceArabic),
      (LocalePreference.en, l10n.languagePreferenceEnglish),
    ];

    return Semantics(
      button: true,
      label: l10n.languagePreferenceTitle,
      child: PopupMenuButton<LocalePreference>(
        key: compact
            ? const Key('language-toggle')
            : const Key('account-language-menu'),
        enabled: enabled,
        tooltip: l10n.languagePreferenceTitle,
        padding: compact ? EdgeInsets.zero : const EdgeInsets.all(8),
        initialValue: settings.preference,
        onSelected: (value) {
          ref.read(localeControllerProvider.notifier).setPreference(value);
        },
        itemBuilder: (context) {
          return [
            for (final item in items)
              PopupMenuItem<LocalePreference>(
                key: Key('language-option-${item.$1.name}'),
                value: item.$1,
                child: Text(item.$2),
              ),
          ];
        },
        child: compact
            ? const SizedBox(width: 48, height: 48, child: Icon(Icons.language))
            : ListTile(
                key: const Key('account-language'),
                contentPadding: EdgeInsets.zero,
                minTileHeight: 48,
                leading: const Icon(Icons.language),
                title: Text(l10n.languagePreferenceTitle),
                subtitle: Text(_labelFor(l10n, settings.preference)),
                trailing: const Icon(Icons.expand_more),
              ),
      ),
    );
  }

  String _labelFor(AppLocalizations l10n, LocalePreference preference) {
    return switch (preference) {
      LocalePreference.system => l10n.languagePreferenceSystem,
      LocalePreference.ar => l10n.languagePreferenceArabic,
      LocalePreference.en => l10n.languagePreferenceEnglish,
    };
  }
}
