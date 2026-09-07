/// Manual OpenAPI 1.2.0 purchase models for Mobile M3.2.
///
/// Money amounts stay decimal strings. Flutter never multiplies price by
/// quantity, never computes totals/affordability, and never logs requirement
/// values, idempotency keys, or quote fingerprints.
library;

import 'package:indirimgo_mobile/features/catalog/domain/catalog_models.dart';
import 'package:indirimgo_mobile/features/orders/domain/order_models.dart';

export 'package:indirimgo_mobile/features/catalog/domain/catalog_models.dart'
    show
        Money,
        MoneyDisplay,
        PackageRequirementField,
        ProductAmountMode,
        ProductOption,
        RequirementInputType;

/// Local UX ceiling for fixed quantity. Laravel remains authoritative.
const int purchaseQuantityMax = 9999;

class CheckoutLineItemRequest {
  const CheckoutLineItemRequest({
    required this.productId,
    this.packageId,
    this.quantity,
    this.requestedAmount,
    this.requirements = const {},
  });

  final int productId;
  final int? packageId;
  final int? quantity;
  final int? requestedAmount;

  /// Sensitive fulfillment inputs. Never log or include in [toString].
  final Map<String, String> requirements;

  Map<String, Object?> toJson() {
    return {
      'product_id': productId,
      if (packageId != null) 'package_id': packageId,
      if (quantity != null) 'quantity': quantity,
      if (requestedAmount != null) 'requested_amount': requestedAmount,
      'requirements': requirements,
    };
  }

  @override
  String toString() =>
      'CheckoutLineItemRequest(productId: $productId, packageId: $packageId, '
      'quantity: $quantity, requestedAmount: $requestedAmount)';
}

class QuoteWalletAffordability {
  const QuoteWalletAffordability({
    required this.availableToSpend,
    required this.canAfford,
  });

  factory QuoteWalletAffordability.fromJson(Map<String, Object?> json) {
    _requireKeys(json, const {'available_to_spend', 'can_afford'});
    return QuoteWalletAffordability(
      availableToSpend: Money.fromJson(
        _requiredMap(json, 'available_to_spend'),
      ),
      canAfford: _requiredBool(json, 'can_afford'),
    );
  }

  final Money availableToSpend;
  final bool canAfford;
}

class CheckoutQuoteLine {
  const CheckoutQuoteLine({
    required this.productId,
    required this.packageId,
    required this.name,
    required this.amountMode,
    required this.quantity,
    required this.requestedAmount,
    required this.unitPrice,
    required this.lineTotal,
    required this.requirementsSchema,
  });

  factory CheckoutQuoteLine.fromJson(Map<String, Object?> json) {
    _requireKeys(json, const {
      'product_id',
      'package_id',
      'name',
      'amount_mode',
      'quantity',
      'requested_amount',
      'unit_price',
      'line_total',
      'requirements_schema',
    });
    final modeRaw = _requiredString(json, 'amount_mode');
    final mode = switch (modeRaw) {
      'fixed' => ProductAmountMode.fixed,
      'custom' => ProductAmountMode.custom,
      _ => throw FormatException('Unsupported amount_mode: $modeRaw'),
    };
    final schemaRaw = json['requirements_schema'];
    if (schemaRaw is! List) {
      throw const FormatException('requirements_schema must be an array.');
    }
    return CheckoutQuoteLine(
      productId: _requiredInt(json, 'product_id'),
      packageId: _requiredInt(json, 'package_id'),
      name: _requiredString(json, 'name'),
      amountMode: mode,
      quantity: _requiredPositiveInt(json, 'quantity'),
      requestedAmount: _nullableInt(json, 'requested_amount'),
      unitPrice: Money.fromJson(_requiredMap(json, 'unit_price')),
      lineTotal: Money.fromJson(_requiredMap(json, 'line_total')),
      requirementsSchema: [
        for (final item in schemaRaw)
          PackageRequirementField.fromJson(
            _asObjectMap(item, 'requirements_schema item'),
          ),
      ],
    );
  }

  final int productId;
  final int packageId;
  final String name;
  final ProductAmountMode amountMode;
  final int quantity;
  final int? requestedAmount;
  final Money unitPrice;
  final Money lineTotal;
  final List<PackageRequirementField> requirementsSchema;
}

class CheckoutQuote {
  const CheckoutQuote({
    required this.quoteFingerprint,
    required this.expiresAt,
    required this.item,
    required this.subtotal,
    required this.fee,
    required this.total,
    required this.wallet,
    required this.pricesVisible,
  });

  factory CheckoutQuote.fromJson(Map<String, Object?> json) {
    _requireKeys(json, const {
      'quote_fingerprint',
      'expires_at',
      'item',
      'subtotal',
      'fee',
      'total',
      'wallet',
      'meta',
    });
    final meta = _requiredMap(json, 'meta');
    _requireKeys(meta, const {'prices_visible'});
    final fingerprint = _requiredString(json, 'quote_fingerprint');
    if (fingerprint.length < 16 || fingerprint.length > 2048) {
      throw const FormatException('quote_fingerprint length is invalid.');
    }
    return CheckoutQuote(
      quoteFingerprint: fingerprint,
      expiresAt: _requiredDateTime(json, 'expires_at'),
      item: CheckoutQuoteLine.fromJson(_requiredMap(json, 'item')),
      subtotal: Money.fromJson(_requiredMap(json, 'subtotal')),
      fee: Money.fromJson(_requiredMap(json, 'fee')),
      total: Money.fromJson(_requiredMap(json, 'total')),
      wallet: QuoteWalletAffordability.fromJson(_requiredMap(json, 'wallet')),
      pricesVisible: _requiredBool(meta, 'prices_visible'),
    );
  }

  factory CheckoutQuote.fromSuccessJson(Map<String, Object?> json) {
    _requireKeys(json, const {'data'});
    return CheckoutQuote.fromJson(_requiredMap(json, 'data'));
  }

  /// Opaque server fingerprint. Never log, display, or put in exceptions.
  final String quoteFingerprint;
  final DateTime expiresAt;
  final CheckoutQuoteLine item;
  final Money subtotal;
  final Money fee;
  final Money total;
  final QuoteWalletAffordability wallet;
  final bool pricesVisible;

  bool isExpiredAt(DateTime now) => !now.toUtc().isBefore(expiresAt.toUtc());

  @override
  String toString() =>
      'CheckoutQuote(expiresAt: $expiresAt, canAfford: ${wallet.canAfford})';
}

class PurchaseReceiptItem {
  const PurchaseReceiptItem({
    required this.productId,
    required this.packageId,
    required this.name,
    required this.amountMode,
    required this.quantity,
    required this.requestedAmount,
    required this.lineTotal,
  });

  factory PurchaseReceiptItem.fromJson(Map<String, Object?> json) {
    _requireKeys(json, const {
      'product_id',
      'package_id',
      'name',
      'amount_mode',
      'quantity',
      'requested_amount',
      'line_total',
    });
    final modeRaw = _requiredString(json, 'amount_mode');
    final mode = switch (modeRaw) {
      'fixed' => ProductAmountMode.fixed,
      'custom' => ProductAmountMode.custom,
      _ => throw FormatException('Unsupported amount_mode: $modeRaw'),
    };
    return PurchaseReceiptItem(
      productId: _nullableInt(json, 'product_id'),
      packageId: _nullableInt(json, 'package_id'),
      name: _requiredString(json, 'name'),
      amountMode: mode,
      quantity: _requiredInt(json, 'quantity'),
      requestedAmount: _nullableInt(json, 'requested_amount'),
      lineTotal: Money.fromJson(_requiredMap(json, 'line_total')),
    );
  }

  final int? productId;
  final int? packageId;
  final String name;
  final ProductAmountMode amountMode;
  final int quantity;
  final int? requestedAmount;
  final Money lineTotal;
}

class PurchaseReceipt {
  const PurchaseReceipt({
    required this.orderNumber,
    required this.status,
    required this.paymentStatus,
    required this.currency,
    required this.total,
    required this.paidAt,
    required this.createdAt,
    required this.fulfillmentStatus,
    required this.customerState,
    required this.fulfillmentSummary,
    required this.items,
  });

  factory PurchaseReceipt.fromJson(Map<String, Object?> json) {
    _requireKeys(json, const {
      'order_number',
      'status',
      'payment_status',
      'currency',
      'total',
      'paid_at',
      'created_at',
      'fulfillment_status',
      'customer_state',
      'fulfillment_summary',
      'items',
    });
    final orderNumber = _requiredString(json, 'order_number');
    if (!orderNumberPattern.hasMatch(orderNumber)) {
      throw const FormatException('order_number format is invalid.');
    }
    final currency = _requiredString(json, 'currency');
    if (currency != 'USD') {
      throw const FormatException('Receipt currency must be USD.');
    }
    final paymentStatus = parsePaymentStatus(json['payment_status']);
    final itemsRaw = json['items'];
    if (itemsRaw is! List) {
      throw const FormatException('items must be an array.');
    }
    return PurchaseReceipt(
      orderNumber: orderNumber,
      status: _requiredString(json, 'status'),
      paymentStatus: paymentStatus,
      currency: currency,
      total: Money.fromJson(_requiredMap(json, 'total')),
      paidAt: _nullableDateTime(json, 'paid_at'),
      createdAt: _requiredDateTime(json, 'created_at'),
      fulfillmentStatus: parseFulfillmentStatus(json['fulfillment_status']),
      customerState: parseCustomerOrderState(json['customer_state']),
      fulfillmentSummary: FulfillmentSummary.fromJson(
        _requiredMap(json, 'fulfillment_summary'),
      ),
      items: [
        for (final item in itemsRaw)
          PurchaseReceiptItem.fromJson(_asObjectMap(item, 'items item')),
      ],
    );
  }

  final String orderNumber;
  final String status;
  final String paymentStatus;
  final String currency;
  final Money total;
  final DateTime? paidAt;
  final DateTime createdAt;
  final String fulfillmentStatus;
  final String customerState;
  final FulfillmentSummary fulfillmentSummary;
  final List<PurchaseReceiptItem> items;
}

class CheckoutResult {
  const CheckoutResult({required this.replayed, required this.order});

  factory CheckoutResult.fromJson(Map<String, Object?> json) {
    _requireKeys(json, const {'data'});
    final data = _requiredMap(json, 'data');
    _requireKeys(data, const {'replayed', 'order'});
    return CheckoutResult(
      replayed: _requiredBool(data, 'replayed'),
      order: PurchaseReceipt.fromJson(_requiredMap(data, 'order')),
    );
  }

  final bool replayed;
  final PurchaseReceipt order;
}

enum CheckoutStatusState { completed, failed, processing }

class CheckoutStatus {
  const CheckoutStatus({
    required this.state,
    this.replayed,
    this.order,
    this.code,
    this.retryAfterSeconds,
  });

  factory CheckoutStatus.fromResponse({
    required int statusCode,
    required Map<String, Object?> json,
  }) {
    _requireKeys(json, const {'data'});
    final data = _requiredMap(json, 'data');
    _requireKeys(data, const {'state'});
    final stateRaw = _requiredString(data, 'state');
    if (statusCode == 202 || stateRaw == 'processing') {
      _requireKeys(data, const {'retry_after_seconds'});
      final retry = _requiredPositiveInt(data, 'retry_after_seconds');
      return CheckoutStatus(
        state: CheckoutStatusState.processing,
        retryAfterSeconds: retry,
      );
    }
    if (stateRaw == 'completed') {
      return CheckoutStatus(
        state: CheckoutStatusState.completed,
        replayed: data.containsKey('replayed')
            ? _requiredBool(data, 'replayed')
            : null,
        order: data.containsKey('order')
            ? PurchaseReceipt.fromJson(_requiredMap(data, 'order'))
            : null,
      );
    }
    if (stateRaw == 'failed') {
      final rawCode = data['code'];
      final code = rawCode == null
          ? null
          : (rawCode is String ? rawCode : null);
      return CheckoutStatus(state: CheckoutStatusState.failed, code: code);
    }
    throw FormatException('Unsupported checkout status state: $stateRaw');
  }

  final CheckoutStatusState state;
  final bool? replayed;
  final PurchaseReceipt? order;
  final String? code;
  final int? retryAfterSeconds;
}

/// In-memory customer-scoped buy-now draft. Discarded on restart.
class PurchaseDraft {
  const PurchaseDraft({
    required this.customerId,
    required this.packageId,
    required this.packageName,
    required this.product,
    required this.requirementsSchema,
    required this.requirementsSupported,
    required this.pricesVisible,
    this.quantity,
    this.requestedAmount,
    this.requirementValues = const {},
    this.quote,
  });

  final int customerId;
  final int packageId;
  final String packageName;
  final ProductOption product;
  final List<PackageRequirementField> requirementsSchema;
  final bool requirementsSupported;
  final bool pricesVisible;
  final int? quantity;
  final int? requestedAmount;

  /// Sensitive. Never persist, log, or include in [toString]/exceptions.
  final Map<String, String> requirementValues;
  final CheckoutQuote? quote;

  bool get isCustom => product.isCustom;
  bool get isFixed => product.isFixed;

  PurchaseDraft copyWith({
    int? quantity,
    bool clearQuantity = false,
    int? requestedAmount,
    bool clearRequestedAmount = false,
    Map<String, String>? requirementValues,
    CheckoutQuote? quote,
    bool clearQuote = false,
  }) {
    return PurchaseDraft(
      customerId: customerId,
      packageId: packageId,
      packageName: packageName,
      product: product,
      requirementsSchema: requirementsSchema,
      requirementsSupported: requirementsSupported,
      pricesVisible: pricesVisible,
      quantity: clearQuantity ? null : (quantity ?? this.quantity),
      requestedAmount: clearRequestedAmount
          ? null
          : (requestedAmount ?? this.requestedAmount),
      requirementValues: requirementValues ?? this.requirementValues,
      quote: clearQuote ? null : (quote ?? this.quote),
    );
  }

  CheckoutLineItemRequest toLineItem() {
    return CheckoutLineItemRequest(
      productId: product.id,
      packageId: packageId,
      quantity: isFixed ? quantity : null,
      requestedAmount: isCustom ? requestedAmount : null,
      requirements: requirementValues,
    );
  }

  @override
  String toString() =>
      'PurchaseDraft(customerId: $customerId, packageId: $packageId, '
      'productId: ${product.id}, hasQuote: ${quote != null})';
}

void _requireKeys(Map<String, Object?> json, Set<String> keys) {
  for (final key in keys) {
    if (!json.containsKey(key)) {
      throw FormatException('Missing required purchase field: $key');
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
    return value.map((mapKey, mapValue) => MapEntry('$mapKey', mapValue));
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

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  throw FormatException('$key must be an integer.');
}

int _requiredPositiveInt(Map<String, Object?> json, String key) {
  final value = _requiredInt(json, key);
  if (value < 1) {
    throw FormatException('$key must be >= 1.');
  }
  return value;
}

int? _nullableInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  throw FormatException('$key must be an integer or null.');
}

bool _requiredBool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is bool) {
    return value;
  }
  throw FormatException('$key must be a boolean.');
}

DateTime _requiredDateTime(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('$key must be a date-time string.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('$key must be a valid date-time.');
  }
  return parsed.toUtc();
}

DateTime? _nullableDateTime(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('$key must be a date-time string or null.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('$key must be a valid date-time.');
  }
  return parsed.toUtc();
}
