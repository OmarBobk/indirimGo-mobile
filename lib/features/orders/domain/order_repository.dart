import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:indirimgo_mobile/features/orders/data/remote_order_repository.dart';
import 'package:indirimgo_mobile/features/orders/domain/order_models.dart';
import 'package:indirimgo_mobile/features/purchase/domain/purchase_models.dart';

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return ref.watch(remoteOrderRepositoryProvider);
});

abstract interface class OrderRepository {
  Future<OrderListPage> fetchOrders(
    OrderListQuery query, {
    CancelToken? cancelToken,
  });

  Future<CheckoutResult> fetchOrder(
    String orderNumber, {
    CancelToken? cancelToken,
  });
}
