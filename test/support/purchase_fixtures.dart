import 'package:indirimgo_mobile/features/purchase/domain/purchase_models.dart';

import 'catalog_fixtures.dart';

export 'catalog_fixtures.dart';

Map<String, Object?> checkoutQuoteJson({
  String fingerprint = 'quote-fingerprint-example-123456',
  String expiresAt = '2099-01-01T00:00:00.000Z',
  int quantity = 2,
  int? requestedAmount,
  String amountMode = 'fixed',
  String totalAmount = '20.00',
  String available = '100.00',
  bool canAfford = true,
  bool pricesVisible = true,
  List<Map<String, Object?>>? requirementsSchema,
}) {
  return {
    'data': {
      'quote_fingerprint': fingerprint,
      'expires_at': expiresAt,
      'item': {
        'product_id': 901,
        'package_id': 42,
        'name': '100 Coins',
        'amount_mode': amountMode,
        'quantity': quantity,
        'requested_amount': requestedAmount,
        'unit_price': moneyJson(amount: '10.00', formatted: r'$10.00'),
        'line_total': moneyJson(
          amount: totalAmount,
          formatted: '\$$totalAmount',
        ),
        'requirements_schema': requirementsSchema ?? [requirementFieldJson()],
      },
      'subtotal': moneyJson(amount: totalAmount, formatted: '\$$totalAmount'),
      'fee': moneyJson(amount: '0.00', formatted: r'$0.00'),
      'total': moneyJson(amount: totalAmount, formatted: '\$$totalAmount'),
      'wallet': {
        'available_to_spend': moneyJson(
          amount: available,
          formatted: '\$$available',
        ),
        'can_afford': canAfford,
      },
      'meta': {'prices_visible': pricesVisible},
    },
  };
}

Map<String, Object?> walletSummaryJson({
  String amount = '42.50',
  bool pricesVisible = true,
}) {
  return {
    'data': {
      'available_to_spend': moneyJson(amount: amount, formatted: '\$$amount'),
    },
    'meta': {'prices_visible': pricesVisible},
  };
}

Map<String, Object?> purchaseReceiptJson({
  String orderNumber = 'ORD-2026-000001',
  String totalAmount = '20.00',
}) {
  return {
    'order_number': orderNumber,
    'status': 'paid',
    'payment_status': 'paid',
    'currency': 'USD',
    'total': moneyJson(amount: totalAmount, formatted: '\$$totalAmount'),
    'paid_at': '2026-08-01T13:01:00.000Z',
    'items': [
      {
        'product_id': 901,
        'package_id': 42,
        'name': '100 Coins',
        'amount_mode': 'fixed',
        'quantity': 2,
        'requested_amount': null,
        'line_total': moneyJson(
          amount: totalAmount,
          formatted: '\$$totalAmount',
        ),
      },
    ],
  };
}

Map<String, Object?> checkoutSuccessJson({
  bool replayed = false,
  String orderNumber = 'ORD-2026-000001',
}) {
  return {
    'data': {
      'replayed': replayed,
      'order': purchaseReceiptJson(orderNumber: orderNumber),
    },
  };
}

Map<String, Object?> checkoutStatusCompletedJson({
  String orderNumber = 'ORD-2026-000001',
}) {
  return {
    'data': {
      'state': 'completed',
      'replayed': true,
      'order': purchaseReceiptJson(orderNumber: orderNumber),
    },
  };
}

Map<String, Object?> checkoutStatusProcessingJson({int retryAfter = 2}) {
  return {
    'data': {'state': 'processing', 'retry_after_seconds': retryAfter},
  };
}

Map<String, Object?> checkoutStatusFailedJson() {
  return {
    'data': {'state': 'failed', 'code': 'checkout_failed'},
  };
}

final sampleCheckoutQuote = CheckoutQuote.fromSuccessJson(checkoutQuoteJson());
final sampleCheckoutResult = CheckoutResult.fromJson(checkoutSuccessJson());
