import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:indirimgo_mobile/core/errors/api_exception.dart';
import 'package:indirimgo_mobile/core/network/api_client.dart';
import 'package:indirimgo_mobile/core/storage/token_storage.dart';
import 'package:indirimgo_mobile/features/auth/domain/auth_models.dart';
import 'package:indirimgo_mobile/features/auth/domain/auth_repository.dart';

final remoteAuthRepositoryProvider = Provider<AuthRepository>((ref) {
  return RemoteAuthRepository(
    apiClient: ref.watch(apiClientProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});

class RemoteAuthRepository implements AuthRepository {
  const RemoteAuthRepository({
    required this.apiClient,
    required this.tokenStorage,
  });

  final ApiClient apiClient;
  final TokenStorage tokenStorage;

  @override
  Future<LoginOutcome> login({
    required String username,
    required String password,
  }) async {
    final response = await apiClient.post(
      'auth/login',
      data: {'username': username, 'password': password},
    );
    if (response.statusCode == 200) {
      return _authenticatedLogin(response.data);
    }
    if (response.statusCode == 202) {
      return LoginTwoFactorRequired(TwoFactorChallenge.fromJson(response.data));
    }
    throw const FormatException(
      'The login response used an unsupported status.',
    );
  }

  @override
  Future<AuthSession> completeTwoFactorWithAuthenticator({
    required TwoFactorChallenge challenge,
    required String code,
  }) async {
    return _completeTwoFactor(challenge: challenge, credential: {'code': code});
  }

  @override
  Future<AuthSession> completeTwoFactorWithRecoveryCode({
    required TwoFactorChallenge challenge,
    required String recoveryCode,
  }) async {
    return _completeTwoFactor(
      challenge: challenge,
      credential: {'recovery_code': recoveryCode},
    );
  }

  Future<AuthSession> _completeTwoFactor({
    required TwoFactorChallenge challenge,
    required Map<String, Object?> credential,
  }) async {
    final response = await apiClient.post(
      'auth/two-factor-challenge',
      data: {'challenge_token': challenge.token, ...credential},
    );
    _requireStatus(response, 200, 'two-factor');
    final session = AuthSession.fromJson(response.data);
    await _save(session);
    return session;
  }

  @override
  Future<MobileUser> fetchCurrentUser() async {
    try {
      final response = await apiClient.get('me');
      _requireStatus(response, 200, 'current-user');
      return MobileUser.fromJson(_data(response.data));
    } on ApiException catch (error) {
      if (error.isAuthoritativeSessionRejection) {
        await _clearRejectedSession(error);
      }
      rethrow;
    }
  }

  @override
  Future<MobileUser?> restoreSession() async {
    if (await tokenStorage.read() == null) {
      return null;
    }
    return fetchCurrentUser();
  }

  @override
  Future<void> logout() async {
    try {
      final response = await apiClient.post('auth/logout');
      _requireStatus(response, 200, 'logout');
      if (response.requestSession case final session?) {
        await tokenStorage.clearIfCurrent(session);
      }
    } on ApiException catch (error) {
      if (error.isAuthoritativeSessionRejection) {
        await _clearRejectedSession(error);
      }
      rethrow;
    }
  }

  @override
  Future<void> clearSession() => tokenStorage.clear();

  Future<void> _save(AuthSession session) {
    return tokenStorage.write(
      StoredSession(
        token: session.token.accessToken,
        expiresAt: session.token.expiresAt,
      ),
    );
  }

  Future<LoginOutcome> _authenticatedLogin(Map<String, Object?> json) async {
    final session = AuthSession.fromJson(json);
    await _save(session);
    return LoginAuthenticated(session);
  }

  Future<void> _clearRejectedSession(ApiException error) async {
    final requestSession = error.requestSession;
    if (requestSession == null) {
      return;
    }
    try {
      await tokenStorage.clearIfCurrent(requestSession);
    } on Object {
      // Preserve the authoritative API error when secure storage is unavailable.
    }
  }
}

void _requireStatus(ApiResponse response, int expected, String operation) {
  if (response.statusCode != expected) {
    throw FormatException(
      'The $operation response used an unsupported status.',
    );
  }
}

Map<String, Object?> _data(Map<String, Object?> json) {
  final value = json['data'];
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  throw const FormatException('The response data field must be an object.');
}
