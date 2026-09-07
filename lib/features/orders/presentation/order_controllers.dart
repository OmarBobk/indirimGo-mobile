import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:indirimgo_mobile/core/errors/api_exception.dart';
import 'package:indirimgo_mobile/core/storage/pending_checkout_store.dart';
import 'package:indirimgo_mobile/features/auth/presentation/auth_controller.dart';
import 'package:indirimgo_mobile/features/catalog/domain/catalog_models.dart';
import 'package:indirimgo_mobile/features/orders/domain/order_models.dart';
import 'package:indirimgo_mobile/features/orders/domain/order_repository.dart';
import 'package:indirimgo_mobile/features/purchase/domain/purchase_models.dart';
import 'package:indirimgo_mobile/features/purchase/presentation/purchase_controllers.dart';

final orderCustomerIdProvider = Provider<int?>((ref) {
  final auth = ref.watch(authControllerProvider);
  if (auth.phase != AuthPhase.authenticated) {
    return null;
  }
  return auth.user?.id;
});

enum OrderListPhase {
  idle,
  loading,
  refreshing,
  loadingMore,
  ready,
  empty,
  error,
}

class OrderListState {
  const OrderListState({
    required this.phase,
    this.orders = const [],
    this.pagination,
    this.error,
    this.loadMoreError,
    this.customerId,
  });

  const OrderListState.initial() : this(phase: OrderListPhase.idle);

  final OrderListPhase phase;
  final List<OrderListItem> orders;
  final OffsetPagination? pagination;
  final ApiException? error;
  final ApiException? loadMoreError;
  final int? customerId;

  bool get hasContent => orders.isNotEmpty;

  bool get canLoadMore =>
      pagination?.hasNextPage == true &&
      phase != OrderListPhase.loading &&
      phase != OrderListPhase.refreshing &&
      phase != OrderListPhase.loadingMore;
}

final orderListControllerProvider =
    NotifierProvider<OrderListController, OrderListState>(
      OrderListController.new,
    );

class OrderListController extends Notifier<OrderListState> {
  OrderRepository get _repository => ref.read(orderRepositoryProvider);

  int _epoch = 0;
  CancelToken? _cancelToken;
  bool _disposed = false;
  bool _loadMoreInFlight = false;

  @override
  OrderListState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _cancelInFlight('dispose');
    });
    ref.listen<int?>(orderCustomerIdProvider, (previous, next) {
      if (previous == next) {
        return;
      }
      _cancelInFlight('customer-switch');
      if (next == null) {
        state = const OrderListState.initial();
        return;
      }
      state = OrderListState(phase: OrderListPhase.loading, customerId: next);
      unawaited(_fetchFirstPage(preserveOnError: false));
    });

    final customerId = ref.read(orderCustomerIdProvider);
    if (customerId == null) {
      return const OrderListState.initial();
    }
    scheduleMicrotask(() {
      if (!_disposed) {
        unawaited(_fetchFirstPage(preserveOnError: false));
      }
    });
    return OrderListState(
      phase: OrderListPhase.loading,
      customerId: customerId,
    );
  }

  Future<void> refresh() async {
    if (state.phase == OrderListPhase.loading ||
        state.phase == OrderListPhase.refreshing) {
      return;
    }
    state = OrderListState(
      phase: state.hasContent
          ? OrderListPhase.refreshing
          : OrderListPhase.loading,
      orders: state.orders,
      pagination: state.pagination,
      customerId: ref.read(orderCustomerIdProvider),
    );
    await _fetchFirstPage(preserveOnError: true);
  }

  Future<void> retry() => _fetchFirstPage(preserveOnError: false);

  Future<void> loadMore() async {
    final pagination = state.pagination;
    if (!state.canLoadMore ||
        pagination == null ||
        _loadMoreInFlight ||
        ref.read(orderCustomerIdProvider) == null) {
      return;
    }
    _loadMoreInFlight = true;
    final customerId = ref.read(orderCustomerIdProvider)!;
    final operation = ++_epoch;
    _cancelToken?.cancel('superseded');
    final token = CancelToken();
    _cancelToken = token;
    state = OrderListState(
      phase: OrderListPhase.loadingMore,
      orders: state.orders,
      pagination: pagination,
      customerId: customerId,
    );
    try {
      final page = await _repository.fetchOrders(
        OrderListQuery(page: pagination.page + 1),
        cancelToken: token,
      );
      if (!_isCurrent(operation, customerId)) {
        return;
      }
      final known = {for (final order in state.orders) order.orderNumber};
      final combined = [
        ...state.orders,
        for (final order in page.orders)
          if (known.add(order.orderNumber)) order,
      ];
      state = OrderListState(
        phase: combined.isEmpty ? OrderListPhase.empty : OrderListPhase.ready,
        orders: combined,
        pagination: page.pagination,
        customerId: customerId,
      );
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.cancelled) {
        return;
      }
      if (await _applyAuthoritativeRejection(error)) {
        if (ref.read(orderCustomerIdProvider) == null) {
          state = const OrderListState.initial();
        }
        return;
      }
      if (!_isCurrent(operation, customerId)) {
        return;
      }
      state = OrderListState(
        phase: OrderListPhase.ready,
        orders: state.orders,
        pagination: pagination,
        loadMoreError: error,
        customerId: customerId,
      );
    } on Object {
      if (_isCurrent(operation, customerId)) {
        state = OrderListState(
          phase: OrderListPhase.ready,
          orders: state.orders,
          pagination: pagination,
          loadMoreError: const ApiException(kind: ApiErrorKind.unknown),
          customerId: customerId,
        );
      }
    } finally {
      _loadMoreInFlight = false;
      if (identical(_cancelToken, token)) {
        _cancelToken = null;
      }
    }
  }

  Future<void> retryLoadMore() => loadMore();

  Future<void> _fetchFirstPage({required bool preserveOnError}) async {
    final customerId = ref.read(orderCustomerIdProvider);
    if (customerId == null) {
      state = const OrderListState.initial();
      return;
    }
    final operation = ++_epoch;
    _cancelToken?.cancel('superseded');
    final token = CancelToken();
    _cancelToken = token;
    final preservedOrders = preserveOnError
        ? state.orders
        : const <OrderListItem>[];
    final preservedPagination = preserveOnError ? state.pagination : null;
    if (!preserveOnError) {
      state = OrderListState(
        phase: OrderListPhase.loading,
        customerId: customerId,
      );
    }
    try {
      final page = await _repository.fetchOrders(
        const OrderListQuery(),
        cancelToken: token,
      );
      if (!_isCurrent(operation, customerId)) {
        return;
      }
      state = OrderListState(
        phase: page.orders.isEmpty
            ? OrderListPhase.empty
            : OrderListPhase.ready,
        orders: page.orders,
        pagination: page.pagination,
        customerId: customerId,
      );
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.cancelled) {
        return;
      }
      if (await _applyAuthoritativeRejection(error)) {
        if (ref.read(orderCustomerIdProvider) == null) {
          state = const OrderListState.initial();
        }
        return;
      }
      if (!_isCurrent(operation, customerId)) {
        return;
      }
      state = OrderListState(
        phase: OrderListPhase.error,
        orders: preservedOrders,
        pagination: preservedPagination,
        error: error,
        customerId: customerId,
      );
    } on Object {
      if (_isCurrent(operation, customerId)) {
        state = OrderListState(
          phase: OrderListPhase.error,
          orders: preservedOrders,
          pagination: preservedPagination,
          error: const ApiException(kind: ApiErrorKind.unknown),
          customerId: customerId,
        );
      }
    } finally {
      if (identical(_cancelToken, token)) {
        _cancelToken = null;
      }
    }
  }

  bool _isCurrent(int operation, int customerId) =>
      !_disposed &&
      operation == _epoch &&
      ref.read(orderCustomerIdProvider) == customerId;

  Future<bool> _applyAuthoritativeRejection(ApiException error) {
    return ref
        .read(authControllerProvider.notifier)
        .applyAuthoritativeRejection(error);
  }

  void _cancelInFlight(String reason) {
    _epoch += 1;
    _cancelToken?.cancel(reason);
    _cancelToken = null;
    _loadMoreInFlight = false;
  }
}

class OrderPollingPolicy {
  const OrderPollingPolicy({
    this.interval = const Duration(seconds: 5),
    this.maximumPolls = 8,
  });

  final Duration interval;
  final int maximumPolls;
}

final orderPollingPolicyProvider = Provider<OrderPollingPolicy>((ref) {
  return const OrderPollingPolicy();
});

enum OrderDetailPhase { idle, loading, refreshing, ready, notFound, error }

class OrderDetailState {
  const OrderDetailState({
    required this.phase,
    this.result,
    this.error,
    this.customerId,
    this.isPolling = false,
    this.pollingEnded = false,
  });

  final OrderDetailPhase phase;
  final CheckoutResult? result;
  final ApiException? error;
  final int? customerId;
  final bool isPolling;
  final bool pollingEnded;

  bool get hasContent => result != null;
}

final orderDetailControllerProvider = NotifierProvider.autoDispose
    .family<OrderDetailController, OrderDetailState, String>(
      OrderDetailController.new,
    );

class OrderDetailController extends Notifier<OrderDetailState> {
  OrderDetailController(this.orderNumber);

  final String orderNumber;

  OrderRepository get _repository => ref.read(orderRepositoryProvider);
  OrderPollingPolicy get _pollingPolicy => ref.read(orderPollingPolicyProvider);

  int _epoch = 0;
  int _pollsRemaining = 0;
  CancelToken? _cancelToken;
  Timer? _pollTimer;
  bool _disposed = false;
  bool _foreground = true;

  @override
  OrderDetailState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _stopAndCancel('dispose');
    });
    ref.listen<int?>(orderCustomerIdProvider, (previous, next) {
      if (previous == next) {
        return;
      }
      _stopAndCancel('customer-switch');
      if (next == null) {
        state = const OrderDetailState(phase: OrderDetailPhase.idle);
      } else {
        unawaited(load());
      }
    });
    scheduleMicrotask(() {
      if (!_disposed) {
        unawaited(load());
      }
    });
    return OrderDetailState(
      phase: OrderDetailPhase.loading,
      customerId: ref.read(orderCustomerIdProvider),
    );
  }

  Future<void> load({bool preserve = false}) async {
    _pollsRemaining = _pollingPolicy.maximumPolls;
    await _fetch(preserve: preserve, isPoll: false);
  }

  Future<void> refresh() => load(preserve: state.hasContent);

  void setForeground(bool foreground) {
    if (_foreground == foreground || _disposed) {
      return;
    }
    _foreground = foreground;
    if (!foreground) {
      _stopAndCancel('background');
      if (state.hasContent) {
        state = OrderDetailState(
          phase: OrderDetailPhase.ready,
          result: state.result,
          error: state.error,
          customerId: state.customerId,
          pollingEnded: state.pollingEnded,
        );
      }
      return;
    }
    final result = state.result;
    if (result == null) {
      unawaited(load());
    } else {
      _schedulePollIfNeeded(result);
    }
  }

  Future<void> _fetch({required bool preserve, required bool isPoll}) async {
    final customerId = ref.read(orderCustomerIdProvider);
    if (customerId == null) {
      state = const OrderDetailState(phase: OrderDetailPhase.idle);
      return;
    }
    if (!orderNumberPattern.hasMatch(orderNumber)) {
      state = OrderDetailState(
        phase: OrderDetailPhase.notFound,
        error: const ApiException(
          kind: ApiErrorKind.notFound,
          code: 'order_not_found',
          statusCode: 404,
        ),
        customerId: customerId,
      );
      return;
    }
    final operation = ++_epoch;
    _cancelToken?.cancel('superseded');
    final token = CancelToken();
    _cancelToken = token;
    final previous = preserve ? state.result : null;
    state = OrderDetailState(
      phase: previous == null
          ? OrderDetailPhase.loading
          : OrderDetailPhase.refreshing,
      result: previous,
      customerId: customerId,
      isPolling: isPoll,
      pollingEnded: state.pollingEnded,
    );
    try {
      final result = await _repository.fetchOrder(
        orderNumber,
        cancelToken: token,
      );
      if (!_isCurrent(operation, customerId)) {
        return;
      }
      state = OrderDetailState(
        phase: OrderDetailPhase.ready,
        result: result,
        customerId: customerId,
      );
      _schedulePollIfNeeded(result);
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.cancelled) {
        return;
      }
      if (await ref
          .read(authControllerProvider.notifier)
          .applyAuthoritativeRejection(error)) {
        if (ref.read(orderCustomerIdProvider) == null) {
          state = const OrderDetailState(phase: OrderDetailPhase.idle);
        }
        return;
      }
      if (!_isCurrent(operation, customerId)) {
        return;
      }
      final notFound =
          error.kind == ApiErrorKind.notFound ||
          error.code == 'order_not_found';
      state = OrderDetailState(
        phase: notFound ? OrderDetailPhase.notFound : OrderDetailPhase.error,
        result: notFound ? null : previous,
        error: error,
        customerId: customerId,
        pollingEnded: isPoll && _pollsRemaining == 0,
      );
      if (!notFound && isPoll && previous != null) {
        _schedulePollIfNeeded(previous);
      }
    } on Object {
      if (_isCurrent(operation, customerId)) {
        state = OrderDetailState(
          phase: OrderDetailPhase.error,
          result: previous,
          error: const ApiException(kind: ApiErrorKind.unknown),
          customerId: customerId,
          pollingEnded: isPoll && _pollsRemaining == 0,
        );
        if (isPoll && previous != null) {
          _schedulePollIfNeeded(previous);
        }
      }
    } finally {
      if (identical(_cancelToken, token)) {
        _cancelToken = null;
      }
    }
  }

  void _schedulePollIfNeeded(CheckoutResult result) {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (!_foreground ||
        _disposed ||
        !isUnfinishedFulfillmentStatus(result.order.fulfillmentStatus)) {
      return;
    }
    if (_pollsRemaining <= 0) {
      state = OrderDetailState(
        phase: state.hasContent ? OrderDetailPhase.ready : state.phase,
        result: state.result,
        error: state.error,
        customerId: state.customerId,
        pollingEnded: true,
      );
      return;
    }
    state = OrderDetailState(
      phase: state.phase,
      result: state.result,
      error: state.error,
      customerId: state.customerId,
      isPolling: true,
    );
    _pollTimer = Timer(_pollingPolicy.interval, () {
      _pollTimer = null;
      if (_disposed || !_foreground || _cancelToken != null) {
        return;
      }
      _pollsRemaining -= 1;
      unawaited(_fetch(preserve: true, isPoll: true));
    });
  }

  Future<void> acknowledgeAndLeave() async {
    final customerId = ref.read(orderCustomerIdProvider);
    if (customerId == null) {
      return;
    }
    final record = await ref
        .read(pendingCheckoutStoreProvider)
        .readForCustomer(customerId);
    if (record?.completedOrderNumber == orderNumber) {
      await ref
          .read(checkoutRecoveryControllerProvider.notifier)
          .acknowledgeCompletedReceipt();
    }
  }

  bool _isCurrent(int operation, int customerId) =>
      !_disposed &&
      operation == _epoch &&
      ref.read(orderCustomerIdProvider) == customerId;

  void _stopAndCancel(String reason) {
    _epoch += 1;
    _pollTimer?.cancel();
    _pollTimer = null;
    _cancelToken?.cancel(reason);
    _cancelToken = null;
  }
}
