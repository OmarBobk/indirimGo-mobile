import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:indirimgo_mobile/core/errors/api_exception.dart';
import 'package:indirimgo_mobile/features/auth/domain/auth_models.dart';
import 'package:indirimgo_mobile/features/auth/domain/auth_repository.dart';

enum AuthPhase {
  initializing,
  unauthenticated,
  submittingLogin,
  twoFactorRequired,
  authenticated,
  verificationFailed,
  loggingOut,
}

class AuthState {
  const AuthState({
    required this.phase,
    this.user,
    this.challenge,
    this.error,
    this.fieldErrors = const {},
    this.challengeExpired = false,
  });

  const AuthState.initializing() : this(phase: AuthPhase.initializing);

  final AuthPhase phase;
  final MobileUser? user;
  final TwoFactorChallenge? challenge;
  final ApiException? error;
  final Map<String, List<String>> fieldErrors;
  final bool challengeExpired;

  bool get isBusy =>
      phase == AuthPhase.submittingLogin || phase == AuthPhase.loggingOut;
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    scheduleMicrotask(restoreSession);
    return const AuthState.initializing();
  }

  Future<void> restoreSession() async {
    state = const AuthState.initializing();
    try {
      final user = await _repository.restoreSession();
      state = user == null
          ? const AuthState(phase: AuthPhase.unauthenticated)
          : AuthState(phase: AuthPhase.authenticated, user: user);
    } on ApiException catch (error) {
      if (error.isAuthoritativeSessionRejection) {
        state = AuthState(phase: AuthPhase.unauthenticated, error: error);
      } else {
        state = AuthState(phase: AuthPhase.verificationFailed, error: error);
      }
    } on Object {
      state = const AuthState(phase: AuthPhase.verificationFailed);
    }
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    if (state.phase == AuthPhase.submittingLogin) {
      return;
    }
    state = const AuthState(phase: AuthPhase.submittingLogin);
    try {
      final result = await _repository.login(
        username: username.trim(),
        password: password,
      );
      state = switch (result) {
        LoginAuthenticated(:final session) => AuthState(
          phase: AuthPhase.authenticated,
          user: session.user,
        ),
        LoginTwoFactorRequired(:final challenge) => AuthState(
          phase: AuthPhase.twoFactorRequired,
          challenge: challenge,
        ),
      };
    } on ApiException catch (error) {
      state = AuthState(
        phase: AuthPhase.unauthenticated,
        error: error,
        fieldErrors: error.fieldErrors,
      );
    } on Object {
      state = const AuthState(phase: AuthPhase.unauthenticated);
    }
  }

  Future<void> completeTwoFactorWithAuthenticator(String code) async {
    final challenge = state.challenge;
    if (challenge == null || state.isBusy) {
      return;
    }
    await _completeTwoFactor(
      challenge,
      () => _repository.completeTwoFactorWithAuthenticator(
        challenge: challenge,
        code: code,
      ),
    );
  }

  Future<void> completeTwoFactorWithRecoveryCode(String recoveryCode) async {
    final challenge = state.challenge;
    if (challenge == null || state.isBusy) {
      return;
    }
    await _completeTwoFactor(
      challenge,
      () => _repository.completeTwoFactorWithRecoveryCode(
        challenge: challenge,
        recoveryCode: recoveryCode,
      ),
    );
  }

  Future<void> _completeTwoFactor(
    TwoFactorChallenge challenge,
    Future<AuthSession> Function() submit,
  ) async {
    if (challenge.isExpired) {
      state = AuthState(
        phase: AuthPhase.twoFactorRequired,
        challenge: challenge,
        challengeExpired: true,
      );
      return;
    }

    state = AuthState(
      phase: AuthPhase.submittingLogin,
      challenge: challenge,
    );
    try {
      final session = await submit();
      state = AuthState(
        phase: AuthPhase.authenticated,
        user: session.user,
      );
    } on ApiException catch (error) {
      final expired = const {
        'invalid_two_factor_challenge',
        'two_factor_attempts_exceeded',
      }.contains(error.code);
      state = AuthState(
        phase: AuthPhase.twoFactorRequired,
        challenge: challenge,
        error: error,
        fieldErrors: error.fieldErrors,
        challengeExpired: expired,
      );
    } on Object {
      state = AuthState(
        phase: AuthPhase.twoFactorRequired,
        challenge: challenge,
      );
    }
  }

  void returnToLogin() {
    state = const AuthState(phase: AuthPhase.unauthenticated);
  }

  Future<void> logout() async {
    final user = state.user;
    if (user == null || state.phase == AuthPhase.loggingOut) {
      return;
    }
    state = AuthState(phase: AuthPhase.loggingOut, user: user);
    try {
      await _repository.logout();
      state = const AuthState(phase: AuthPhase.unauthenticated);
    } on ApiException catch (error) {
      if (error.isAuthoritativeSessionRejection) {
        state = AuthState(phase: AuthPhase.unauthenticated, error: error);
      } else {
        state = AuthState(
          phase: AuthPhase.authenticated,
          user: user,
          error: error,
        );
      }
    } on Object {
      state = AuthState(phase: AuthPhase.authenticated, user: user);
    }
  }
}
