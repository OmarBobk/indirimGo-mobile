import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  throw StateError(
    'TokenStorage must be provided at the application boundary.',
  );
});

final class SessionReference {
  const SessionReference._(this._token);

  final String _token;

  @override
  String toString() => 'SessionReference';
}

class StoredSession {
  StoredSession({required this.token, required this.expiresAt})
    : reference = SessionReference._(token);

  final String token;
  final DateTime expiresAt;
  final SessionReference reference;
}

abstract interface class TokenStorage {
  Future<StoredSession?> read();
  Future<void> write(StoredSession session);
  Future<void> clear();
  Future<bool> clearIfCurrent(SessionReference reference);
}

enum TokenStorageOperation { read, write, delete }

final class TokenStorageException implements Exception {
  const TokenStorageException(this.operation);

  final TokenStorageOperation operation;

  @override
  String toString() => 'TokenStorageException(operation: ${operation.name})';
}

abstract interface class SecureValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

final class FlutterSecureValueStore implements SecureValueStore {
  FlutterSecureValueStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({SecureValueStore? storage})
    : _storage = storage ?? FlutterSecureValueStore();

  static const _sessionKey = 'auth.session';
  static const _version = 1;

  final SecureValueStore _storage;
  Future<void> _mutationQueue = Future<void>.value();

  @override
  Future<StoredSession?> read() => _serialized(_read);

  @override
  Future<void> write(StoredSession session) => _serialized(() async {
    final serialized = jsonEncode({
      'version': _version,
      'access_token': session.token,
      'expires_at': session.expiresAt.toUtc().toIso8601String(),
    });
    await _writeValue(serialized);
  });

  @override
  Future<void> clear() => _serialized(_deleteValue);

  @override
  Future<bool> clearIfCurrent(SessionReference reference) =>
      _serialized(() async {
        final current = await _read();
        if (current == null || current.token != reference._token) {
          return false;
        }
        await _deleteValue();
        return true;
      });

  Future<StoredSession?> _read() async {
    final serialized = await _readValue();
    if (serialized == null) {
      return null;
    }

    final session = _decode(serialized);
    if (session != null) {
      return session;
    }

    await _deleteValue();
    return null;
  }

  StoredSession? _decode(String serialized) {
    try {
      final decoded = jsonDecode(serialized);
      if (decoded is! Map) {
        return null;
      }
      final map = Map<String, Object?>.from(decoded);
      if (map['version'] != _version ||
          map['access_token'] is! String ||
          map['expires_at'] is! String) {
        return null;
      }
      final token = map['access_token']! as String;
      final expiresAt = DateTime.tryParse(map['expires_at']! as String);
      if (token.isEmpty || expiresAt == null) {
        return null;
      }
      return StoredSession(token: token, expiresAt: expiresAt.toUtc());
    } on FormatException {
      return null;
    }
  }

  Future<String?> _readValue() async {
    try {
      return await _storage.read(_sessionKey);
    } on Object {
      throw const TokenStorageException(TokenStorageOperation.read);
    }
  }

  Future<void> _writeValue(String value) async {
    try {
      await _storage.write(_sessionKey, value);
    } on Object {
      throw const TokenStorageException(TokenStorageOperation.write);
    }
  }

  Future<void> _deleteValue() async {
    try {
      await _storage.delete(_sessionKey);
    } on Object {
      throw const TokenStorageException(TokenStorageOperation.delete);
    }
  }

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _mutationQueue = _mutationQueue.then((_) async {
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}

class InMemoryTokenStorage implements TokenStorage {
  InMemoryTokenStorage([this.session]);

  StoredSession? session;
  int clearCount = 0;
  Future<void> _mutationQueue = Future<void>.value();

  @override
  Future<void> clear() => _serialized(() async {
    clearCount += 1;
    session = null;
  });

  @override
  Future<bool> clearIfCurrent(SessionReference reference) =>
      _serialized(() async {
        if (session?.token != reference._token) {
          return false;
        }
        clearCount += 1;
        session = null;
        return true;
      });

  @override
  Future<StoredSession?> read() => _serialized(() async => session);

  @override
  Future<void> write(StoredSession value) => _serialized(() async {
    session = value;
  });

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _mutationQueue = _mutationQueue.then((_) async {
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}
