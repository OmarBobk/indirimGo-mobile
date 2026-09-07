import 'package:indirimgo_mobile/features/orders/domain/order_models.dart';

import 'purchase_fixtures.dart';

Map<String, Object?> orderListItemJson({
  String orderNumber = 'ORD-2026-000001',
  String? title = '100 Coins',
  String paymentStatus = 'paid',
  String fulfillmentStatus = 'completed',
  String customerState = 'delivered',
  int itemCount = 1,
}) {
  return {
    'order_number': orderNumber,
    'created_at': '2026-08-01T13:00:00.000Z',
    'paid_at': paymentStatus == 'pending_payment'
        ? null
        : '2026-08-01T13:01:00.000Z',
    'currency': 'USD',
    'total': moneyJson(amount: '20.00', formatted: r'$20.00'),
    'payment_status': paymentStatus,
    'fulfillment_status': fulfillmentStatus,
    'customer_state': customerState,
    'title': title,
    'item_count': itemCount,
  };
}

Map<String, Object?> orderListPageJson({
  int page = 1,
  int lastPage = 1,
  List<Map<String, Object?>>? orders,
}) {
  final data = orders ?? [orderListItemJson()];
  return {
    'data': data,
    'meta': {
      'pagination': {
        'page': page,
        'per_page': ordersPerPage,
        'total': data.length,
        'last_page': lastPage,
      },
    },
  };
}

final sampleOrderPage = OrderListPage.fromJson(orderListPageJson());

Map<String, Object?> orderDetailJson({
  String orderNumber = 'ORD-2026-000001',
  String fulfillmentStatus = 'completed',
}) {
  return {
    'data': {
      'replayed': false,
      'order': purchaseReceiptJson(
        orderNumber: orderNumber,
        fulfillmentStatus: fulfillmentStatus,
        customerState: fulfillmentStatus == 'completed'
            ? 'delivered'
            : 'in_progress',
      ),
    },
  };
}
