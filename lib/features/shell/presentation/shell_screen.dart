import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:indirimgo_mobile/core/localization/generated/app_localizations.dart';
import 'package:indirimgo_mobile/core/theme/app_theme.dart';
import 'package:indirimgo_mobile/core/widgets/api_error_message.dart';
import 'package:indirimgo_mobile/features/auth/presentation/auth_controller.dart';

class ShellScreen extends ConsumerWidget {
  const ShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    final isLoggingOut = auth.phase == AuthPhase.loggingOut;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.brandLatin,
          textDirection: TextDirection.ltr,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: BrandColors.yellow,
        foregroundColor: BrandColors.ink,
      ),
      body: SafeArea(
        child: user == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                key: const Key('authenticated-shell'),
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  Text(
                    l10n.welcomeUser(user.name),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.home_outlined),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                l10n.homeTitle,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            l10n.homePlaceholder,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(l10n.homePlaceholderBody),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.account_circle_outlined),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                l10n.accountTitle,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          SelectableText(l10n.usernameValue(user.username)),
                          const SizedBox(height: AppSpacing.xs),
                          SelectableText(l10n.emailValue(user.email)),
                          if (auth.error != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                localizedApiError(l10n, auth.error),
                                key: const Key('logout-error'),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          OutlinedButton.icon(
                            key: const Key('logout-button'),
                            onPressed: isLoggingOut
                                ? null
                                : ref
                                      .read(authControllerProvider.notifier)
                                      .logout,
                            icon: isLoggingOut
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.logout),
                            label: Text(
                              isLoggingOut
                                  ? l10n.loggingOut
                                  : l10n.logoutAction,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
