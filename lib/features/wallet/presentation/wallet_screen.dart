import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:indirimgo_mobile/core/localization/generated/app_localizations.dart';
import 'package:indirimgo_mobile/core/routing/app_router.dart';
import 'package:indirimgo_mobile/core/theme/app_theme.dart';
import 'package:indirimgo_mobile/core/widgets/api_error_message.dart';
import 'package:indirimgo_mobile/core/widgets/refresh_progress_slot.dart';
import 'package:indirimgo_mobile/features/auth/presentation/auth_controller.dart';
import 'package:indirimgo_mobile/features/catalog/presentation/widgets/catalog_widgets.dart';
import 'package:indirimgo_mobile/features/wallet/domain/wallet_models.dart';
import 'package:indirimgo_mobile/features/wallet/domain/wallet_repository.dart';
import 'package:indirimgo_mobile/features/wallet/presentation/wallet_controllers.dart';
import 'package:indirimgo_mobile/features/wallet/presentation/wallet_labels.dart';
import 'package:indirimgo_mobile/features/wallet/presentation/wallet_widgets.dart';
import 'package:indirimgo_mobile/features/wallet/presentation/wallet_workspace_controller.dart';
import 'package:intl/intl.dart' hide TextDirection;

enum _TopupFilter { all, pending, completed, rejected }

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _refreshController;
  final GlobalKey _historyKey = GlobalKey();
  bool _balanceVisible = true;
  _TopupFilter _filter = _TopupFilter.all;

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    _refreshController.repeat();
    try {
      await ref.read(walletWorkspaceControllerProvider.notifier).refresh();
    } finally {
      if (mounted) {
        _refreshController
          ..stop()
          ..reset();
      }
    }
  }

  Future<TopupDetail?> _loadRejectedTopup(String publicRef) async {
    try {
      return await ref.read(walletRepositoryProvider).fetchTopup(publicRef);
    } catch (error) {
      final mapped = recoverableWalletError(error);
      await ref
          .read(authControllerProvider.notifier)
          .applyAuthoritativeRejection(mapped);
      throw mapped;
    }
  }

  void _showRejectedReason(TopupListItem item) {
    final detail = _loadRejectedTopup(item.publicRef);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _RejectedTopupSheet(
        item: item,
        detail: detail,
        onViewDetails: () {
          Navigator.of(sheetContext).pop();
          context.push(AppRoutes.walletTopupDetail(item.publicRef));
        },
      ),
    );
  }

  void _scrollToHistory() {
    final historyContext = _historyKey.currentContext;
    if (historyContext != null) {
      Scrollable.ensureVisible(
        historyContext,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final summary = ref.watch(walletSummaryControllerProvider);
    final workspace = ref.watch(walletWorkspaceControllerProvider);
    final refreshing =
        summary.phase == WalletLoadPhase.refreshing || workspace.isRefreshing;

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? null
          : BrandColors.paper,
      appBar: AppBar(
        title: Text(l10n.walletTitle),
        centerTitle: false,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: context.pop,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          IconButton(
            key: const Key('wallet-refresh'),
            tooltip: l10n.refreshWalletAction,
            onPressed: refreshing ? null : _refresh,
            icon: RotationTransition(
              turns: _refreshController,
              child: const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            RefreshProgressSlot(active: refreshing),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  key: const Key('wallet-screen'),
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.xl,
                  ),
                  children: [
                    _SummaryCard(
                      summary: summary,
                      balanceVisible: _balanceVisible,
                      onToggleBalance: () =>
                          setState(() => _balanceVisible = !_balanceVisible),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: FilledButton.icon(
                            key: const Key('wallet-add-funds'),
                            onPressed: () =>
                                context.push(AppRoutes.walletTopup),
                            icon: const Icon(Icons.add_rounded),
                            label: Text(l10n.addFundsAction),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          flex: 2,
                          child: OutlinedButton.icon(
                            key: const Key('wallet-history'),
                            onPressed: _scrollToHistory,
                            icon: const Icon(Icons.receipt_long_outlined),
                            label: Text(l10n.walletHistoryAction),
                          ),
                        ),
                      ],
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
                      key: _historyKey,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _TopupFilters(
                      selected: _filter,
                      onSelected: (filter) => setState(() => _filter = filter),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _TopupList(
                      section: workspace.topupSection,
                      filter: _filter,
                      onRejectedTap: _showRejectedReason,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      l10n.transactionsTitle,
                      key: const Key('wallet-transactions-title'),
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
  const _SummaryCard({
    required this.summary,
    required this.balanceVisible,
    required this.onToggleBalance,
  });

  final WalletSummaryState summary;
  final bool balanceVisible;
  final VoidCallback onToggleBalance;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF24221B)
          : const Color(0xFFFFFCF0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: const BorderSide(color: Color(0xFFFDE68A)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md + 2),
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.availableBalanceLabel,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: BrandColors.mutedSlate,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('wallet-toggle-balance'),
                    tooltip: balanceVisible
                        ? l10n.hideBalanceAction
                        : l10n.showBalanceAction,
                    onPressed: onToggleBalance,
                    icon: Icon(
                      balanceVisible
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              CatalogPriceText(
                key: const Key('wallet-screen-available'),
                pricesVisible:
                    balanceVisible && (summary.summary?.pricesVisible ?? true),
                money: summary.summary?.availableToSpend,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
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

class _TopupFilters extends StatelessWidget {
  const _TopupFilters({required this.selected, required this.onSelected});

  final _TopupFilter selected;
  final ValueChanged<_TopupFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = {
      _TopupFilter.all: l10n.walletFilterAll,
      _TopupFilter.pending: l10n.walletFilterPending,
      _TopupFilter.completed: l10n.walletFilterCompleted,
      _TopupFilter.rejected: l10n.walletFilterRejected,
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in _TopupFilter.values)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                key: Key('wallet-filter-${filter.name}'),
                label: Text(labels[filter]!),
                selected: selected == filter,
                showCheckmark: false,
                onSelected: (_) => onSelected(filter),
              ),
            ),
        ],
      ),
    );
  }
}

class _TopupList extends ConsumerWidget {
  const _TopupList({
    required this.section,
    required this.filter,
    required this.onRejectedTap,
  });

  final WalletHistorySection<TopupListItem> section;
  final _TopupFilter filter;
  final ValueChanged<TopupListItem> onRejectedTap;

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
    final filteredItems = section.items
        .where((item) {
          return switch (filter) {
            _TopupFilter.all => true,
            _TopupFilter.pending => item.pendingUntilAdminApproval,
            _TopupFilter.completed =>
              item.credited || item.status == 'approved',
            _TopupFilter.rejected => item.status == 'rejected',
          };
        })
        .toList(growable: false);
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
        if (filteredItems.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(l10n.topupsEmptyBody),
          ),
        for (final item in filteredItems)
          _TopupTile(
            item: item,
            onTap: item.status == 'rejected'
                ? () => onRejectedTap(item)
                : () =>
                      context.push(AppRoutes.walletTopupDetail(item.publicRef)),
          ),
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
  const _TopupTile({required this.item, required this.onTap});

  final TopupListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = localizedTopupStatus(l10n, item);
    final statusTone = item.credited
        ? WalletStatusTone.success
        : item.status == 'rejected'
        ? WalletStatusTone.rejected
        : item.pendingUntilAdminApproval
        ? WalletStatusTone.pending
        : WalletStatusTone.neutral;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        key: Key('wallet-topup-${item.publicRef}'),
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ActivityIcon(
                icon: Icons.account_balance_rounded,
                tone: statusTone,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.paymentMethodName ?? l10n.transactionTypeTopup,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatActivityTime(l10n, item.submittedAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: BrandColors.mutedSlate,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _CopyableReference(publicRef: item.publicRef),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    item.walletAmount.display.formatted,
                    textDirection: TextDirection.ltr,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: item.credited
                          ? const Color(0xFF15803D)
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 96),
                    child: StatusBadge(label: status, tone: statusTone),
                  ),
                ],
              ),
            ],
          ),
        ),
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
        for (final item in section.items) _TransactionTile(item: item),
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

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.item});

  final WalletTransactionItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final credited = item.direction == 'credit';
    final tone = credited ? WalletStatusTone.success : WalletStatusTone.neutral;
    final icon = switch (item.type) {
      'purchase' => Icons.shopping_bag_outlined,
      'topup' => Icons.account_balance_rounded,
      'refund' => Icons.replay_rounded,
      _ => Icons.receipt_long_outlined,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        key: Key('wallet-tx-${item.publicRef}'),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ActivityIcon(icon: icon, tone: tone),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.customerSafeDescription ??
                        localizedTransactionType(l10n, item.type),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatActivityTime(l10n, item.occurredAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: BrandColors.mutedSlate,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _CopyableReference(publicRef: item.publicRef),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item.amount.display.formatted,
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: credited
                        ? const Color(0xFF15803D)
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                StatusBadge(
                  label: localizedTransactionDirection(l10n, item.direction),
                  tone: tone,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityIcon extends StatelessWidget {
  const _ActivityIcon({required this.icon, required this.tone});

  final IconData icon;
  final WalletStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final (color, background) = switch (tone) {
      WalletStatusTone.success => (
        const Color(0xFF15803D),
        const Color(0xFFF0FDF4),
      ),
      WalletStatusTone.pending => (
        const Color(0xFFB45309),
        const Color(0xFFFEF3C7),
      ),
      WalletStatusTone.rejected => (
        const Color(0xFFB91C1C),
        const Color(0xFFFEF2F2),
      ),
      WalletStatusTone.neutral => (
        const Color(0xFF475569),
        const Color(0xFFF1F5F9),
      ),
    };
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _CopyableReference extends StatelessWidget {
  const _CopyableReference({required this.publicRef});

  final String publicRef;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: '${l10n.copyAction} $publicRef',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: publicRef));
          if (!context.mounted) {
            return;
          }
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(l10n.copiedToClipboard)));
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _shortReference(publicRef),
                textDirection: TextDirection.ltr,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: BrandColors.mutedSlate,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.content_copy_rounded,
                size: 14,
                color: BrandColors.mutedSlate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RejectedTopupSheet extends StatelessWidget {
  const _RejectedTopupSheet({
    required this.item,
    required this.detail,
    required this.onViewDetails,
  });

  final TopupListItem item;
  final Future<TopupDetail?> detail;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const _ActivityIcon(
                  icon: Icons.error_outline_rounded,
                  tone: WalletStatusTone.rejected,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.topupRejectedTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        item.publicRef,
                        textDirection: TextDirection.ltr,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: BrandColors.mutedSlate,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            FutureBuilder<TopupDetail?>(
              future: detail,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text(
                    localizedApiError(
                      l10n,
                      recoverableWalletError(snapshot.error!),
                    ),
                  );
                }
                return Text(
                  snapshot.data?.customerSafeReason ??
                      l10n.topupRejectedReasonUnavailable,
                  style: Theme.of(context).textTheme.bodyLarge,
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: onViewDetails,
              child: Text(l10n.viewTopupDetailsAction),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatActivityTime(AppLocalizations l10n, DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now();
  final time = DateFormat.Hm(l10n.localeName).format(local);
  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    return l10n.walletTodayAt(time);
  }
  return '${DateFormat.MMMd(l10n.localeName).format(local)}, $time';
}

String _shortReference(String value) {
  if (value.length <= 13) {
    return value;
  }
  return '${value.substring(0, 7)}…${value.substring(value.length - 3)}';
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
