/// Manual OpenAPI 1.4.0 models for customer-owned order history.
///
/// Money remains server-provided decimal strings through the shared [Money]
/// model. These models never persist or log order response bodies.
library;

import 'package:indirimgo_mobile/features/catalog/domain/catalog_models.dart';

const int ordersPerPage = 20;

const int orderSearchQueryMinLength = 2;

const int orderSearchQueryMaxLength = 100;

const supportedOrderCustomerStateFilters = <String>{
  'needs_attention',
  'in_progress',
  'delivered',
  'refunded',
};

const supportedPaymentStatuses = <String>{
  'paid',
  'pending_payment',
  'processing',
  'fulfilled',
  'failed',
  'refunded',
  'cancelled',
};

const supportedFulfillmentStatuses = <String>{
  'pending',
  'queued',
  'processing',
  'completed',
  'failed',
  'cancelled',
};

const supportedCustomerOrderStates = <String>{
  'needs_attention',
  'in_progress',
  'delivered',
  'refunded',
  'other',
};

bool isUnfinishedFulfillmentStatus(String status) =>
    status == 'pending' || status == 'queued' || status == 'processing';

class OrderListQuery {
  const OrderListQuery({
    this.page = 1,
    this.perPage = ordersPerPage,
    this.q,
    this.customerState,
  });

  final int page;
  final int perPage;
  final String? q;
  final String? customerState;

  bool get hasSearch => q != null && q!.isNotEmpty;

  bool get hasFilter => customerState != null;

  Map<String, Object?> toQueryParameters() => {
    'page': page,
    'per_page': perPage,
    if (hasSearch) 'q': q,
    if (hasFilter) 'customer_state': customerState,
  };

  OrderListQuery copyWith({
    int? page,
    int? perPage,
    String? q,
    bool clearQ = false,
    String? customerState,
    bool clearCustomerState = false,
  }) {
    return OrderListQuery(
      page: page ?? this.page,
      perPage: perPage ?? this.perPage,
      q: clearQ ? null : q ?? this.q,
      customerState: clearCustomerState
          ? null
          : customerState ?? this.customerState,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is OrderListQuery &&
        other.page == page &&
        other.perPage == perPage &&
        other.q == q &&
        other.customerState == customerState;
  }

  @override
  int get hashCode => Object.hash(page, perPage, q, customerState);
}

class OrderListItem {
  const OrderListItem({
    required this.orderNumber,
    required this.createdAt,
    required this.paidAt,
    required this.currency,
    required this.total,
    required this.paymentStatus,
    required this.fulfillmentStatus,
    required this.customerState,
    required this.title,
    required this.itemCount,
  });

  factory OrderListItem.fromJson(Map<String, Object?> json) {
    _requireKeys(json, const {
      'order_number',
      'created_at',
      'paid_at',
      'currency',
      'total',
      'payment_status',
      'fulfillment_status',
      'customer_state',
      'title',
      'item_count',
    });
    final orderNumber = _requiredString(json, 'order_number');
    if (!orderNumberPattern.hasMatch(orderNumber)) {
      throw const FormatException('order_number format is invalid.');
    }
    final currency = _requiredString(json, 'currency');
    if (currency != 'USD') {
      throw const FormatException('Order currency must be USD.');
    }
    final itemCount = _requiredInt(json, 'item_count');
    if (itemCount < 0) {
      throw const FormatException('item_count must be non-negative.');
    }
    return OrderListItem(
      orderNumber: orderNumber,
      createdAt: _requiredDateTime(json, 'created_at'),
      paidAt: _nullableDateTime(json, 'paid_at'),
      currency: currency,
      total: Money.fromJson(_requiredMap(json, 'total')),
      paymentStatus: parsePaymentStatus(json['payment_status']),
      fulfillmentStatus: parseFulfillmentStatus(json['fulfillment_status']),
      customerState: parseCustomerOrderState(json['customer_state']),
      title: _nullableString(json, 'title'),
      itemCount: itemCount,
    );
  }

  final String orderNumber;
  final DateTime createdAt;
  final DateTime? paidAt;
  final String currency;
  final Money total;
  final String paymentStatus;
  final String fulfillmentStatus;
  final String customerState;
  final String? title;
  final int itemCount;
}

class OrderListPage {
  const OrderListPage({required this.orders, required this.pagination});

  factory OrderListPage.fromJson(Map<String, Object?> json) {
    _requireKeys(json, const {'data', 'meta'});
    final rawOrders = json['data'];
    if (rawOrders is! List) {
      throw const FormatException('data must be an array.');
    }
    final meta = _requiredMap(json, 'meta');
    _requireKeys(meta, const {'pagination'});
    return OrderListPage(
      orders: [
        for (final item in rawOrders)
          OrderListItem.fromJson(_asObjectMap(item, 'order list item')),
      ],
      pagination: OffsetPagination.fromJson(_requiredMap(meta, 'pagination')),
    );
  }

  final List<OrderListItem> orders;
  final OffsetPagination pagination;
}

class FulfillmentSummary {
  const FulfillmentSummary({
    required this.total,
    required this.queued,
    required this.processing,
    required this.completed,
    required this.failed,
    required this.cancelled,
  });

  factory FulfillmentSummary.fromJson(Map<String, Object?> json) {
    _requireKeys(json, const {
      'total',
      'queued',
      'processing',
      'completed',
      'failed',
      'cancelled',
    });
    final values = <String, int>{
      for (final key in const [
        'total',
        'queued',
        'processing',
        'completed',
        'failed',
        'cancelled',
      ])
        key: _requiredInt(json, key),
    };
    if (values.values.any((value) => value < 0)) {
      throw const FormatException(
        'Fulfillment summary values must be non-negative.',
      );
    }
    return FulfillmentSummary(
      total: values['total']!,
      queued: values['queued']!,
      processing: values['processing']!,
      completed: values['completed']!,
      failed: values['failed']!,
      cancelled: values['cancelled']!,
    );
  }

  final int total;
  final int queued;
  final int processing;
  final int completed;
  final int failed;
  final int cancelled;
}

final orderNumberPattern = RegExp(r'^ORD-[A-Za-z0-9\-]+$');

String parsePaymentStatus(Object? value) =>
    _parseAllowlistedStatus(value, supportedPaymentStatuses, 'payment_status');

String parseFulfillmentStatus(Object? value) => _parseAllowlistedStatus(
  value,
  supportedFulfillmentStatuses,
  'fulfillment_status',
);

String parseCustomerOrderState(Object? value) => _parseAllowlistedStatus(
  value,
  supportedCustomerOrderStates,
  'customer_state',
);

String _parseAllowlistedStatus(
  Object? value,
  Set<String> allowlist,
  String field,
) {
  if (value is String && allowlist.contains(value)) {
    return value;
  }
  throw FormatException('Unsupported $field.');
}

void _requireKeys(Map<String, Object?> json, Set<String> keys) {
  for (final key in keys) {
    if (!json.containsKey(key)) {
      throw FormatException('Missing required order field: $key');
    }
  }
}

Map<String, Object?> _requiredMap(Map<String, Object?> json, String key) {
  return _asObjectMap(json[key], key);
}

Map<String, Object?> _asObjectMap(Object? value, String label) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  throw FormatException('$label must be an object.');
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FormatException('$key must be a non-empty string.');
}

String? _nullableString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null || value is String) {
    return value as String?;
  }
  throw FormatException('$key must be a string or null.');
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  throw FormatException('$key must be an integer.');
}

DateTime _requiredDateTime(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return parsed.toUtc();
    }
  }
  throw FormatException('$key must be a valid date-time.');
}

DateTime? _nullableDateTime(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return parsed.toUtc();
    }
  }
  throw FormatException('$key must be a date-time string or null.');
}
