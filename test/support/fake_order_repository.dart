import 'package:dio/dio.dart';
import 'package:indirimgo_mobile/core/errors/api_exception.dart';
import 'package:indirimgo_mobile/features/orders/domain/order_models.dart';
import 'package:indirimgo_mobile/features/orders/domain/order_repository.dart';
import 'package:indirimgo_mobile/features/purchase/domain/purchase_models.dart';

import 'order_fixtures.dart';

class FakeOrderRepository implements OrderRepository {
  OrderListPage firstPage = sampleOrderPage;
  final Map<int, OrderListPage> pages = {};
  CheckoutResult detail = CheckoutResult.fromJson(orderDetailJson());
  Object? listError;
  Object? detailError;
  Future<OrderListPage> Function(OrderListQuery query, CancelToken? token)?
  listHandler;
  Future<CheckoutResult> Function(String orderNumber, CancelToken? token)?
  detailHandler;

  int listCalls = 0;
  int detailCalls = 0;
  final List<OrderListQuery> queries = [];
  final List<String> orderNumbers = [];
  final List<CancelToken?> detailTokens = [];

  @override
  Future<OrderListPage> fetchOrders(
    OrderListQuery query, {
    CancelToken? cancelToken,
  }) async {
    listCalls += 1;
    queries.add(query);
    if (listHandler != null) {
      return listHandler!(query, cancelToken);
    }
    _throwIfCancelled(cancelToken);
    if (listError case final error?) {
      throw error;
    }
    return pages[query.page] ?? firstPage;
  }

  @override
  Future<CheckoutResult> fetchOrder(
    String orderNumber, {
    CancelToken? cancelToken,
  }) async {
    detailCalls += 1;
    orderNumbers.add(orderNumber);
    detailTokens.add(cancelToken);
    if (detailHandler != null) {
      return detailHandler!(orderNumber, cancelToken);
    }
    _throwIfCancelled(cancelToken);
    if (detailError case final error?) {
      throw error;
    }
    return detail;
  }

  void _throwIfCancelled(CancelToken? token) {
    if (token?.isCancelled ?? false) {
      throw const ApiException(kind: ApiErrorKind.cancelled);
    }
  }
}
