import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  throw StateError('TokenStorage must be provided at the application boundary.');
});

class StoredSession {
  const StoredSession({required this.token, required this.expiresAt});

  final String token;
  final DateTime expiresAt;
}

abstract interface class TokenStorage {
  Future<StoredSession?> read();
  Future<void> write(StoredSession session);
  Future<void> clear();
}

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'auth.sanctum_token';
  static const _expiryKey = 'auth.expires_at';

  final FlutterSecureStorage _storage;

  @override
  Future<StoredSession?> read() async {
    final values = await _storage.readAll();
    final token = values[_tokenKey];
    final expiresAt = DateTime.tryParse(values[_expiryKey] ?? '');

    if (token == null || token.isEmpty || expiresAt == null) {
      if (token != null || values[_expiryKey] != null) {
        await clear();
      }
      return null;
    }

    return StoredSession(token: token, expiresAt: expiresAt.toUtc());
  }

  @override
  Future<void> write(StoredSession session) async {
    await _storage.write(key: _tokenKey, value: session.token);
    await _storage.write(
      key: _expiryKey,
      value: session.expiresAt.toUtc().toIso8601String(),
    );
  }

  @override
  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _tokenKey),
      _storage.delete(key: _expiryKey),
    ]);
  }
}

class InMemoryTokenStorage implements TokenStorage {
  InMemoryTokenStorage([this.session]);

  StoredSession? session;
  int clearCount = 0;

  @override
  Future<void> clear() async {
    clearCount += 1;
    session = null;
  }

  @override
  Future<StoredSession?> read() async => session;

  @override
  Future<void> write(StoredSession value) async {
    session = value;
  }
}
