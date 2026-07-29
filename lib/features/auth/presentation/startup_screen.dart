import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:indirimgo_mobile/core/localization/generated/app_localizations.dart';
import 'package:indirimgo_mobile/core/theme/app_theme.dart';
import 'package:indirimgo_mobile/features/auth/presentation/auth_controller.dart';

class StartupScreen extends ConsumerWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authControllerProvider);
    final failed = auth.phase == AuthPhase.verificationFailed;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Semantics(
                liveRegion: true,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: BrandColors.yellow,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Text(
                        l10n.brandLatin,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          color: BrandColors.ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Icon(
                      failed ? Icons.cloud_off_outlined : Icons.shield_outlined,
                      size: 52,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      failed ? l10n.offlineTitle : l10n.startupTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      failed ? l10n.offlineSubtitle : l10n.startupSubtitle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (failed)
                      FilledButton.icon(
                        key: const Key('session-retry'),
                        onPressed: ref
                            .read(authControllerProvider.notifier)
                            .restoreSession,
                        icon: const Icon(Icons.refresh),
                        label: Text(l10n.retryAction),
                      )
                    else
                      const CircularProgressIndicator(
                        color: BrandColors.yellow,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
