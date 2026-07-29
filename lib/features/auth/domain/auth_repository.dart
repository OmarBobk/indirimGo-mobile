import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:indirimgo_mobile/features/auth/domain/auth_models.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  throw StateError('AuthRepository must be provided.');
});

abstract interface class AuthRepository {
  Future<LoginOutcome> login({
    required String username,
    required String password,
  });

  Future<AuthSession> completeTwoFactorWithAuthenticator({
    required TwoFactorChallenge challenge,
    required String code,
  });

  Future<AuthSession> completeTwoFactorWithRecoveryCode({
    required TwoFactorChallenge challenge,
    required String recoveryCode,
  });

  Future<MobileUser> fetchCurrentUser();
  Future<MobileUser?> restoreSession();
  Future<void> logout();
  Future<void> clearSession();
}
