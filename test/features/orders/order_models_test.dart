import 'package:flutter_test/flutter_test.dart';
import 'package:indirimgo_mobile/features/orders/domain/order_models.dart';
import 'package:indirimgo_mobile/features/purchase/domain/purchase_models.dart';

import '../../support/order_fixtures.dart';

void main() {
  test('parses order list pagination and preserves money strings', () {
    final page = OrderListPage.fromJson(
      orderListPageJson(page: 2, lastPage: 3),
    );
    expect(page.pagination.page, 2);
    expect(page.pagination.perPage, 20);
    expect(page.pagination.hasNextPage, isTrue);
    expect(page.orders.single.total.amount, '20.00');
    expect(page.orders.single.paidAt, isNotNull);
  });

  test('parses required nullable list fields', () {
    final item = OrderListItem.fromJson(
      orderListItemJson(
        title: null,
        paymentStatus: 'pending_payment',
        fulfillmentStatus: 'pending',
        customerState: 'in_progress',
      ),
    );
    expect(item.title, isNull);
    expect(item.paidAt, isNull);
    expect(item.itemCount, 1);
  });

  test('rejects missing required fields and invalid money', () {
    final missing = orderListItemJson()..remove('customer_state');
    expect(() => OrderListItem.fromJson(missing), throwsFormatException);

    final invalidMoney = orderListItemJson();
    invalidMoney['total'] = {
      'amount': 20.0,
      'currency': 'USD',
      'display': {'currency': 'USD', 'formatted': r'$20.00'},
    };
    expect(() => OrderListItem.fromJson(invalidMoney), throwsFormatException);
  });

  test('accepts every documented order status', () {
    for (final payment in supportedPaymentStatuses) {
      expect(
        OrderListItem.fromJson(
          orderListItemJson(paymentStatus: payment),
        ).paymentStatus,
        payment,
      );
    }
    for (final fulfillment in supportedFulfillmentStatuses) {
      expect(
        OrderListItem.fromJson(
          orderListItemJson(fulfillmentStatus: fulfillment),
        ).fulfillmentStatus,
        fulfillment,
      );
    }
    for (final customerState in supportedCustomerOrderStates) {
      expect(
        OrderListItem.fromJson(
          orderListItemJson(customerState: customerState),
        ).customerState,
        customerState,
      );
    }
  });

  test('rejects unknown statuses instead of exposing raw keys', () {
    expect(
      () => OrderListItem.fromJson(
        orderListItemJson(paymentStatus: 'secret_internal'),
      ),
      throwsFormatException,
    );
  });

  test('preserves CheckoutSuccess and parses additive detail fields', () {
    final result = CheckoutResult.fromJson(
      orderDetailJson(fulfillmentStatus: 'processing'),
    );
    expect(result.replayed, isFalse);
    expect(result.order.createdAt, DateTime.utc(2026, 8, 1, 13));
    expect(result.order.fulfillmentStatus, 'processing');
    expect(result.order.customerState, 'in_progress');
    expect(result.order.fulfillmentSummary.total, 2);
    expect(result.order.total.amount, '20.00');
  });

  test('requires every additive receipt field', () {
    final json = orderDetailJson();
    final data = json['data']! as Map<String, Object?>;
    final order = data['order']! as Map<String, Object?>;
    order.remove('fulfillment_summary');
    expect(() => CheckoutResult.fromJson(json), throwsFormatException);
  });
}
