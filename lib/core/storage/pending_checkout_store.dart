import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Customer-scoped checkout recovery metadata.
///
/// Persists only customer identity, an unresolved Idempotency-Key, an optional
/// completed `order_number` anchor, and creation time. Never stores requirement
/// values, quote bodies, fingerprints, prices, receipt bodies, or tokens.
final class CheckoutRecoveryRecord {
  const CheckoutRecoveryRecord({
    required this.customerId,
    required this.createdAt,
    this.idempotencyKey,
    this.completedOrderNumber,
  });

  final int customerId;
  final DateTime createdAt;

  /// Unresolved attempt key. Absent after success key removal or safe clear.
  final String? idempotencyKey;

  /// Durable owned receipt anchor. Cleared only after explicit acknowledgement.
  final String? completedOrderNumber;

  bool get hasUnresolvedKey {
    final key = idempotencyKey;
    return key != null && key.isNotEmpty;
  }

  bool get hasCompletedAnchor {
    final orderNumber = completedOrderNumber;
    return orderNumber != null && orderNumber.isNotEmpty;
  }

  CheckoutRecoveryRecord copyWith({
    String? idempotencyKey,
    bool clearIdempotencyKey = false,
    String? completedOrderNumber,
    bool clearCompletedOrderNumber = false,
    DateTime? createdAt,
  }) {
    return CheckoutRecoveryRecord(
      customerId: customerId,
      createdAt: createdAt ?? this.createdAt,
      idempotencyKey: clearIdempotencyKey
          ? null
          : (idempotencyKey ?? this.idempotencyKey),
      completedOrderNumber: clearCompletedOrderNumber
          ? null
          : (completedOrderNumber ?? this.completedOrderNumber),
    );
  }

  @override
  String toString() =>
      'CheckoutRecoveryRecord(customerId: $customerId, createdAt: $createdAt, '
      'hasKey: $hasUnresolvedKey, hasAnchor: $hasCompletedAnchor)';
}

/// @Deprecated Prefer [CheckoutRecoveryRecord]. Kept as a typedef for call-site
/// clarity in older tests; identical shape is not guaranteed for legacy fields.
typedef PendingCheckoutAttempt = CheckoutRecoveryRecord;

abstract interface class PendingCheckoutStore {
  /// Reads only the authenticated customer's recovery record.
  Future<CheckoutRecoveryRecord?> readForCustomer(int customerId);

  /// Persists or refreshes an unresolved Idempotency-Key for [customerId].
  ///
  /// Refuses to replace a different unresolved key for the same customer.
  Future<void> writeUnresolved({
    required int customerId,
    required String idempotencyKey,
    required DateTime createdAt,
  });

  /// Writes the completed order anchor while preserving any unresolved key.
  Future<void> markCompleted({
    required int customerId,
    required String orderNumber,
  });

  /// Removes the raw Idempotency-Key while preserving a completed order anchor.
  Future<void> clearPendingKey(int customerId);

  /// Clears the entire recovery record for one customer only.
  Future<void> clearForCustomer(int customerId);
}

/// Defaults to an empty in-memory store for tests. Production overrides this
/// with [SecurePendingCheckoutStore] in `main.dart`.
final pendingCheckoutStoreProvider = Provider<PendingCheckoutStore>((ref) {
  return InMemoryPendingCheckoutStore();
});

/// Generates an OpenAPI-compatible Idempotency-Key (1..128 chars).
///
/// Uses [Random.secure] entropy. Never log or display the returned value.
String generateIdempotencyKey({Random? random}) {
  final source = random ?? Random.secure();
  final bytes = List<int>.generate(32, (_) => source.nextInt(256));
  final encoded = base64Url.encode(bytes).replaceAll('=', '');
  final key = 'ig-$encoded';
  if (key.isEmpty || key.length > 128) {
    throw StateError('Generated Idempotency-Key length is invalid.');
  }
  return key;
}

final _orderNumberPattern = RegExp(r'^ORD-[A-Za-z0-9\-]+$');

class SecurePendingCheckoutStore implements PendingCheckoutStore {
  SecurePendingCheckoutStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _legacyStorageKey = 'indirimgo.pending_checkout.v1';
  static const _recordPrefix = 'indirimgo.checkout_recovery.v2.';
  static const _version = 2;

  final FlutterSecureStorage _storage;

  String _storageKeyFor(int customerId) => '$_recordPrefix$customerId';

  @override
  Future<CheckoutRecoveryRecord?> readForCustomer(int customerId) async {
    await _migrateLegacyIfNeeded();
    try {
      final raw = await _storage.read(key: _storageKeyFor(customerId));
      if (raw == null || raw.isEmpty) {
        return null;
      }
      final record = _decode(raw);
      if (record.customerId != customerId) {
        await _storage.delete(key: _storageKeyFor(customerId));
        return null;
      }
      return record;
    } on FormatException {
      await _storage.delete(key: _storageKeyFor(customerId));
      return null;
    }
  }

  @override
  Future<void> writeUnresolved({
    required int customerId,
    required String idempotencyKey,
    required DateTime createdAt,
  }) async {
    _validateKey(idempotencyKey);
    final existing = await readForCustomer(customerId);
    if (existing != null &&
        existing.hasUnresolvedKey &&
        existing.idempotencyKey != idempotencyKey) {
      // Never overwrite an unresolved same-customer key with a different key.
      return;
    }
    await _writeRecord(
      CheckoutRecoveryRecord(
        customerId: customerId,
        createdAt: createdAt.toUtc(),
        idempotencyKey: idempotencyKey,
        completedOrderNumber: existing?.completedOrderNumber,
      ),
    );
  }

  @override
  Future<void> markCompleted({
    required int customerId,
    required String orderNumber,
  }) async {
    if (!_orderNumberPattern.hasMatch(orderNumber)) {
      throw const FormatException('Completed order_number format is invalid.');
    }
    final existing = await readForCustomer(customerId);
    await _writeRecord(
      CheckoutRecoveryRecord(
        customerId: customerId,
        createdAt: existing?.createdAt ?? DateTime.now().toUtc(),
        idempotencyKey: existing?.idempotencyKey,
        completedOrderNumber: orderNumber,
      ),
    );
  }

  @override
  Future<void> clearPendingKey(int customerId) async {
    final existing = await readForCustomer(customerId);
    if (existing == null) {
      return;
    }
    if (!existing.hasCompletedAnchor) {
      await clearForCustomer(customerId);
      return;
    }
    await _writeRecord(existing.copyWith(clearIdempotencyKey: true));
  }

  @override
  Future<void> clearForCustomer(int customerId) async {
    await _storage.delete(key: _storageKeyFor(customerId));
  }

  Future<void> _writeRecord(CheckoutRecoveryRecord record) async {
    final payload = jsonEncode({
      'version': _version,
      'customer_id': record.customerId,
      if (record.idempotencyKey != null)
        'idempotency_key': record.idempotencyKey,
      if (record.completedOrderNumber != null)
        'completed_order_number': record.completedOrderNumber,
      'created_at': record.createdAt.toUtc().toIso8601String(),
    });
    await _storage.write(
      key: _storageKeyFor(record.customerId),
      value: payload,
    );
  }

  Future<void> _migrateLegacyIfNeeded() async {
    try {
      final raw = await _storage.read(key: _legacyStorageKey);
      if (raw == null || raw.isEmpty) {
        return;
      }
      final legacy = _decodeLegacyV1(raw);
      final existing = await _storage.read(
        key: _storageKeyFor(legacy.customerId),
      );
      if (existing == null || existing.isEmpty) {
        await _writeRecord(legacy);
      }
      await _storage.delete(key: _legacyStorageKey);
    } on FormatException {
      await _storage.delete(key: _legacyStorageKey);
    } on Object {
      // Leave legacy in place; next read may retry. Do not wipe other customers.
    }
  }

  CheckoutRecoveryRecord _decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException(
        'Checkout recovery payload must be an object.',
      );
    }
    final map = decoded.map((key, value) => MapEntry('$key', value));
    final version = map['version'];
    if (version != _version && version != 1) {
      throw const FormatException('Unsupported checkout recovery version.');
    }
    return _recordFromMap(map);
  }

  CheckoutRecoveryRecord _decodeLegacyV1(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Legacy pending checkout must be an object.');
    }
    final map = decoded.map((key, value) => MapEntry('$key', value));
    return _recordFromMap(map);
  }

  CheckoutRecoveryRecord _recordFromMap(Map<String, Object?> map) {
    final customerId = map['customer_id'];
    final key = map['idempotency_key'];
    final orderNumber = map['completed_order_number'];
    final createdAtRaw = map['created_at'];
    if (customerId is! int || customerId < 1) {
      throw const FormatException('Checkout recovery customer_id is invalid.');
    }
    String? idempotencyKey;
    if (key != null) {
      if (key is! String || key.isEmpty || key.length > 128) {
        throw const FormatException('Checkout recovery key is invalid.');
      }
      idempotencyKey = key;
    }
    String? completedOrderNumber;
    if (orderNumber != null) {
      if (orderNumber is! String ||
          !_orderNumberPattern.hasMatch(orderNumber)) {
        throw const FormatException(
          'Checkout recovery completed_order_number is invalid.',
        );
      }
      completedOrderNumber = orderNumber;
    }
    if (idempotencyKey == null && completedOrderNumber == null) {
      throw const FormatException('Checkout recovery record is empty.');
    }
    if (createdAtRaw is! String) {
      throw const FormatException('Checkout recovery created_at is invalid.');
    }
    final createdAt = DateTime.tryParse(createdAtRaw);
    if (createdAt == null) {
      throw const FormatException('Checkout recovery created_at is invalid.');
    }
    return CheckoutRecoveryRecord(
      customerId: customerId,
      idempotencyKey: idempotencyKey,
      completedOrderNumber: completedOrderNumber,
      createdAt: createdAt.toUtc(),
    );
  }

  void _validateKey(String key) {
    if (key.isEmpty || key.length > 128) {
      throw const FormatException('Idempotency-Key length is invalid.');
    }
  }
}

/// In-memory store for deterministic tests.
class InMemoryPendingCheckoutStore implements PendingCheckoutStore {
  final Map<int, CheckoutRecoveryRecord> records = {};
  int writeCount = 0;
  int clearCount = 0;
  final List<String> writeOps = [];

  /// Test helper mirroring the previous single-slot surface.
  CheckoutRecoveryRecord? get attempt {
    if (records.length == 1) {
      return records.values.single;
    }
    return null;
  }

  set attempt(CheckoutRecoveryRecord? value) {
    records.clear();
    if (value != null) {
      records[value.customerId] = value;
    }
  }

  @override
  Future<CheckoutRecoveryRecord?> readForCustomer(int customerId) async {
    return records[customerId];
  }

  @override
  Future<void> writeUnresolved({
    required int customerId,
    required String idempotencyKey,
    required DateTime createdAt,
  }) async {
    final existing = records[customerId];
    if (existing != null &&
        existing.hasUnresolvedKey &&
        existing.idempotencyKey != idempotencyKey) {
      return;
    }
    records[customerId] = CheckoutRecoveryRecord(
      customerId: customerId,
      createdAt: createdAt.toUtc(),
      idempotencyKey: idempotencyKey,
      completedOrderNumber: existing?.completedOrderNumber,
    );
    writeCount += 1;
    writeOps.add('unresolved');
  }

  @override
  Future<void> markCompleted({
    required int customerId,
    required String orderNumber,
  }) async {
    final existing = records[customerId];
    records[customerId] = CheckoutRecoveryRecord(
      customerId: customerId,
      createdAt: existing?.createdAt ?? DateTime.now().toUtc(),
      idempotencyKey: existing?.idempotencyKey,
      completedOrderNumber: orderNumber,
    );
    writeCount += 1;
    writeOps.add('completed:$orderNumber');
  }

  @override
  Future<void> clearPendingKey(int customerId) async {
    final existing = records[customerId];
    if (existing == null) {
      return;
    }
    if (!existing.hasCompletedAnchor) {
      await clearForCustomer(customerId);
      return;
    }
    records[customerId] = existing.copyWith(clearIdempotencyKey: true);
    writeOps.add('clearKey');
  }

  @override
  Future<void> clearForCustomer(int customerId) async {
    if (records.remove(customerId) != null) {
      clearCount += 1;
      writeOps.add('clearCustomer');
    }
  }
}
