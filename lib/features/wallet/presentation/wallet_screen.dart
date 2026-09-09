import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:indirimgo_mobile/core/localization/generated/app_localizations.dart';
import 'package:indirimgo_mobile/core/routing/app_router.dart';
import 'package:indirimgo_mobile/core/theme/app_theme.dart';
import 'package:indirimgo_mobile/core/widgets/api_error_message.dart';
import 'package:indirimgo_mobile/core/widgets/refresh_progress_slot.dart';
import 'package:indirimgo_mobile/features/catalog/presentation/widgets/catalog_widgets.dart';
import 'package:indirimgo_mobile/features/wallet/domain/wallet_models.dart';
import 'package:indirimgo_mobile/features/wallet/presentation/wallet_controllers.dart';
import 'package:indirimgo_mobile/features/wallet/presentation/wallet_labels.dart';
import 'package:indirimgo_mobile/features/wallet/presentation/wallet_workspace_controller.dart';
import 'package:intl/intl.dart' hide TextDirection;

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final summary = ref.watch(walletSummaryControllerProvider);
    final workspace = ref.watch(walletWorkspaceControllerProvider);
    final refreshing =
        summary.phase == WalletLoadPhase.refreshing ||
        workspace.phase == WalletListPhase.refreshing;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.walletTitle),
        backgroundColor: BrandColors.yellow,
        foregroundColor: BrandColors.ink,
        actions: [
          IconButton(
            key: const Key('wallet-refresh'),
            tooltip: l10n.refreshWalletAction,
            onPressed: () =>
                ref.read(walletWorkspaceControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            RefreshProgressSlot(active: refreshing),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref
                    .read(walletWorkspaceControllerProvider.notifier)
                    .refresh(),
                child: ListView(
                  key: const Key('wallet-screen'),
                  padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                  children: [
                    _SummaryCard(summary: summary),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.icon(
                      key: const Key('wallet-add-funds'),
                      onPressed: () => context.push(AppRoutes.walletTopup),
                      icon: const Icon(Icons.add),
                      label: Text(l10n.addFundsAction),
                    ),
                    if (summary.summary?.pendingTopupPublicRef != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _PendingBanner(
                        publicRef: summary.summary!.pendingTopupPublicRef!,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      l10n.topupsTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _TopupList(workspace: workspace),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      l10n.transactionsTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _TransactionList(workspace: workspace),
                    if (workspace.phase == WalletListPhase.error &&
                        workspace.hasContent) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(localizedApiError(l10n, workspace.error)),
                    ],
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final WalletSummaryState summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: switch (summary.phase) {
          WalletLoadPhase.idle ||
          WalletLoadPhase.loading when !summary.hasContent => Semantics(
            liveRegion: true,
            label: l10n.walletLoading,
            child: const LinearProgressIndicator(
              key: Key('wallet-screen-summary-loading'),
            ),
          ),
          WalletLoadPhase.error when !summary.hasContent => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.walletUnavailableTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(localizedApiError(l10n, summary.error)),
            ],
          ),
          _ => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.availableToSpendLabel),
              const SizedBox(height: AppSpacing.xs),
              CatalogPriceText(
                key: const Key('wallet-screen-available'),
                pricesVisible: summary.summary?.pricesVisible ?? true,
                money: summary.summary?.availableToSpend,
              ),
            ],
          ),
        },
      ),
    );
  }
}

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.publicRef});

  final String publicRef;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.pendingTopupBanner),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              key: const Key('wallet-view-pending'),
              onPressed: () =>
                  context.push(AppRoutes.walletTopupDetail(publicRef)),
              child: Text(l10n.viewPendingTopupAction),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopupList extends ConsumerWidget {
  const _TopupList({required this.workspace});

  final WalletWorkspaceState workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (workspace.phase == WalletListPhase.loading && !workspace.hasContent) {
      return Semantics(
        liveRegion: true,
        label: l10n.walletLoading,
        child: const LinearProgressIndicator(),
      );
    }
    if (workspace.topups.isEmpty) {
      return Text(l10n.topupsEmptyBody);
    }
    return Column(
      children: [
        for (final item in workspace.topups) _TopupTile(item: item),
        if (workspace.canLoadMoreTopups)
          TextButton(
            key: const Key('wallet-load-more-topups'),
            onPressed: () => ref
                .read(walletWorkspaceControllerProvider.notifier)
                .loadMoreTopups(),
            child: Text(l10n.loadMoreTopups),
          ),
      ],
    );
  }
}

class _TopupTile extends StatelessWidget {
  const _TopupTile({required this.item});

  final TopupListItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = localizedTopupStatus(l10n, item);
    return Card(
      child: Semantics(
        button: true,
        label: l10n.topupCardSemantics(
          item.publicRef,
          status,
          item.walletAmount.display.formatted,
        ),
        child: ListTile(
          key: Key('wallet-topup-${item.publicRef}'),
          title: Text(item.publicRef, textDirection: TextDirection.ltr),
          subtitle: Text(status),
          trailing: Text(
            item.walletAmount.display.formatted,
            textDirection: TextDirection.ltr,
          ),
          onTap: () =>
              context.push(AppRoutes.walletTopupDetail(item.publicRef)),
        ),
      ),
    );
  }
}

class _TransactionList extends ConsumerWidget {
  const _TransactionList({required this.workspace});

  final WalletWorkspaceState workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (workspace.transactions.isEmpty) {
      return Text(l10n.transactionsEmptyBody);
    }
    final dateFormat = DateFormat.yMMMd(l10n.localeName);
    return Column(
      children: [
        for (final item in workspace.transactions)
          Card(
            child: Semantics(
              label: l10n.transactionCardSemantics(
                localizedTransactionType(l10n, item.type),
                localizedTransactionDirection(l10n, item.direction),
                item.amount.display.formatted,
                dateFormat.format(item.occurredAt.toLocal()),
              ),
              child: ListTile(
                key: Key('wallet-tx-${item.publicRef}'),
                title: Text(localizedTransactionType(l10n, item.type)),
                subtitle: Text(
                  '${localizedTransactionDirection(l10n, item.direction)} · ${dateFormat.format(item.occurredAt.toLocal())}',
                ),
                trailing: Text(
                  item.amount.display.formatted,
                  textDirection: TextDirection.ltr,
                ),
              ),
            ),
          ),
        if (workspace.canLoadMoreTransactions)
          TextButton(
            key: const Key('wallet-load-more-transactions'),
            onPressed: () => ref
                .read(walletWorkspaceControllerProvider.notifier)
                .loadMoreTransactions(),
            child: Text(l10n.loadMoreTransactions),
          ),
      ],
    );
  }
}
