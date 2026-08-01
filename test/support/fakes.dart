import 'dart:async';

import 'package:indirimgo_mobile/core/errors/api_exception.dart';
import 'package:indirimgo_mobile/core/storage/token_storage.dart';
import 'package:indirimgo_mobile/features/auth/domain/auth_models.dart';
import 'package:indirimgo_mobile/features/auth/domain/auth_repository.dart';

final sampleUser = MobileUser(
  id: 7,
  name: 'Omar Customer',
  username: 'omar',
  email: 'omar@example.com',
  phone: null,
  countryCode: null,
  locale: 'ar',
  preferredCurrency: 'USD',
  timezone: null,
  profilePhotoUrl: null,
  emailVerifiedAt: null,
);

final sampleUserB = MobileUser(
  id: 8,
  name: 'Other Customer',
  username: 'other',
  email: 'other@example.com',
  phone: null,
  countryCode: null,
  locale: 'en',
  preferredCurrency: 'USD',
  timezone: null,
  profilePhotoUrl: null,
  emailVerifiedAt: null,
);

final sampleSession = AuthSession(
  token: AuthToken(
    accessToken: '7|test-secret',
    tokenType: 'Bearer',
    expiresAt: DateTime.utc(2026, 8, 28),
  ),
  user: sampleUser,
);

final sampleSessionB = AuthSession(
  token: AuthToken(
    accessToken: '8|test-secret-b',
    tokenType: 'Bearer',
    expiresAt: DateTime.utc(2026, 8, 28),
  ),
  user: sampleUserB,
);

StoredSession sampleStoredSession() => StoredSession(
  token: sampleSession.token.accessToken,
  expiresAt: sampleSession.token.expiresAt,
);

final sampleChallenge = TwoFactorChallenge(
  token: 'challenge-token-kept-only-in-memory-1234567890123',
  expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
);

typedef LoginHandler =
    Future<LoginOutcome> Function(String username, String password);
typedef AuthenticatorHandler =
    Future<AuthSession> Function(TwoFactorChallenge challenge, String code);
typedef RecoveryHandler =
    Future<AuthSession> Function(
      TwoFactorChallenge challenge,
      String recoveryCode,
    );

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.tokenStorage});

  final TokenStorage? tokenStorage;

  MobileUser? restoreResult;
  Object? restoreError;
  Future<MobileUser?> Function()? restoreHandler;
  LoginHandler? loginHandler;
  AuthenticatorHandler? authenticatorHandler;
  RecoveryHandler? recoveryHandler;
  Future<void> Function()? logoutHandler;

  int loginCalls = 0;
  int restoreCalls = 0;
  int logoutCalls = 0;
  int clearCalls = 0;
  int authenticatorCalls = 0;
  int recoveryCalls = 0;
  String? lastUsername;
  String? lastPassword;

  @override
  Future<LoginOutcome> login({
    required String username,
    required String password,
  }) async {
    loginCalls += 1;
    lastUsername = username;
    lastPassword = password;
    final outcome =
        await (loginHandler?.call(username, password) ??
            Future.value(LoginAuthenticated(sampleSession)));
    if (outcome case LoginAuthenticated(:final session)) {
      await _persist(session);
    }
    return outcome;
  }

  @override
  Future<AuthSession> completeTwoFactorWithAuthenticator({
    required TwoFactorChallenge challenge,
    required String code,
  }) async {
    authenticatorCalls += 1;
    final session =
        await (authenticatorHandler?.call(challenge, code) ??
            Future.value(sampleSession));
    await _persist(session);
    return session;
  }

  @override
  Future<AuthSession> completeTwoFactorWithRecoveryCode({
    required TwoFactorChallenge challenge,
    required String recoveryCode,
  }) async {
    recoveryCalls += 1;
    final session =
        await (recoveryHandler?.call(challenge, recoveryCode) ??
            Future.value(sampleSession));
    await _persist(session);
    return session;
  }

  @override
  Future<MobileUser> fetchCurrentUser() async {
    if (restoreError case final error?) {
      throw error;
    }
    return restoreResult ?? sampleUser;
  }

  @override
  Future<MobileUser?> restoreSession() async {
    restoreCalls += 1;
    if (restoreHandler != null) {
      return restoreHandler!();
    }
    if (restoreError case final error?) {
      throw error;
    }
    return restoreResult;
  }

  @override
  Future<void> logout() async {
    logoutCalls += 1;
    await logoutHandler?.call();
    await tokenStorage?.clear();
  }

  @override
  Future<void> clearSession() async {
    clearCalls += 1;
    await tokenStorage?.clear();
  }

  Future<void> _persist(AuthSession session) async {
    final storage = tokenStorage;
    if (storage == null) {
      return;
    }
    await storage.write(
      StoredSession(
        token: session.token.accessToken,
        expiresAt: session.token.expiresAt,
      ),
    );
  }
}

ApiException networkFailure() => const ApiException(kind: ApiErrorKind.network);

ApiException serverFailure() =>
    const ApiException(kind: ApiErrorKind.server, statusCode: 503);

ApiException unauthorizedRejection(SessionReference session) => ApiException(
  kind: ApiErrorKind.unauthorized,
  code: 'unauthenticated',
  statusCode: 401,
  requestSession: session,
);

ApiException forbiddenRejection(String code, SessionReference session) =>
    ApiException(
      kind: ApiErrorKind.forbidden,
      code: code,
      statusCode: 403,
      requestSession: session,
    );

Completer<T> pending<T>() => Completer<T>();
