import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:indirimgo_mobile/core/localization/generated/app_localizations.dart';
import 'package:indirimgo_mobile/core/routing/app_router.dart';
import 'package:indirimgo_mobile/core/theme/app_theme.dart';
import 'package:indirimgo_mobile/core/widgets/api_error_message.dart';
import 'package:indirimgo_mobile/core/widgets/customer_state_badge.dart';
import 'package:indirimgo_mobile/core/widgets/refresh_progress_slot.dart';
import 'package:indirimgo_mobile/features/orders/domain/order_models.dart';
import 'package:indirimgo_mobile/features/orders/presentation/order_controllers.dart';
import 'package:indirimgo_mobile/features/orders/presentation/order_status_labels.dart';
import 'package:indirimgo_mobile/features/purchase/presentation/widgets/purchase_widgets.dart';
import 'package:intl/intl.dart' hide TextDirection;

class OrdersListScreen extends ConsumerStatefulWidget {
  const OrdersListScreen({super.key});

  @override
  ConsumerState<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends ConsumerState<OrdersListScreen> {
  late final TextEditingController _searchController;
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(orderListControllerProvider).searchInput,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(orderListControllerProvider);
    final controller = ref.read(orderListControllerProvider.notifier);
    ref.listen<String>(
      orderListControllerProvider.select((value) => value.searchInput),
      (previous, next) {
        if (next != _searchController.text) {
          _searchController.text = next;
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.ordersTitle),
        backgroundColor: BrandColors.yellow,
        foregroundColor: BrandColors.ink,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: TextField(
                key: const Key('orders-search-field'),
                controller: _searchController,
                focusNode: _searchFocus,
                textInputAction: TextInputAction.search,
                maxLength: orderSearchQueryMaxLength,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                buildCounter:
                    (
                      context, {
                      required currentLength,
                      required isFocused,
                      required maxLength,
                    }) => null,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(orderSearchQueryMaxLength),
                ],
                decoration: InputDecoration(
                  labelText: l10n.searchOrdersLabel,
                  hintText: l10n.searchOrdersHint,
                  prefixIcon: const Icon(Icons.search),
                  errorText: state.searchTooShort
                      ? l10n.ordersSearchTooShort
                      : null,
                  suffixIcon: state.searchInput.isEmpty
                      ? null
                      : IconButton(
                          key: const Key('orders-clear-search'),
                          tooltip: l10n.clearSearch,
                          onPressed: () {
                            _searchController.clear();
                            controller.submitSearch('');
                          },
                          icon: const Icon(Icons.clear),
                        ),
                ),
                onChanged: controller.onSearchChanged,
                onSubmitted: controller.submitSearch,
              ),
            ),
            SizedBox(
              height: 56,
              child: ListView(
                key: const Key('orders-status-filters'),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                children: [
                  _FilterChip(
                    id: null,
                    label: l10n.filterAll,
                    selected: state.query.customerState == null,
                    onSelected: () => controller.setCustomerState(null),
                  ),
                  _FilterChip(
                    id: 'needs_attention',
                    label: l10n.filterNeedsAttention,
                    selected: state.query.customerState == 'needs_attention',
                    onSelected: () =>
                        controller.setCustomerState('needs_attention'),
                  ),
                  _FilterChip(
                    id: 'in_progress',
                    label: l10n.filterInProgress,
                    selected: state.query.customerState == 'in_progress',
                    onSelected: () =>
                        controller.setCustomerState('in_progress'),
                  ),
                  _FilterChip(
                    id: 'delivered',
                    label: l10n.filterDelivered,
                    selected: state.query.customerState == 'delivered',
                    onSelected: () => controller.setCustomerState('delivered'),
                  ),
                  _FilterChip(
                    id: 'refunded',
                    label: l10n.filterRefunded,
                    selected: state.query.customerState == 'refunded',
                    onSelected: () => controller.setCustomerState('refunded'),
                  ),
                ],
              ),
            ),
            RefreshProgressSlot(
              key: const Key('orders-progress-slot'),
              active:
                  state.phase == OrderListPhase.refreshing ||
                  state.phase == OrderListPhase.loadingMore,
            ),
            Expanded(child: _body(context, state, controller, l10n)),
          ],
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    OrderListState state,
    OrderListController controller,
    AppLocalizations l10n,
  ) {
    if (state.searchTooShort) {
      return PurchaseStatusView(
        key: const Key('orders-search-too-short'),
        title: l10n.ordersSearchTooShort,
        body: l10n.searchOrdersHint,
        icon: Icons.search,
      );
    }
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
          key: state.isNarrowed
              ? const Key('orders-no-matches')
              : const Key('orders-empty'),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.5,
              child: PurchaseStatusView(
                title: state.isNarrowed
                    ? l10n.ordersNoMatchesTitle
                    : l10n.ordersEmptyTitle,
                body: state.isNarrowed
                    ? l10n.ordersNoMatchesBody
                    : l10n.ordersEmptyBody,
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.id,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String? id;
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: AppSpacing.xs),
      child: FilterChip(
        key: Key('orders-filter-${id ?? 'all'}'),
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        visualDensity: VisualDensity.standard,
        materialTapTargetSize: MaterialTapTargetSize.padded,
        onSelected: (_) => onSelected(),
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
                      height: 1.35,
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
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: CustomerStateBadge(state: order.customerState),
                  ),
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
