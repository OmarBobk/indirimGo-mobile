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

class OrderReceiptScreen extends ConsumerWidget {
  const OrderReceiptScreen({super.key, required this.orderNumber});

  final String orderNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(orderReceiptControllerProvider(orderNumber));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.receiptTitle),
        backgroundColor: BrandColors.yellow,
        foregroundColor: BrandColors.ink,
      ),
      body: SafeArea(
        child: switch (state.phase) {
          OrderReceiptPhase.idle || OrderReceiptPhase.loading => Semantics(
            label: l10n.loadingReceipt,
            child: const Center(
              child: CircularProgressIndicator(key: Key('receipt-loading')),
            ),
          ),
          OrderReceiptPhase.notFound => PurchaseStatusView(
            key: const Key('receipt-not-found'),
            title: l10n.orderNotFoundTitle,
            body: l10n.orderNotFoundBody,
            actionLabel: l10n.backToHomeAction,
            onAction: () => context.go(AppRoutes.shell),
          ),
          OrderReceiptPhase.error => PurchaseStatusView(
            key: const Key('receipt-error'),
            title: l10n.receiptTitle,
            body: localizedApiError(l10n, state.error),
            actionLabel: l10n.retryAction,
            onAction: () => ref
                .read(orderReceiptControllerProvider(orderNumber).notifier)
                .load(),
          ),
          OrderReceiptPhase.ready => _ReceiptBody(result: state.result!),
        },
      ),
    );
  }
}

class _ReceiptBody extends ConsumerWidget {
  const _ReceiptBody({required this.result});

  final CheckoutResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final order = result.order;
    final theme = Theme.of(context);

    return ListView(
      key: const Key('order-receipt'),
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Icon(Icons.check_circle, color: BrandColors.success, size: 48),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.purchaseSuccessTitle, style: theme.textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          key: const Key('receipt-order-number'),
          l10n.orderNumberLabel(order.orderNumber),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(l10n.paymentStatusLabel(order.paymentStatus)),
        PurchaseSectionLabel(l10n.orderTotalsTitle),
        PurchaseMoneyText(
          key: const Key('receipt-total'),
          money: order.total,
          label: l10n.finalTotalLabel,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        PurchaseSectionLabel(l10n.receiptItemsTitle),
        ...order.items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: theme.textTheme.titleMedium),
                Text(
                  item.amountMode == ProductAmountMode.fixed
                      ? l10n.quantityValue(item.quantity)
                      : l10n.requestedAmountValue(item.requestedAmount ?? 0),
                ),
                PurchaseMoneyText(
                  money: item.lineTotal,
                  label: l10n.lineTotalLabel,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            key: const Key('receipt-done'),
            onPressed: () async {
              await ref
                  .read(
                    orderReceiptControllerProvider(order.orderNumber).notifier,
                  )
                  .acknowledgeAndLeave();
              if (context.mounted) {
                context.go(AppRoutes.shell);
              }
            },
            child: Text(l10n.backToHomeAction),
          ),
        ),
      ],
    );
  }
}
