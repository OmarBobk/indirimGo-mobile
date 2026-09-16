import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:indirimgo_mobile/core/localization/generated/app_localizations.dart';
import 'package:indirimgo_mobile/core/routing/app_router.dart';
import 'package:indirimgo_mobile/core/theme/app_theme.dart';
import 'package:indirimgo_mobile/core/widgets/api_error_message.dart';
import 'package:indirimgo_mobile/core/widgets/refresh_progress_slot.dart';
import 'package:indirimgo_mobile/features/catalog/presentation/widgets/catalog_widgets.dart';
import 'package:indirimgo_mobile/features/wallet/presentation/topup_detail_controller.dart';
import 'package:indirimgo_mobile/features/wallet/presentation/wallet_labels.dart';

class TopupDetailScreen extends ConsumerStatefulWidget {
  const TopupDetailScreen({super.key, required this.publicRef});

  final String publicRef;

  @override
  ConsumerState<TopupDetailScreen> createState() => _TopupDetailScreenState();
}

class _TopupDetailScreenState extends ConsumerState<TopupDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(topupDetailControllerProvider.notifier).load(widget.publicRef);
    });
  }

  @override
  void didUpdateWidget(TopupDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.publicRef != widget.publicRef) {
      ref.read(topupDetailControllerProvider.notifier).load(widget.publicRef);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(topupDetailControllerProvider);
    final detail = state.detail;
    final refreshing = state.phase == TopupDetailPhase.refreshing;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.topupDetailTitle),
        backgroundColor: BrandColors.yellow,
        foregroundColor: BrandColors.ink,
        actions: [
          IconButton(
            key: const Key('topup-detail-refresh'),
            tooltip: l10n.refreshTopupAction,
            onPressed: () =>
                ref.read(topupDetailControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            RefreshProgressSlot(active: refreshing),
            Expanded(
              child: switch (state.phase) {
                TopupDetailPhase.idle ||
                TopupDetailPhase.loading when detail == null => Center(
                  child: Semantics(
                    liveRegion: true,
                    label: l10n.walletLoading,
                    child: const CircularProgressIndicator(),
                  ),
                ),
                TopupDetailPhase.error when detail == null => ListView(
                  padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                  children: [
                    Text(
                      localizedApiError(l10n, state.error),
                      key: const Key('topup-detail-error'),
                    ),
                    TextButton(
                      onPressed: () => ref
                          .read(topupDetailControllerProvider.notifier)
                          .refresh(),
                      child: Text(l10n.retryAction),
                    ),
                  ],
                ),
                _ when detail != null => ListView(
                  key: const Key('topup-detail-screen'),
                  padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                  children: [
                    Text(
                      l10n.topupReferenceLabel(detail.publicRef),
                      textDirection: TextDirection.ltr,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      localizedTopupStatusValue(
                        l10n,
                        detail.status,
                        credited: detail.credited,
                        pending: detail.pendingUntilAdminApproval,
                      ),
                      key: const Key('topup-detail-status'),
                    ),
                    if (detail.pendingUntilAdminApproval) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(l10n.topupPendingNotice),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Text(l10n.enteredAmountLabel),
                    Text(
                      detail.enteredDisplay.formatted,
                      textDirection: TextDirection.ltr,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(l10n.walletCreditLabel),
                    CatalogPriceText(
                      pricesVisible: true,
                      money: detail.walletAmount,
                    ),
                    if (detail.paymentMethod != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(l10n.paymentMethodLabel),
                      Text(detail.paymentMethod!.name),
                      if (detail.paymentMethod!.instructions != null)
                        Text(detail.paymentMethod!.instructions!),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      detail.hasProof ? l10n.topupHasProof : l10n.topupNoProof,
                    ),
                    if (detail.customerSafeReason != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(detail.customerSafeReason!),
                    ],
                    if (detail.canRetry) ...[
                      const SizedBox(height: AppSpacing.lg),
                      OutlinedButton(
                        key: const Key('topup-retry'),
                        onPressed: () => context.push(AppRoutes.walletTopup),
                        child: Text(l10n.retryTopupAction),
                      ),
                    ],
                  ],
                ),
                _ => Center(child: Text(l10n.topupNotFound)),
              },
            ),
          ],
        ),
      ),
    );
  }
}
