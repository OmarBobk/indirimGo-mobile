import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Minimal customer-scoped recovery metadata for an in-flight checkout.
///
/// Persists only customer identity, raw Idempotency-Key, and creation time.
/// Never stores requirement values, quote bodies, fingerprints, or tokens.
final class PendingCheckoutAttempt {
  const PendingCheckoutAttempt({
    required this.customerId,
    required this.idempotencyKey,
    required this.createdAt,
  });

  final int customerId;
  final String idempotencyKey;
  final DateTime createdAt;

  @override
  String toString() =>
      'PendingCheckoutAttempt(customerId: $customerId, createdAt: $createdAt)';
}

abstract interface class PendingCheckoutStore {
  Future<PendingCheckoutAttempt?> read();

  Future<void> write(PendingCheckoutAttempt attempt);

  Future<void> clear();

  /// Clears only when the stored attempt belongs to [customerId].
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

class SecurePendingCheckoutStore implements PendingCheckoutStore {
  SecurePendingCheckoutStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _storageKey = 'indirimgo.pending_checkout.v1';
  static const _version = 1;

  final FlutterSecureStorage _storage;

  @override
  Future<PendingCheckoutAttempt?> read() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw == null || raw.isEmpty) {
        return null;
      }
      return _decode(raw);
    } on FormatException {
      await clear();
      return null;
    } on Object {
      rethrow;
    }
  }

  @override
  Future<void> write(PendingCheckoutAttempt attempt) async {
    final payload = jsonEncode({
      'version': _version,
      'customer_id': attempt.customerId,
      'idempotency_key': attempt.idempotencyKey,
      'created_at': attempt.createdAt.toUtc().toIso8601String(),
    });
    await _storage.write(key: _storageKey, value: payload);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _storageKey);
  }

  @override
  Future<void> clearForCustomer(int customerId) async {
    final current = await read();
    if (current == null) {
      return;
    }
    if (current.customerId == customerId) {
      await clear();
    }
  }

  PendingCheckoutAttempt _decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException(
        'Pending checkout payload must be an object.',
      );
    }
    final map = decoded.map((key, value) => MapEntry('$key', value));
    final version = map['version'];
    if (version != _version) {
      throw const FormatException('Unsupported pending checkout version.');
    }
    final customerId = map['customer_id'];
    final key = map['idempotency_key'];
    final createdAtRaw = map['created_at'];
    if (customerId is! int || customerId < 1) {
      throw const FormatException('Pending checkout customer_id is invalid.');
    }
    if (key is! String || key.isEmpty || key.length > 128) {
      throw const FormatException('Pending checkout key is invalid.');
    }
    if (createdAtRaw is! String) {
      throw const FormatException('Pending checkout created_at is invalid.');
    }
    final createdAt = DateTime.tryParse(createdAtRaw);
    if (createdAt == null) {
      throw const FormatException('Pending checkout created_at is invalid.');
    }
    return PendingCheckoutAttempt(
      customerId: customerId,
      idempotencyKey: key,
      createdAt: createdAt.toUtc(),
    );
  }
}

/// In-memory store for deterministic tests.
class InMemoryPendingCheckoutStore implements PendingCheckoutStore {
  PendingCheckoutAttempt? attempt;
  int writeCount = 0;
  int clearCount = 0;

  @override
  Future<PendingCheckoutAttempt?> read() async => attempt;

  @override
  Future<void> write(PendingCheckoutAttempt value) async {
    attempt = value;
    writeCount += 1;
  }

  @override
  Future<void> clear() async {
    attempt = null;
    clearCount += 1;
  }

  @override
  Future<void> clearForCustomer(int customerId) async {
    if (attempt?.customerId == customerId) {
      await clear();
    }
  }
}
