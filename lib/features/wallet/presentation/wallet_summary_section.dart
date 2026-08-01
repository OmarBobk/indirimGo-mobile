import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:indirimgo_mobile/core/localization/generated/app_localizations.dart';
import 'package:indirimgo_mobile/core/theme/app_theme.dart';
import 'package:indirimgo_mobile/core/widgets/api_error_message.dart';
import 'package:indirimgo_mobile/features/catalog/presentation/widgets/catalog_widgets.dart';
import 'package:indirimgo_mobile/features/wallet/presentation/wallet_controllers.dart';

class WalletSummarySection extends ConsumerWidget {
  const WalletSummarySection({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(walletSummaryControllerProvider);

    return Column(
      key: const Key('wallet-summary-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact)
          Text(
            l10n.walletSectionTitle,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        if (!compact) const SizedBox(height: AppSpacing.sm),
        switch (state.phase) {
          WalletLoadPhase.idle || WalletLoadPhase.loading =>
            const LinearProgressIndicator(key: Key('wallet-summary-loading')),
          WalletLoadPhase.refreshing ||
          WalletLoadPhase.ready when state.summary != null => CatalogPriceText(
            key: const Key('wallet-available-to-spend'),
            pricesVisible: true,
            money: state.summary!.availableToSpend,
            prefix: '${l10n.availableToSpendLabel} ',
          ),
          WalletLoadPhase.error => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                localizedApiError(l10n, state.error),
                key: const Key('wallet-summary-error'),
              ),
              TextButton(
                key: const Key('wallet-summary-retry'),
                onPressed: () => ref
                    .read(walletSummaryControllerProvider.notifier)
                    .refresh(),
                child: Text(l10n.retryAction),
              ),
            ],
          ),
          _ => Text(l10n.walletUnavailableBody),
        },
      ],
    );
  }
}
