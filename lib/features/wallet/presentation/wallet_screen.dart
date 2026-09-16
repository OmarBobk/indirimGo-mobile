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
        summary.phase == WalletLoadPhase.refreshing || workspace.isRefreshing;

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
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.xl,
                  ),
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
                    _TopupList(section: workspace.topupSection),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      l10n.transactionsTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _TransactionList(section: workspace.transactionSection),
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
  const _TopupList({required this.section});

  final WalletHistorySection<TopupListItem> section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (section.isLoadingInitial) {
      return Semantics(
        liveRegion: true,
        label: l10n.walletLoading,
        child: const LinearProgressIndicator(key: Key('wallet-topups-loading')),
      );
    }
    if (section.showError) {
      return _SectionError(
        titleKey: const Key('wallet-topups-error'),
        retryKey: const Key('wallet-retry-topups'),
        title: l10n.walletUnavailableTitle,
        body: localizedApiError(l10n, section.error),
        onRetry: () =>
            ref.read(walletWorkspaceControllerProvider.notifier).retryTopups(),
      );
    }
    if (section.showEmpty) {
      return Text(l10n.topupsEmptyBody, key: const Key('wallet-topups-empty'));
    }
    return Column(
      children: [
        if (section.showRefreshError)
          _SectionError(
            titleKey: const Key('wallet-topups-refresh-error'),
            retryKey: const Key('wallet-retry-topups'),
            title: l10n.walletUnavailableTitle,
            body: localizedApiError(l10n, section.error),
            onRetry: () => ref
                .read(walletWorkspaceControllerProvider.notifier)
                .retryTopups(),
          ),
        for (final item in section.items) _TopupTile(item: item),
        if (section.canRetryLoadMore)
          TextButton(
            key: const Key('wallet-retry-more-topups'),
            onPressed: () => ref
                .read(walletWorkspaceControllerProvider.notifier)
                .loadMoreTopups(),
            child: Text(l10n.retryAction),
          )
        else if (section.canLoadMore)
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
      child: ListTile(
        key: Key('wallet-topup-${item.publicRef}'),
        title: Text(item.publicRef, textDirection: TextDirection.ltr),
        subtitle: Text(status),
        trailing: Text(
          item.walletAmount.display.formatted,
          textDirection: TextDirection.ltr,
        ),
        onTap: () => context.push(AppRoutes.walletTopupDetail(item.publicRef)),
      ),
    );
  }
}

class _TransactionList extends ConsumerWidget {
  const _TransactionList({required this.section});

  final WalletHistorySection<WalletTransactionItem> section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (section.isLoadingInitial) {
      return Semantics(
        liveRegion: true,
        label: l10n.walletLoading,
        child: const LinearProgressIndicator(
          key: Key('wallet-transactions-loading'),
        ),
      );
    }
    if (section.showError) {
      return _SectionError(
        titleKey: const Key('wallet-transactions-error'),
        retryKey: const Key('wallet-retry-transactions'),
        title: l10n.walletUnavailableTitle,
        body: localizedApiError(l10n, section.error),
        onRetry: () => ref
            .read(walletWorkspaceControllerProvider.notifier)
            .retryTransactions(),
      );
    }
    if (section.showEmpty) {
      return Text(
        l10n.transactionsEmptyBody,
        key: const Key('wallet-transactions-empty'),
      );
    }
    final dateFormat = DateFormat.yMMMd(l10n.localeName);
    return Column(
      children: [
        if (section.showRefreshError)
          _SectionError(
            titleKey: const Key('wallet-transactions-refresh-error'),
            retryKey: const Key('wallet-retry-transactions'),
            title: l10n.walletUnavailableTitle,
            body: localizedApiError(l10n, section.error),
            onRetry: () => ref
                .read(walletWorkspaceControllerProvider.notifier)
                .retryTransactions(),
          ),
        for (final item in section.items)
          Card(
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
        if (section.canRetryLoadMore)
          TextButton(
            key: const Key('wallet-retry-more-transactions'),
            onPressed: () => ref
                .read(walletWorkspaceControllerProvider.notifier)
                .loadMoreTransactions(),
            child: Text(l10n.retryAction),
          )
        else if (section.canLoadMore)
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

class _SectionError extends StatelessWidget {
  const _SectionError({
    required this.titleKey,
    required this.retryKey,
    required this.title,
    required this.body,
    required this.onRetry,
  });

  final Key titleKey;
  final Key retryKey;
  final String title;
  final String body;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          key: titleKey,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(body),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: retryKey,
            onPressed: onRetry,
            child: Text(l10n.retryAction),
          ),
        ),
      ],
    );
  }
}
