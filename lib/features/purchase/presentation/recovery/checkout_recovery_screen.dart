import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:indirimgo_mobile/core/localization/generated/app_localizations.dart';
import 'package:indirimgo_mobile/core/routing/app_router.dart';
import 'package:indirimgo_mobile/core/theme/app_theme.dart';
import 'package:indirimgo_mobile/core/widgets/api_error_message.dart';
import 'package:indirimgo_mobile/features/purchase/presentation/purchase_controllers.dart';
import 'package:indirimgo_mobile/features/purchase/presentation/widgets/purchase_widgets.dart';

class CheckoutRecoveryScreen extends ConsumerWidget {
  const CheckoutRecoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(checkoutRecoveryControllerProvider);

    ref.listen(checkoutRecoveryControllerProvider, (previous, next) {
      if (next.phase == CheckoutRecoveryPhase.completed &&
          next.receipt != null) {
        ref
            .read(checkoutRecoveryControllerProvider.notifier)
            .acknowledgeTerminal();
        context.go(AppRoutes.orderReceipt(next.receipt!.orderNumber));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.checkoutRecoveryTitle),
        backgroundColor: BrandColors.yellow,
        foregroundColor: BrandColors.ink,
        automaticallyImplyLeading:
            state.phase != CheckoutRecoveryPhase.processing &&
            state.phase != CheckoutRecoveryPhase.checking,
      ),
      body: SafeArea(
        child: switch (state.phase) {
          CheckoutRecoveryPhase.idle => PurchaseStatusView(
            title: l10n.checkoutRecoveryTitle,
            body: l10n.checkoutRecoveryIdleBody,
            actionLabel: l10n.backToHomeAction,
            onAction: () => context.go(AppRoutes.shell),
          ),
          CheckoutRecoveryPhase.checking ||
          CheckoutRecoveryPhase.processing => Padding(
            key: const Key('checkout-recovery-processing'),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.checkoutRecoveryProcessingBody,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    key: const Key('checkout-recovery-manual-retry'),
                    onPressed: () => ref
                        .read(checkoutRecoveryControllerProvider.notifier)
                        .pollStatus(manual: true),
                    child: Text(l10n.retryAction),
                  ),
                ),
              ],
            ),
          ),
          CheckoutRecoveryPhase.completed => PurchaseStatusView(
            title: l10n.purchaseSuccessTitle,
            body: l10n.purchaseSuccessBody,
            icon: Icons.check_circle_outline,
            actionLabel: l10n.viewReceiptAction,
            onAction: () {
              final orderNumber = state.receipt?.orderNumber;
              if (orderNumber != null) {
                context.go(AppRoutes.orderReceipt(orderNumber));
              }
            },
          ),
          CheckoutRecoveryPhase.failed => PurchaseStatusView(
            key: const Key('checkout-recovery-failed'),
            title: l10n.checkoutFailedTitle,
            body: localizedApiError(l10n, state.error),
            icon: Icons.error_outline,
            actionLabel: l10n.backToHomeAction,
            onAction: () {
              ref
                  .read(checkoutRecoveryControllerProvider.notifier)
                  .acknowledgeTerminal();
              context.go(AppRoutes.shell);
            },
          ),
          CheckoutRecoveryPhase.retryRequiredRestart => PurchaseStatusView(
            key: const Key('checkout-recovery-restart'),
            title: l10n.checkoutRetryRequiredTitle,
            body: l10n.checkoutRetryRequiredBody,
            actionLabel: l10n.backToHomeAction,
            onAction: () {
              ref
                  .read(checkoutRecoveryControllerProvider.notifier)
                  .acknowledgeTerminal();
              context.go(AppRoutes.shell);
            },
          ),
          CheckoutRecoveryPhase.notFound => PurchaseStatusView(
            key: const Key('checkout-recovery-not-found'),
            title: l10n.checkoutRecoveryTitle,
            body: l10n.checkoutAttemptNotFoundBody,
            actionLabel: l10n.backToHomeAction,
            onAction: () {
              ref
                  .read(checkoutRecoveryControllerProvider.notifier)
                  .acknowledgeTerminal();
              context.go(AppRoutes.shell);
            },
          ),
          CheckoutRecoveryPhase.error => PurchaseStatusView(
            key: const Key('checkout-recovery-error'),
            title: l10n.checkoutRecoveryTitle,
            body: localizedApiError(l10n, state.error),
            actionLabel: l10n.retryAction,
            onAction: () => ref
                .read(checkoutRecoveryControllerProvider.notifier)
                .pollStatus(manual: true),
          ),
        },
      ),
    );
  }
}
