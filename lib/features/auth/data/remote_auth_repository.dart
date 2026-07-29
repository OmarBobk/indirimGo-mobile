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
    required ApiClient apiClient,
    required TokenStorage tokenStorage,
  }) : _apiClient = apiClient,
       _tokenStorage = tokenStorage;

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  @override
  Future<LoginOutcome> login({
    required String username,
    required String password,
  }) async {
    final json = await _apiClient.post(
      'auth/login',
      data: {'username': username, 'password': password},
    );
    final data = _data(json);
    if (data['two_factor_required'] == true) {
      return LoginTwoFactorRequired(TwoFactorChallenge.fromJson(json));
    }

    final session = AuthSession.fromJson(json);
    await _save(session);
    return LoginAuthenticated(session);
  }

  @override
  Future<AuthSession> completeTwoFactorWithAuthenticator({
    required TwoFactorChallenge challenge,
    required String code,
  }) async {
    return _completeTwoFactor(
      challenge: challenge,
      credential: {'code': code},
    );
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
    final json = await _apiClient.post(
      'auth/two-factor-challenge',
      data: {'challenge_token': challenge.token, ...credential},
    );
    final session = AuthSession.fromJson(json);
    await _save(session);
    return session;
  }

  @override
  Future<MobileUser> fetchCurrentUser() async {
    try {
      final json = await _apiClient.get('me');
      return MobileUser.fromJson(_data(json));
    } on ApiException catch (error) {
      if (error.isAuthoritativeSessionRejection) {
        await _tokenStorage.clear();
      }
      rethrow;
    }
  }

  @override
  Future<MobileUser?> restoreSession() async {
    if (await _tokenStorage.read() == null) {
      return null;
    }
    return fetchCurrentUser();
  }

  @override
  Future<void> logout() async {
    try {
      await _apiClient.post('auth/logout');
      await _tokenStorage.clear();
    } on ApiException catch (error) {
      if (error.isAuthoritativeSessionRejection) {
        await _tokenStorage.clear();
      }
      rethrow;
    }
  }

  @override
  Future<void> clearSession() => _tokenStorage.clear();

  Future<void> _save(AuthSession session) {
    return _tokenStorage.write(
      StoredSession(
        token: session.token.accessToken,
        expiresAt: session.token.expiresAt,
      ),
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
