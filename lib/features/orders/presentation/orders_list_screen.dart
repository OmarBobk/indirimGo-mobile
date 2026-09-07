import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:indirimgo_mobile/core/localization/generated/app_localizations.dart';
import 'package:indirimgo_mobile/core/routing/app_router.dart';
import 'package:indirimgo_mobile/core/theme/app_theme.dart';
import 'package:indirimgo_mobile/core/widgets/api_error_message.dart';
import 'package:indirimgo_mobile/features/orders/domain/order_models.dart';
import 'package:indirimgo_mobile/features/orders/presentation/order_controllers.dart';
import 'package:indirimgo_mobile/features/orders/presentation/order_status_labels.dart';
import 'package:indirimgo_mobile/features/purchase/presentation/widgets/purchase_widgets.dart';
import 'package:intl/intl.dart';

class OrdersListScreen extends ConsumerWidget {
  const OrdersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(orderListControllerProvider);
    final controller = ref.read(orderListControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.ordersTitle),
        backgroundColor: BrandColors.yellow,
        foregroundColor: BrandColors.ink,
      ),
      body: SafeArea(child: _body(context, state, controller, l10n)),
    );
  }

  Widget _body(
    BuildContext context,
    OrderListState state,
    OrderListController controller,
    AppLocalizations l10n,
  ) {
    if (state.phase == OrderListPhase.loading && !state.hasContent) {
      return Semantics(
        liveRegion: true,
        label: l10n.ordersLoading,
        child: const Center(
          child: CircularProgressIndicator(key: Key('orders-loading')),
        ),
      );
    }
    if (state.phase == OrderListPhase.error && !state.hasContent) {
      return PurchaseStatusView(
        key: const Key('orders-error'),
        title: l10n.ordersUnavailableTitle,
        body: localizedApiError(l10n, state.error),
        icon: Icons.receipt_long_outlined,
        actionLabel: l10n.retryAction,
        onAction: controller.retry,
      );
    }
    if (state.phase == OrderListPhase.empty ||
        (state.phase == OrderListPhase.ready && !state.hasContent)) {
      return RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          key: const Key('orders-empty'),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.65,
              child: PurchaseStatusView(
                title: l10n.ordersEmptyTitle,
                body: l10n.ordersEmptyBody,
                icon: Icons.receipt_long_outlined,
              ),
            ),
          ],
        ),
      );
    }

    final hasRefreshError =
        state.phase == OrderListPhase.error && state.hasContent;
    final extraCount =
        (hasRefreshError ? 1 : 0) +
        ((state.canLoadMore || state.loadMoreError != null) ? 1 : 0);
    return RefreshIndicator(
      key: const Key('orders-refresh'),
      onRefresh: controller.refresh,
      child: ListView.builder(
        key: const Key('orders-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: state.orders.length + extraCount,
        itemBuilder: (context, index) {
          if (hasRefreshError && index == 0) {
            return Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  localizedApiError(l10n, state.error),
                  key: const Key('orders-refresh-error'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          }
          final orderIndex = index - (hasRefreshError ? 1 : 0);
          if (orderIndex < state.orders.length) {
            final order = state.orders[orderIndex];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _OrderCard(
                order: order,
                onTap: () =>
                    context.push(AppRoutes.orderReceipt(order.orderNumber)),
              ),
            );
          }
          if (state.loadMoreError != null) {
            return _LoadMoreError(
              message: localizedApiError(l10n, state.loadMoreError),
              onRetry: controller.retryLoadMore,
            );
          }
          return Semantics(
            liveRegion: state.phase == OrderListPhase.loadingMore,
            label: state.phase == OrderListPhase.loadingMore
                ? l10n.ordersLoadingMore
                : l10n.loadMoreOrders,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(
                child: state.phase == OrderListPhase.loadingMore
                    ? const CircularProgressIndicator(
                        key: Key('orders-load-more-loading'),
                      )
                    : OutlinedButton(
                        key: const Key('orders-load-more'),
                        onPressed: controller.loadMore,
                        child: Text(l10n.loadMoreOrders),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final OrderListItem order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final created = DateFormat.yMMMd(locale).add_jm().format(order.createdAt);
    final title = order.title?.trim().isNotEmpty == true
        ? order.title!.trim()
        : l10n.orderTitleFallback;
    final customerState = localizedCustomerOrderState(
      l10n,
      order.customerState,
    );
    final semanticLabel = l10n.orderCardSemantics(
      title,
      order.orderNumber,
      created,
      order.total.display.formatted,
      customerState,
      order.itemCount,
    );

    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('order-card-${order.orderNumber}'),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 96),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      order.orderNumber,
                      key: Key('order-number-${order.orderNumber}'),
                      textAlign: TextAlign.start,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(l10n.orderCreatedLabel(created)),
                  const SizedBox(height: AppSpacing.sm),
                  PurchaseMoneyText(money: order.total),
                  const SizedBox(height: AppSpacing.xs),
                  Text(l10n.customerStateLabel(customerState)),
                  if (order.itemCount > 0) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(l10n.orderItemCount(order.itemCount)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadMoreError extends StatelessWidget {
  const _LoadMoreError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              key: const Key('orders-load-more-retry'),
              onPressed: onRetry,
              child: Text(l10n.retryAction),
            ),
          ],
        ),
      ),
    );
  }
}
