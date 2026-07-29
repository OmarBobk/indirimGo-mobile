import 'dart:async';

import 'package:indirimgo_mobile/core/errors/api_exception.dart';
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

final sampleSession = AuthSession(
  token: AuthToken(
    accessToken: '7|test-secret',
    tokenType: 'Bearer',
    expiresAt: DateTime.utc(2026, 8, 28),
  ),
  user: sampleUser,
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
    return loginHandler?.call(username, password) ??
        LoginAuthenticated(sampleSession);
  }

  @override
  Future<AuthSession> completeTwoFactorWithAuthenticator({
    required TwoFactorChallenge challenge,
    required String code,
  }) {
    return authenticatorHandler?.call(challenge, code) ??
        Future.value(sampleSession);
  }

  @override
  Future<AuthSession> completeTwoFactorWithRecoveryCode({
    required TwoFactorChallenge challenge,
    required String recoveryCode,
  }) {
    return recoveryHandler?.call(challenge, recoveryCode) ??
        Future.value(sampleSession);
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
  }

  @override
  Future<void> clearSession() async {
    clearCalls += 1;
  }
}

ApiException networkFailure() =>
    const ApiException(kind: ApiErrorKind.network);

Completer<T> pending<T>() => Completer<T>();
