import 'package:flutter_test/flutter_test.dart';
import 'package:indirimgo_mobile/core/storage/pending_topup_store.dart';

void main() {
  test(
    'per-customer records isolate A and B and refuse key overwrite',
    () async {
      final store = InMemoryPendingTopupStore();
      await store.writeUnresolved(
        customerId: 7,
        idempotencyKey: 'ig-secret-a',
        createdAt: DateTime.utc(2026, 9, 1, 12),
      );
      await store.writeUnresolved(
        customerId: 8,
        idempotencyKey: 'ig-secret-b',
        createdAt: DateTime.utc(2026, 9, 1, 13),
      );

      expect((await store.readForCustomer(7))?.idempotencyKey, 'ig-secret-a');
      expect((await store.readForCustomer(8))?.idempotencyKey, 'ig-secret-b');
      expect(
        (await store.readForCustomer(7)).toString(),
        isNot(contains('ig-secret-a')),
      );

      await store.writeUnresolved(
        customerId: 7,
        idempotencyKey: 'ig-second',
        createdAt: DateTime.utc(2026, 9, 1, 14),
      );
      expect((await store.readForCustomer(7))?.idempotencyKey, 'ig-secret-a');

      await store.clearForCustomer(7);
      expect(await store.readForCustomer(7), isNull);
      expect((await store.readForCustomer(8))?.idempotencyKey, 'ig-secret-b');
    },
  );
}
