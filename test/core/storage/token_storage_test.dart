import 'package:flutter_test/flutter_test.dart';
import 'package:indirimgo_mobile/core/storage/token_storage.dart';

void main() {
  test(
    'in-memory storage deterministically writes reads and clears a session',
    () async {
      final storage = InMemoryTokenStorage();
      final session = StoredSession(
        token: 'token-value',
        expiresAt: DateTime.utc(2026, 8, 28),
      );

      expect(await storage.read(), isNull);

      await storage.write(session);
      expect((await storage.read())?.token, 'token-value');
      expect((await storage.read())?.expiresAt, DateTime.utc(2026, 8, 28));

      await storage.clear();
      expect(await storage.read(), isNull);
      expect(storage.clearCount, 1);
    },
  );
}
