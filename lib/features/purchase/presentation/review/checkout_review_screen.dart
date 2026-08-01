import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:indirimgo_mobile/core/localization/generated/app_localizations.dart';
import 'package:indirimgo_mobile/core/routing/app_router.dart';
import 'package:indirimgo_mobile/core/theme/app_theme.dart';
import 'package:indirimgo_mobile/core/widgets/api_error_message.dart';
import 'package:indirimgo_mobile/features/purchase/domain/purchase_models.dart';
import 'package:indirimgo_mobile/features/purchase/presentation/purchase_controllers.dart';
import 'package:indirimgo_mobile/features/purchase/presentation/widgets/purchase_widgets.dart';
import 'package:indirimgo_mobile/features/wallet/presentation/wallet_summary_section.dart';

class CheckoutReviewScreen extends ConsumerStatefulWidget {
  const CheckoutReviewScreen({super.key});

  @override
  ConsumerState<CheckoutReviewScreen> createState() =>
      _CheckoutReviewScreenState();
}

class _CheckoutReviewScreenState extends ConsumerState<CheckoutReviewScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(checkoutReviewControllerProvider.notifier).ensureFreshQuote();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref
          .read(checkoutReviewControllerProvider.notifier)
          .ensureFreshQuote(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final draft = ref.watch(purchaseDraftControllerProvider).draft;
    final review = ref.watch(checkoutReviewControllerProvider);

    ref.listen(checkoutReviewControllerProvider, (previous, next) {
      if (next.phase == CheckoutReviewPhase.success && next.receipt != null) {
        context.go(AppRoutes.orderReceipt(next.receipt!.orderNumber));
      } else if (next.phase == CheckoutReviewPhase.recoveryRequired) {
        context.go(AppRoutes.checkoutRecovery);
      }
    });

    if (draft?.quote == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.checkoutReviewTitle),
          backgroundColor: BrandColors.yellow,
          foregroundColor: BrandColors.ink,
        ),
        body: PurchaseStatusView(
          key: const Key('checkout-review-missing-quote'),
          title: l10n.checkoutReviewTitle,
          body: l10n.quoteMissingBody,
          actionLabel: l10n.backToPackages,
          onAction: () => context.go(AppRoutes.shell),
        ),
      );
    }

    final quote = draft!.quote!;
    final canConfirm = isCheckoutConfirmEnabled(quote: quote, review: review);
    final blockPop =
        review.phase == CheckoutReviewPhase.submitting ||
        review.submittingLocked ||
        review.phase == CheckoutReviewPhase.recoveryRequired ||
        review.phase == CheckoutReviewPhase.success;

    return PopScope(
      key: const Key('checkout-review-popscope'),
      canPop: !blockPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        if (review.phase == CheckoutReviewPhase.recoveryRequired) {
          context.go(AppRoutes.checkoutRecovery);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.checkoutReviewTitle),
          backgroundColor: BrandColors.yellow,
          foregroundColor: BrandColors.ink,
        ),
        body: SafeArea(
          child: ListView(
            key: const Key('checkout-review'),
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(
                quote.item.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                quote.item.amountMode == ProductAmountMode.fixed
                    ? l10n.quantityValue(quote.item.quantity)
                    : l10n.requestedAmountValue(
                        quote.item.requestedAmount ?? 0,
                      ),
              ),
              PurchaseSectionLabel(l10n.orderTotalsTitle),
              PurchaseMoneyText(
                key: const Key('line-total'),
                money: quote.item.lineTotal,
                label: l10n.lineTotalLabel,
              ),
              const SizedBox(height: AppSpacing.xs),
              PurchaseMoneyText(
                key: const Key('final-total'),
                money: quote.total,
                label: l10n.finalTotalLabel,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              PurchaseSectionLabel(l10n.walletSectionTitle),
              PurchaseMoneyText(
                key: const Key('available-to-spend'),
                money: quote.wallet.availableToSpend,
                label: l10n.availableToSpendLabel,
              ),
              const SizedBox(height: AppSpacing.sm),
              const WalletSummarySection(compact: true),
              const SizedBox(height: AppSpacing.sm),
              Text(
                key: const Key('quote-expiry'),
                l10n.quoteExpiresAt(
                  quote.expiresAt.toLocal().toIso8601String(),
                ),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (review.phase == CheckoutReviewPhase.priceChanged) ...[
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    key: const Key('price-changed-message'),
                    l10n.priceChangedBody,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              if (!quote.wallet.canAfford ||
                  review.phase == CheckoutReviewPhase.insufficientBalance) ...[
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    key: const Key('insufficient-balance-message'),
                    l10n.insufficientBalanceBody,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              if (review.phase == CheckoutReviewPhase.unavailable) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  key: const Key('purchasing-unavailable-message'),
                  l10n.purchaseUnavailableBody,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (review.error != null &&
                  review.phase == CheckoutReviewPhase.error) ...[
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    key: const Key('checkout-error'),
                    localizedApiError(l10n, review.error),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  key: const Key('confirm-wallet-purchase'),
                  onPressed: canConfirm
                      ? () => ref
                            .read(checkoutReviewControllerProvider.notifier)
                            .confirmPurchase()
                      : null,
                  child: review.phase == CheckoutReviewPhase.submitting
                      ? Semantics(
                          liveRegion: true,
                          label: l10n.submittingPurchase,
                          child: const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : Text(l10n.confirmWalletChargeAction),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.confirmWalletChargeHint,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (review.phase == CheckoutReviewPhase.priceChanged) ...[
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  key: const Key('refresh-quote-action'),
                  onPressed: () => ref
                      .read(checkoutReviewControllerProvider.notifier)
                      .ensureFreshQuote(force: true),
                  child: Text(l10n.refreshQuoteAction),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
