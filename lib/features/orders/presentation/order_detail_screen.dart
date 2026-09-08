import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:indirimgo_mobile/core/localization/generated/app_localizations.dart';
import 'package:indirimgo_mobile/core/routing/app_router.dart';
import 'package:indirimgo_mobile/core/theme/app_theme.dart';
import 'package:indirimgo_mobile/core/widgets/api_error_message.dart';
import 'package:indirimgo_mobile/core/widgets/customer_state_badge.dart';
import 'package:indirimgo_mobile/features/orders/domain/order_models.dart';
import 'package:indirimgo_mobile/features/orders/presentation/order_controllers.dart';
import 'package:indirimgo_mobile/features/orders/presentation/order_status_labels.dart';
import 'package:indirimgo_mobile/features/purchase/domain/purchase_models.dart';
import 'package:indirimgo_mobile/features/purchase/presentation/widgets/purchase_widgets.dart';
import 'package:intl/intl.dart' hide TextDirection;

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderNumber});

  final String orderNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(orderDetailControllerProvider(orderNumber));
    final controller = ref.read(
      orderDetailControllerProvider(orderNumber).notifier,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.orderDetailTitle),
        backgroundColor: BrandColors.yellow,
        foregroundColor: BrandColors.ink,
        actions: [
          IconButton(
            key: const Key('order-detail-refresh'),
            tooltip: l10n.refreshOrderAction,
            onPressed:
                state.phase == OrderDetailPhase.loading ||
                    state.phase == OrderDetailPhase.refreshing
                ? null
                : controller.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: switch (state.phase) {
          OrderDetailPhase.idle ||
          OrderDetailPhase.loading when !state.hasContent => Semantics(
            liveRegion: true,
            label: l10n.loadingOrderDetail,
            child: const Center(
              child: CircularProgressIndicator(
                key: Key('order-detail-loading'),
              ),
            ),
          ),
          OrderDetailPhase.notFound => PurchaseStatusView(
            key: const Key('order-detail-not-found'),
            title: l10n.orderNotFoundTitle,
            body: l10n.orderNotFoundBody,
            actionLabel: l10n.backToHomeAction,
            onAction: () => context.go(AppRoutes.shell),
          ),
          OrderDetailPhase.error when !state.hasContent => PurchaseStatusView(
            key: const Key('order-detail-error'),
            title: l10n.orderDetailTitle,
            body: localizedApiError(l10n, state.error),
            actionLabel: l10n.retryAction,
            onAction: controller.refresh,
          ),
          _ when state.hasContent => _OrderDetailBody(
            state: state,
            onRefresh: controller.refresh,
            onDone: () async {
              await controller.acknowledgeAndLeave();
              if (context.mounted) {
                context.go(AppRoutes.orders);
              }
            },
            onHome: () async {
              await controller.acknowledgeAndLeave();
              if (context.mounted) {
                context.go(AppRoutes.shell);
              }
            },
          ),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }
}

class _OrderDetailBody extends StatelessWidget {
  const _OrderDetailBody({
    required this.state,
    required this.onRefresh,
    required this.onDone,
    required this.onHome,
  });

  final OrderDetailState state;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onDone;
  final Future<void> Function() onHome;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final order = state.result!.order;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateFormat = DateFormat.yMMMd(locale).add_jm();

    return RefreshIndicator(
      key: const Key('order-detail'),
      onRefresh: onRefresh,
      child: ListView(
        key: const Key('order-receipt'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (state.phase == OrderDetailPhase.refreshing || state.isPolling)
            Semantics(
              liveRegion: true,
              label: state.isPolling
                  ? l10n.orderStatusRefreshing
                  : l10n.refreshingOrders,
              child: const LinearProgressIndicator(
                key: Key('order-detail-refreshing'),
              ),
            ),
          if (state.phase == OrderDetailPhase.error) ...[
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              liveRegion: true,
              child: Text(
                localizedApiError(l10n, state.error),
                key: const Key('order-detail-refresh-error'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          if (state.pollingEnded) ...[
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              liveRegion: true,
              child: Text(
                l10n.orderPollingEnded,
                key: const Key('order-polling-ended'),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.orderNumberHeading,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          Directionality(
            textDirection: TextDirection.ltr,
            child: SelectableText(
              order.orderNumber,
              key: const Key('receipt-order-number'),
              textAlign: TextAlign.start,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.orderCreatedLabel(dateFormat.format(order.createdAt))),
          if (order.paidAt != null)
            Text(l10n.orderPaidLabel(dateFormat.format(order.paidAt!))),
          PurchaseSectionLabel(l10n.orderStatusSection),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: CustomerStateBadge(
              key: const Key('customer-state-badge'),
              state: order.customerState,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _StatusLine(
            label: l10n.paymentLabel,
            value: localizedPaymentStatus(l10n, order.paymentStatus),
            key: const Key('payment-status'),
          ),
          const SizedBox(height: AppSpacing.sm),
          _StatusLine(
            label: l10n.fulfillmentLabel,
            value: localizedFulfillmentStatus(l10n, order.fulfillmentStatus),
            key: const Key('fulfillment-status'),
          ),
          PurchaseSectionLabel(l10n.orderTotalsTitle),
          PurchaseMoneyText(
            key: const Key('receipt-total'),
            money: order.total,
            label: l10n.finalTotalLabel,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              order.currency,
              textAlign: TextAlign.start,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (_showSummary(order.fulfillmentSummary)) ...[
            PurchaseSectionLabel(l10n.fulfillmentSummaryTitle),
            _FulfillmentSummaryView(summary: order.fulfillmentSummary),
          ],
          PurchaseSectionLabel(l10n.receiptItemsTitle),
          ...order.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
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
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: FilledButton(
              key: const Key('receipt-done'),
              onPressed: onDone,
              child: Text(l10n.receiptDoneAction),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: OutlinedButton(
              key: const Key('receipt-home'),
              onPressed: onHome,
              child: Text(l10n.backToHomeAction),
            ),
          ),
        ],
      ),
    );
  }

  bool _showSummary(FulfillmentSummary summary) =>
      summary.total > 0 ||
      summary.queued > 0 ||
      summary.processing > 0 ||
      summary.completed > 0 ||
      summary.failed > 0 ||
      summary.cancelled > 0;
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: $value',
      style: Theme.of(
        context,
      ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _FulfillmentSummaryView extends StatelessWidget {
  const _FulfillmentSummaryView({required this.summary});

  final FulfillmentSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entries = [
      (l10n.fulfillmentSummaryTotal, summary.total),
      (l10n.fulfillmentStatusQueued, summary.queued),
      (l10n.fulfillmentStatusProcessing, summary.processing),
      (l10n.fulfillmentStatusCompleted, summary.completed),
      (l10n.fulfillmentStatusFailed, summary.failed),
      (l10n.fulfillmentStatusCancelled, summary.cancelled),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in entries)
          if (entry.$2 > 0)
            Text(l10n.fulfillmentSummaryCount(entry.$1, entry.$2)),
      ],
    );
  }
}
