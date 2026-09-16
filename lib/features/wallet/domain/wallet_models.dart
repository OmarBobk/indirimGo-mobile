import 'package:indirimgo_mobile/features/catalog/domain/catalog_models.dart';

const int walletPageSize = 20;

const supportedTopupStatuses = <String>{
  'pending',
  'approved',
  'rejected',
  'cancelled',
};

const supportedTopupCurrencies = <String>{'USD', 'TRY'};

const supportedWalletDirections = <String>{'credit', 'debit'};

const supportedWalletTransactionTypes = <String>{
  'purchase',
  'topup',
  'refund',
  'adjustment',
  'commission_credit',
  'commission_reversal',
  'commission_clawback_waiver',
  'commission_reversal_correction',
};

final _moneyAmountPattern = RegExp(r'^-?\d+\.\d{2}$');
final _enteredAmountPattern = RegExp(r'^\d+\.\d{2}$');
final _topupPublicRefPattern = RegExp(r'^TUP-[A-Za-z0-9]+$');

class WalletSummary {
  const WalletSummary({
    required this.availableToSpend,
    required this.pricesVisible,
    this.pendingTopupPublicRef,
  });

  factory WalletSummary.fromJson(Map<String, Object?> json) {
    _requireKeys(json, const {'data', 'meta'});
    final data = _asObjectMap(json['data'], 'data');
    final meta = _asObjectMap(json['meta'], 'meta');
    _requireKeys(data, const {
      'available_to_spend',
      'pending_topup_public_ref',
    });
    _requireKeys(meta, const {'prices_visible'});
    return WalletSummary(
      availableToSpend: Money.fromJson(
        _asObjectMap(data['available_to_spend'], 'available_to_spend'),
      ),
      pricesVisible: _requiredBool(meta, 'prices_visible'),
      pendingTopupPublicRef: _optionalPublicRef(
        data['pending_topup_public_ref'],
      ),
    );
  }

  final Money availableToSpend;
  final bool pricesVisible;
  final String? pendingTopupPublicRef;
}

class EnteredAmountDisplay {
  const EnteredAmountDisplay({required this.currency, required this.formatted});

  factory EnteredAmountDisplay.fromJson(Map<String, Object?> json) {
    _requireKeys(json, const {'currency', 'formatted'});
    final currency = _requiredString(json, 'currency');
    if (!supportedTopupCurrencies.contains(currency)) {
      throw const FormatException('Entered currency must be USD or TRY.');
    }
    return EnteredAmountDisplay(
      currency: currency,
      formatted: _requiredString(json, 'formatted'),
    );
  }

  final String currency;
  final String formatted;
}

class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.name,
    this.instructions,
    this.imageUrl,
  });

  factory PaymentMethod.fromJson(Map<String, Object?> json) {
    _requireKeys(json, const {'id', 'name', 'instructions', 'image_url'});
    final id = _requiredInt(json, 'id');
    if (id < 1) {
      throw const FormatException('payment method id must be at least 1.');
    }
    return PaymentMethod(
      id: id,
      name: _requiredString(json, 'name'),
      instructions: _optionalString(json['instructions']),
      imageUrl: _optionalString(json['image_url']),
    );
  }

  final int id;
  final String name;
  final String? instructions;
  final String? imageUrl;
}

class WalletTransactionItem {
  const WalletTransactionItem({
    required this.publicRef,
    required this.type,
    required this.direction,
    required this.amount,
    required this.occurredAt,
    this.relatedOrderNumber,
    this.relatedTopupPublicRef,
    this.customerSafeDescription,
  });

  factory WalletTransactionItem.fromJson(Map<String, Object?> json) {
    _requireKeys(json, const {
      'public_ref',
      'type',
      'direction',
      'amount',
      'occurred_at',
      'related_order_number',
      'related_topup_public_ref',
      'customer_safe_description',
    });
    final type = _requiredString(json, 'type');
    final direction = _requiredString(json, 'direction');
    if (!supportedWalletTransactionTypes.contains(type)) {
      throw const FormatException('Unsupported wallet transaction type.');
    }
    if (!supportedWalletDirections.contains(direction)) {
      throw const FormatException('Unsupported wallet transaction direction.');
    }
    return WalletTransactionItem(
      publicRef: _requiredString(json, 'public_ref'),
      type: type,
      direction: direction,
      amount: Money.fromJson(_asObjectMap(json['amount'], 'amount')),
      occurredAt: _requiredDateTime(json, 'occurred_at'),
      relatedOrderNumber: _optionalString(json['related_order_number']),
      relatedTopupPublicRef: _optionalPublicRef(
        json['related_topup_public_ref'],
      ),
      customerSafeDescription: _optionalString(
        json['customer_safe_description'],
      ),
    );
  }

  final String publicRef;
  final String type;
  final String direction;
  final Money amount;
  final DateTime occurredAt;
  final String? relatedOrderNumber;
  final String? relatedTopupPublicRef;
  final String? customerSafeDescription;
}

class WalletTransactionPage {
  const WalletTransactionPage({required this.items, required this.pagination});

  factory WalletTransactionPage.fromJson(Map<String, Object?> json) {
    _requireKeys(json, const {'data', 'meta'});
    final meta = _asObjectMap(json['meta'], 'meta');
    _requireKeys(meta, const {'pagination'});
    return WalletTransactionPage(
      items: _requiredObjectList(
        json['data'],
        'data',
      ).map(WalletTransactionItem.fromJson).toList(growable: false),
      pagination: OffsetPagination.fromJson(
        _asObjectMap(meta['pagination'], 'pagination'),
      ),
    );
  }

  final List<WalletTransactionItem> items;
  final OffsetPagination pagination;
}

class TopupListItem {
  const TopupListItem({
    required this.publicRef,
    required this.status,
    required this.pendingUntilAdminApproval,
    required this.credited,
    required this.moneyMoved,
    required this.canRetry,
    required this.walletAmount,
    required this.hasProof,
    required this.submittedAt,
    this.paymentMethodName,
  });

  factory TopupListItem.fromJson(Map<String, Object?> json) {
    _requireKeys(json, const {
      'public_ref',
      'status',
      'pending_until_admin_approval',
      'credited',
      'money_moved',
      'can_retry',
      'wallet_amount',
      'payment_method_name',
      'has_proof',
      'submitted_at',
    });
    final status = _requiredString(json, 'status');
    if (!supportedTopupStatuses.contains(status)) {
      throw const FormatException('Unsupported top-up status.');
    }
    return TopupListItem(
      publicRef: _requiredPublicRef(json, 'public_ref'),
      status: status,
      pendingUntilAdminApproval: _requiredBool(
        json,
        'pending_until_admin_approval',
      ),
      credited: _requiredBool(json, 'credited'),
      moneyMoved: _requiredBool(json, 'money_moved'),
      canRetry: _requiredBool(json, 'can_retry'),
      walletAmount: Money.fromJson(
        _asObjectMap(json['wallet_amount'], 'wallet_amount'),
      ),
      paymentMethodName: _optionalString(json['payment_method_name']),
      hasProof: _requiredBool(json, 'has_proof'),
      submittedAt: _requiredDateTime(json, 'submitted_at'),
    );
  }

  final String publicRef;
  final String status;
  final bool pendingUntilAdminApproval;
  final bool credited;
  final bool moneyMoved;
  final bool canRetry;
  final Money walletAmount;
  final String? paymentMethodName;
  final bool hasProof;
  final DateTime submittedAt;
}

class TopupListPage {
  const TopupListPage({
    required this.items,
    required this.pagination,
    this.pendingTopupPublicRef,
  });

  factory TopupListPage.fromJson(Map<String, Object?> json) {
    _requireKeys(json, const {'data', 'meta'});
    final meta = _asObjectMap(json['meta'], 'meta');
    _requireKeys(meta, const {'pagination', 'pending_topup_public_ref'});
    return TopupListPage(
      items: _requiredObjectList(
        json['data'],
        'data',
      ).map(TopupListItem.fromJson).toList(growable: false),
      pagination: OffsetPagination.fromJson(
        _asObjectMap(meta['pagination'], 'pagination'),
      ),
      pendingTopupPublicRef: _optionalPublicRef(
        meta['pending_topup_public_ref'],
      ),
    );
  }

  final List<TopupListItem> items;
  final OffsetPagination pagination;
  final String? pendingTopupPublicRef;
}

class TopupDetail {
  const TopupDetail({
    required this.publicRef,
    required this.status,
    required this.pendingUntilAdminApproval,
    required this.credited,
    required this.moneyMoved,
    required this.canRetry,
    required this.enteredAmount,
    required this.enteredCurrency,
    required this.enteredDisplay,
    required this.walletAmount,
    required this.hasProof,
    this.paymentMethod,
    this.customerSafeReason,
    this.submittedAt,
    this.reviewedAt,
    this.creditedAt,
  });

  factory TopupDetail.fromJson(Map<String, Object?> json) {
    _requireKeys(json, const {
      'public_ref',
      'status',
      'pending_until_admin_approval',
      'credited',
      'money_moved',
      'can_retry',
      'entered_amount',
      'entered_currency',
      'entered_display',
      'wallet_amount',
      'payment_method',
      'has_proof',
      'customer_safe_reason',
      'submitted_at',
      'reviewed_at',
      'credited_at',
    });
    final status = _requiredString(json, 'status');
    final enteredCurrency = _requiredString(json, 'entered_currency');
    final enteredAmount = _requiredString(json, 'entered_amount');
    if (!supportedTopupStatuses.contains(status)) {
      throw const FormatException('Unsupported top-up status.');
    }
    if (!supportedTopupCurrencies.contains(enteredCurrency)) {
      throw const FormatException('Entered currency must be USD or TRY.');
    }
    if (!_enteredAmountPattern.hasMatch(enteredAmount)) {
      throw const FormatException(
        'Entered amount must be a two-decimal string.',
      );
    }
    final paymentMethodRaw = json['payment_method'];
    return TopupDetail(
      publicRef: _requiredPublicRef(json, 'public_ref'),
      status: status,
      pendingUntilAdminApproval: _requiredBool(
        json,
        'pending_until_admin_approval',
      ),
      credited: _requiredBool(json, 'credited'),
      moneyMoved: _requiredBool(json, 'money_moved'),
      canRetry: _requiredBool(json, 'can_retry'),
      enteredAmount: enteredAmount,
      enteredCurrency: enteredCurrency,
      enteredDisplay: EnteredAmountDisplay.fromJson(
        _asObjectMap(json['entered_display'], 'entered_display'),
      ),
      walletAmount: Money.fromJson(
        _asObjectMap(json['wallet_amount'], 'wallet_amount'),
      ),
      paymentMethod: paymentMethodRaw == null
          ? null
          : PaymentMethod.fromJson(
              _asObjectMap(paymentMethodRaw, 'payment_method'),
            ),
      hasProof: _requiredBool(json, 'has_proof'),
      customerSafeReason: _optionalString(json['customer_safe_reason']),
      submittedAt: _optionalDateTime(json['submitted_at']),
      reviewedAt: _optionalDateTime(json['reviewed_at']),
      creditedAt: _optionalDateTime(json['credited_at']),
    );
  }

  final String publicRef;
  final String status;
  final bool pendingUntilAdminApproval;
  final bool credited;
  final bool moneyMoved;
  final bool canRetry;
  final String enteredAmount;
  final String enteredCurrency;
  final EnteredAmountDisplay enteredDisplay;
  final Money walletAmount;
  final PaymentMethod? paymentMethod;
  final bool hasProof;
  final String? customerSafeReason;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final DateTime? creditedAt;
}

class TopupSubmitResult {
  const TopupSubmitResult({
    required this.replayed,
    required this.pendingUntilAdminApproval,
    required this.topup,
  });

  factory TopupSubmitResult.fromJson(Map<String, Object?> json) {
    _requireKeys(json, const {'data'});
    final data = _asObjectMap(json['data'], 'data');
    _requireKeys(data, const {
      'replayed',
      'pending_until_admin_approval',
      'topup',
    });
    return TopupSubmitResult(
      replayed: _requiredBool(data, 'replayed'),
      pendingUntilAdminApproval: _requiredBool(
        data,
        'pending_until_admin_approval',
      ),
      topup: TopupDetail.fromJson(_asObjectMap(data['topup'], 'topup')),
    );
  }

  final bool replayed;
  final bool pendingUntilAdminApproval;
  final TopupDetail topup;
}

enum TopupStatusState { completed, processing, failed }

class TopupStatusResult {
  const TopupStatusResult({
    required this.state,
    this.replayed,
    this.pendingUntilAdminApproval,
    this.topup,
    this.retryAfterSeconds,
    this.code,
  });

  factory TopupStatusResult.fromResponse({
    required int statusCode,
    required Map<String, Object?> json,
  }) {
    _requireKeys(json, const {'data'});
    final data = _asObjectMap(json['data'], 'data');
    final state = _requiredString(data, 'state');
    if (statusCode == 202 || state == 'processing') {
      return TopupStatusResult(
        state: TopupStatusState.processing,
        retryAfterSeconds: _optionalInt(data['retry_after_seconds']) ?? 2,
      );
    }
    if (state == 'failed') {
      return TopupStatusResult(
        state: TopupStatusState.failed,
        code: _optionalString(data['code']),
      );
    }
    if (state != 'completed') {
      throw const FormatException('Unsupported top-up status state.');
    }
    return TopupStatusResult(
      state: TopupStatusState.completed,
      replayed: _optionalBool(data['replayed']),
      pendingUntilAdminApproval: _optionalBool(
        data['pending_until_admin_approval'],
      ),
      topup: TopupDetail.fromJson(_asObjectMap(data['topup'], 'topup')),
    );
  }

  final TopupStatusState state;
  final bool? replayed;
  final bool? pendingUntilAdminApproval;
  final TopupDetail? topup;
  final int? retryAfterSeconds;
  final String? code;
}

class SelectedTopupProof {
  const SelectedTopupProof({
    required this.filename,
    this.path,
    this.bytes,
    this.mimeType,
  });

  final String filename;
  final String? path;
  final List<int>? bytes;
  final String? mimeType;
}

void _requireKeys(Map<String, Object?> json, Set<String> keys) {
  for (final key in keys) {
    if (!json.containsKey(key)) {
      throw FormatException('Missing required wallet field: $key');
    }
  }
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

List<Map<String, Object?>> _requiredObjectList(Object? value, String label) {
  if (value is! List) {
    throw FormatException('$label must be a list.');
  }
  return [for (final item in value) _asObjectMap(item, label)];
}

bool _requiredBool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is bool) {
    return value;
  }
  throw FormatException('$key must be a boolean.');
}

bool? _optionalBool(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is bool) {
    return value;
  }
  throw const FormatException('Optional boolean is invalid.');
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  throw FormatException('$key must be an integer.');
}

int? _optionalInt(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  throw const FormatException('Optional integer is invalid.');
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FormatException('$key must be a non-empty string.');
}

String? _optionalString(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value.isEmpty ? null : value;
  }
  throw const FormatException('Optional string is invalid.');
}

String _requiredPublicRef(Map<String, Object?> json, String key) {
  final value = _requiredString(json, key);
  if (!_topupPublicRefPattern.hasMatch(value)) {
    throw FormatException('$key must be a TUP public reference.');
  }
  return value;
}

String? _optionalPublicRef(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is String && _topupPublicRefPattern.hasMatch(value)) {
    return value;
  }
  if (value is String && value.isEmpty) {
    return null;
  }
  throw const FormatException('Top-up public ref is invalid.');
}

DateTime _requiredDateTime(Map<String, Object?> json, String key) {
  final parsed = _optionalDateTime(json[key]);
  if (parsed == null) {
    throw FormatException('$key must be an ISO-8601 timestamp.');
  }
  return parsed;
}

DateTime? _optionalDateTime(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    return DateTime.tryParse(value)?.toUtc();
  }
  throw const FormatException('Timestamp is invalid.');
}

bool isValidEnteredAmount(String value) {
  return _enteredAmountPattern.hasMatch(value) ||
      RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value);
}

bool isMoneyAmount(String value) => _moneyAmountPattern.hasMatch(value);
