import 'package:flutter_test/flutter_test.dart';
import 'package:indirimgo_mobile/core/storage/pending_checkout_store.dart';

void main() {
  test('generateIdempotencyKey stays within OpenAPI bounds', () {
    final key = generateIdempotencyKey();
    expect(key.length, greaterThanOrEqualTo(1));
    expect(key.length, lessThanOrEqualTo(128));
    expect(key.startsWith('ig-'), isTrue);
  });

  test('per-customer records isolate A and B recovery metadata', () async {
    final store = InMemoryPendingCheckoutStore();
    await store.writeUnresolved(
      customerId: 7,
      idempotencyKey: 'ig-secret-a',
      createdAt: DateTime.utc(2026, 8, 1, 12),
    );
    await store.writeUnresolved(
      customerId: 8,
      idempotencyKey: 'ig-secret-b',
      createdAt: DateTime.utc(2026, 8, 1, 13),
    );

    final a = await store.readForCustomer(7);
    final b = await store.readForCustomer(8);
    expect(a?.idempotencyKey, 'ig-secret-a');
    expect(b?.idempotencyKey, 'ig-secret-b');

    await store.markCompleted(customerId: 7, orderNumber: 'ORD-2026-000001');
    final aCompleted = await store.readForCustomer(7);
    expect(aCompleted?.hasUnresolvedKey, isTrue);
    expect(aCompleted?.completedOrderNumber, 'ORD-2026-000001');
    expect(aCompleted.toString(), isNot(contains('ig-secret-a')));
    expect(aCompleted.toString(), isNot(contains('ORD-2026-000001')));

    await store.clearPendingKey(7);
    final aAnchored = await store.readForCustomer(7);
    expect(aAnchored?.hasUnresolvedKey, isFalse);
    expect(aAnchored?.completedOrderNumber, 'ORD-2026-000001');

    // Clearing A must not touch B.
    await store.clearForCustomer(7);
    expect(await store.readForCustomer(7), isNull);
    expect((await store.readForCustomer(8))?.idempotencyKey, 'ig-secret-b');
  });

  test('refuses to overwrite a different unresolved key', () async {
    final store = InMemoryPendingCheckoutStore();
    await store.writeUnresolved(
      customerId: 7,
      idempotencyKey: 'ig-first',
      createdAt: DateTime.utc(2026, 8, 1),
    );
    await store.writeUnresolved(
      customerId: 7,
      idempotencyKey: 'ig-second',
      createdAt: DateTime.utc(2026, 8, 1, 1),
    );
    expect((await store.readForCustomer(7))?.idempotencyKey, 'ig-first');
  });
}
