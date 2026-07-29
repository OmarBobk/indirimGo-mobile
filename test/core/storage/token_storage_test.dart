import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:indirimgo_mobile/core/storage/token_storage.dart';

void main() {
  late FakeSecureValueStore values;
  late SecureTokenStorage storage;

  setUp(() {
    values = FakeSecureValueStore();
    storage = SecureTokenStorage(storage: values);
  });

  test('secure storage round trips one versioned session value', () async {
    final session = _session('token-value');

    await storage.write(session);
    final restored = await storage.read();

    expect(values.keys.toSet(), {'auth.session'});
    expect(values.value, contains('"version":1'));
    expect(values.value, contains('"access_token":"token-value"'));
    expect(restored?.token, session.token);
    expect(restored?.expiresAt, session.expiresAt);
  });

  test('malformed and incomplete sessions are deleted safely', () async {
    for (final malformed in [
      'not-json',
      '{"version":1}',
      '{"version":2,"access_token":"old","expires_at":"2026-08-28T00:00:00Z"}',
      '{"version":1,"access_token":"","expires_at":"invalid"}',
    ]) {
      values.value = malformed;
      expect(await storage.read(), isNull);
      expect(values.value, isNull);
    }
  });

  test('write and clear mutations execute in call order', () async {
    final gate = Completer<void>();
    values.writeGate = gate;

    final write = storage.write(_session('ordered-token'));
    await values.writeStarted.future;
    final clear = storage.clear();
    await Future<void>.delayed(Duration.zero);
    expect(values.events, ['write-start']);

    gate.complete();
    await Future.wait([write, clear]);

    expect(values.events, ['write-start', 'write-end', 'delete']);
    expect(await storage.read(), isNull);
  });

  test('compare-and-clear removes only the matching session', () async {
    final oldSession = _session('old-token');
    final currentSession = _session('current-token');
    await storage.write(oldSession);
    await storage.write(currentSession);

    expect(await storage.clearIfCurrent(oldSession.reference), isFalse);
    expect((await storage.read())?.token, currentSession.token);
    expect(await storage.clearIfCurrent(currentSession.reference), isTrue);
    expect(await storage.read(), isNull);
  });

  test(
    'read write and delete failures are sanitized and recoverable',
    () async {
      const sensitive = 'sensitive-storage-value';

      values.failRead = true;
      await _expectSanitized(
        storage.read(),
        TokenStorageOperation.read,
        sensitive,
      );
      values.failRead = false;

      values.failWrite = true;
      await _expectSanitized(
        storage.write(_session(sensitive)),
        TokenStorageOperation.write,
        sensitive,
      );
      values.failWrite = false;

      await storage.write(_session('safe-token'));
      values.failDelete = true;
      await _expectSanitized(
        storage.clear(),
        TokenStorageOperation.delete,
        sensitive,
      );
      values.failDelete = false;

      await storage.clear();
      await storage.write(_session('queue-recovered'));
      expect((await storage.read())?.token, 'queue-recovered');
    },
  );
}

StoredSession _session(String token) =>
    StoredSession(token: token, expiresAt: DateTime.utc(2026, 8, 28));

Future<void> _expectSanitized<T>(
  Future<T> operation,
  TokenStorageOperation expectedOperation,
  String sensitive,
) async {
  try {
    await operation;
    fail('Expected secure storage operation to fail');
  } on TokenStorageException catch (error) {
    expect(error.operation, expectedOperation);
    expect(error.toString(), isNot(contains(sensitive)));
  }
}

final class FakeSecureValueStore implements SecureValueStore {
  String? value;
  bool failRead = false;
  bool failWrite = false;
  bool failDelete = false;
  Completer<void>? writeGate;
  final writeStarted = Completer<void>();
  final List<String> keys = [];
  final List<String> events = [];

  @override
  Future<void> delete(String key) async {
    keys.add(key);
    events.add('delete');
    if (failDelete) {
      throw StateError('sensitive-storage-value');
    }
    value = null;
  }

  @override
  Future<String?> read(String key) async {
    keys.add(key);
    if (failRead) {
      throw StateError('sensitive-storage-value');
    }
    return value;
  }

  @override
  Future<void> write(String key, String newValue) async {
    keys.add(key);
    events.add('write-start');
    if (!writeStarted.isCompleted) {
      writeStarted.complete();
    }
    await writeGate?.future;
    if (failWrite) {
      throw StateError('sensitive-storage-value');
    }
    value = newValue;
    events.add('write-end');
  }
}
