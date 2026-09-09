import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Customer-scoped unresolved top-up Idempotency-Key recovery.
///
/// Persists only customer id, the unresolved key, and a timestamp. Never stores
/// proof bytes, amounts, currencies, payment-method ids, or response bodies.
final class TopupRecoveryRecord {
  const TopupRecoveryRecord({
    required this.customerId,
    required this.idempotencyKey,
    required this.createdAt,
  });

  final int customerId;
  final String idempotencyKey;
  final DateTime createdAt;

  @override
  String toString() =>
      'TopupRecoveryRecord(customerId: $customerId, createdAt: $createdAt)';
}

abstract interface class PendingTopupStore {
  Future<TopupRecoveryRecord?> readForCustomer(int customerId);

  Future<void> writeUnresolved({
    required int customerId,
    required String idempotencyKey,
    required DateTime createdAt,
  });

  Future<void> clearForCustomer(int customerId);
}

final pendingTopupStoreProvider = Provider<PendingTopupStore>((ref) {
  return InMemoryPendingTopupStore();
});

class SecurePendingTopupStore implements PendingTopupStore {
  SecurePendingTopupStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _recordPrefix = 'indirimgo.topup_recovery.v1.';
  static const _version = 1;

  final FlutterSecureStorage _storage;

  String _storageKeyFor(int customerId) => '$_recordPrefix$customerId';

  @override
  Future<TopupRecoveryRecord?> readForCustomer(int customerId) async {
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
    if (existing != null && existing.idempotencyKey != idempotencyKey) {
      return;
    }
    await _storage.write(
      key: _storageKeyFor(customerId),
      value: jsonEncode({
        'version': _version,
        'customer_id': customerId,
        'idempotency_key': idempotencyKey,
        'created_at': createdAt.toUtc().toIso8601String(),
      }),
    );
  }

  @override
  Future<void> clearForCustomer(int customerId) async {
    await _storage.delete(key: _storageKeyFor(customerId));
  }

  TopupRecoveryRecord _decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Top-up recovery payload must be an object.');
    }
    final map = decoded.map((key, value) => MapEntry('$key', value));
    final customerId = map['customer_id'];
    final key = map['idempotency_key'];
    final createdAtRaw = map['created_at'];
    if (customerId is! int || customerId < 1) {
      throw const FormatException('Top-up recovery customer_id is invalid.');
    }
    if (key is! String || key.isEmpty || key.length > 128) {
      throw const FormatException('Top-up recovery key is invalid.');
    }
    if (createdAtRaw is! String) {
      throw const FormatException('Top-up recovery created_at is invalid.');
    }
    final createdAt = DateTime.tryParse(createdAtRaw);
    if (createdAt == null) {
      throw const FormatException('Top-up recovery created_at is invalid.');
    }
    return TopupRecoveryRecord(
      customerId: customerId,
      idempotencyKey: key,
      createdAt: createdAt.toUtc(),
    );
  }

  void _validateKey(String key) {
    if (key.isEmpty || key.length > 128) {
      throw const FormatException('Idempotency-Key length is invalid.');
    }
  }
}

class InMemoryPendingTopupStore implements PendingTopupStore {
  final Map<int, TopupRecoveryRecord> records = {};

  @override
  Future<TopupRecoveryRecord?> readForCustomer(int customerId) async {
    return records[customerId];
  }

  @override
  Future<void> writeUnresolved({
    required int customerId,
    required String idempotencyKey,
    required DateTime createdAt,
  }) async {
    final existing = records[customerId];
    if (existing != null && existing.idempotencyKey != idempotencyKey) {
      return;
    }
    records[customerId] = TopupRecoveryRecord(
      customerId: customerId,
      idempotencyKey: idempotencyKey,
      createdAt: createdAt.toUtc(),
    );
  }

  @override
  Future<void> clearForCustomer(int customerId) async {
    records.remove(customerId);
  }
}
