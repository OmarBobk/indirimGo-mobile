import 'package:flutter_test/flutter_test.dart';
import 'package:indirimgo_mobile/core/storage/pending_checkout_store.dart';

void main() {
  test('generateIdempotencyKey stays within OpenAPI bounds', () {
    final key = generateIdempotencyKey();
    expect(key.length, greaterThanOrEqualTo(1));
    expect(key.length, lessThanOrEqualTo(128));
    expect(key.startsWith('ig-'), isTrue);
  });

  test('in-memory store round-trips minimal metadata only', () async {
    final store = InMemoryPendingCheckoutStore();
    final attempt = PendingCheckoutAttempt(
      customerId: 7,
      idempotencyKey: 'ig-secret-key',
      createdAt: DateTime.utc(2026, 8, 1, 12),
    );
    await store.write(attempt);
    final read = await store.read();
    expect(read?.customerId, 7);
    expect(read?.idempotencyKey, 'ig-secret-key');
    expect(read.toString(), isNot(contains('ig-secret-key')));

    await store.clearForCustomer(8);
    expect(await store.read(), isNotNull);
    await store.clearForCustomer(7);
    expect(await store.read(), isNull);
  });
}
