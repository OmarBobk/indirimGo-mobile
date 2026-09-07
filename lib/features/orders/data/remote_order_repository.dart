import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:indirimgo_mobile/core/network/api_client.dart';
import 'package:indirimgo_mobile/features/orders/domain/order_models.dart';
import 'package:indirimgo_mobile/features/orders/domain/order_repository.dart';
import 'package:indirimgo_mobile/features/purchase/domain/purchase_models.dart';

final remoteOrderRepositoryProvider = Provider<OrderRepository>((ref) {
  return RemoteOrderRepository(apiClient: ref.watch(apiClientProvider));
});

class RemoteOrderRepository implements OrderRepository {
  const RemoteOrderRepository({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<OrderListPage> fetchOrders(
    OrderListQuery query, {
    CancelToken? cancelToken,
  }) async {
    final response = await apiClient.get(
      'orders',
      queryParameters: query.toQueryParameters(),
      cancelToken: cancelToken,
    );
    _requireOk(response, 'order-list');
    return OrderListPage.fromJson(response.data);
  }

  @override
  Future<CheckoutResult> fetchOrder(
    String orderNumber, {
    CancelToken? cancelToken,
  }) async {
    final response = await apiClient.get(
      'orders/$orderNumber',
      cancelToken: cancelToken,
    );
    _requireOk(response, 'order-show');
    return CheckoutResult.fromJson(response.data);
  }
}

void _requireOk(ApiResponse response, String operation) {
  if (response.statusCode != 200) {
    throw FormatException(
      'The $operation response used an unsupported status.',
    );
  }
}
