import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:indirimgo_mobile/core/localization/generated/app_localizations.dart';
import 'package:indirimgo_mobile/core/routing/app_router.dart';
import 'package:indirimgo_mobile/core/theme/app_theme.dart';
import 'package:indirimgo_mobile/core/widgets/api_error_message.dart';
import 'package:indirimgo_mobile/features/auth/presentation/auth_controller.dart';
import 'package:indirimgo_mobile/features/wallet/presentation/wallet_summary_section.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    final isLoggingOut = auth.phase == AuthPhase.loggingOut;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.accountTitle),
        backgroundColor: BrandColors.yellow,
        foregroundColor: BrandColors.ink,
      ),
      body: SafeArea(
        child: user == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                key: const Key('account-screen'),
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.welcomeUser(user.name),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          SelectableText(l10n.usernameValue(user.username)),
                          const SizedBox(height: AppSpacing.xs),
                          SelectableText(l10n.emailValue(user.email)),
                          const SizedBox(height: AppSpacing.lg),
                          ListTile(
                            key: const Key('account-orders'),
                            contentPadding: EdgeInsets.zero,
                            minTileHeight: 48,
                            leading: const Icon(Icons.receipt_long_outlined),
                            title: Text(l10n.ordersTitle),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push(AppRoutes.orders),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const WalletSummarySection(),
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
                          Semantics(
                            button: true,
                            liveRegion: isLoggingOut,
                            label: isLoggingOut
                                ? l10n.loggingOut
                                : l10n.logoutAction,
                            child: OutlinedButton.icon(
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
