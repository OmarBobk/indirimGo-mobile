import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:indirimgo_mobile/core/errors/api_exception.dart';
import 'package:indirimgo_mobile/core/storage/token_storage.dart';
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

enum TwoFactorTerminalReason { invalidOrExpired, attemptsExceeded }

enum SessionRestorationFailure { network, server, storage, unexpected }

class AuthState {
  const AuthState({
    required this.phase,
    this.user,
    this.challenge,
    this.error,
    this.fieldErrors = const {},
    this.twoFactorTerminalReason,
    this.restorationFailure,
  });

  const AuthState.initializing() : this(phase: AuthPhase.initializing);

  final AuthPhase phase;
  final MobileUser? user;
  final TwoFactorChallenge? challenge;
  final ApiException? error;
  final Map<String, List<String>> fieldErrors;
  final TwoFactorTerminalReason? twoFactorTerminalReason;
  final SessionRestorationFailure? restorationFailure;

  bool get isBusy =>
      phase == AuthPhase.submittingLogin || phase == AuthPhase.loggingOut;
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  int _operationEpoch = 0;
  bool _disposed = false;

  @override
  AuthState build() {
    ref.onDispose(() {
      _disposed = true;
      _operationEpoch += 1;
    });
    scheduleMicrotask(() {
      if (!_disposed) {
        restoreSession();
      }
    });
    return const AuthState.initializing();
  }

  Future<void> restoreSession() async {
    final operation = _beginOperation();
    _commit(operation, const AuthState.initializing());
    try {
      final user = await _repository.restoreSession();
      _commit(
        operation,
        user == null
            ? const AuthState(phase: AuthPhase.unauthenticated)
            : AuthState(phase: AuthPhase.authenticated, user: user),
      );
    } on ApiException catch (error) {
      if (error.isAuthoritativeSessionRejection) {
        _commit(
          operation,
          AuthState(phase: AuthPhase.unauthenticated, error: error),
        );
      } else {
        _commit(
          operation,
          AuthState(
            phase: AuthPhase.verificationFailed,
            error: error,
            restorationFailure: switch (error.kind) {
              ApiErrorKind.network => SessionRestorationFailure.network,
              ApiErrorKind.server => SessionRestorationFailure.server,
              _ => SessionRestorationFailure.unexpected,
            },
          ),
        );
      }
    } on TokenStorageException {
      _commit(
        operation,
        const AuthState(
          phase: AuthPhase.verificationFailed,
          restorationFailure: SessionRestorationFailure.storage,
        ),
      );
    } on Object {
      _commit(
        operation,
        const AuthState(
          phase: AuthPhase.verificationFailed,
          restorationFailure: SessionRestorationFailure.unexpected,
        ),
      );
    }
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    if (state.phase != AuthPhase.unauthenticated) {
      return;
    }
    final operation = _beginOperation();
    _commit(operation, const AuthState(phase: AuthPhase.submittingLogin));
    try {
      final result = await _repository.login(
        username: username.trim(),
        password: password,
      );
      _commit(operation, switch (result) {
        LoginAuthenticated(:final session) => AuthState(
          phase: AuthPhase.authenticated,
          user: session.user,
        ),
        LoginTwoFactorRequired(:final challenge) => AuthState(
          phase: AuthPhase.twoFactorRequired,
          challenge: challenge,
        ),
      });
    } on ApiException catch (error) {
      _commit(
        operation,
        AuthState(
          phase: AuthPhase.unauthenticated,
          error: error,
          fieldErrors: error.fieldErrors,
        ),
      );
    } on Object {
      _commit(operation, const AuthState(phase: AuthPhase.unauthenticated));
    }
  }

  Future<void> completeTwoFactorWithAuthenticator(String code) async {
    final challenge = state.challenge;
    if (challenge == null || state.phase != AuthPhase.twoFactorRequired) {
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
    if (challenge == null || state.phase != AuthPhase.twoFactorRequired) {
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
    final operation = _beginOperation();
    _commit(
      operation,
      AuthState(phase: AuthPhase.submittingLogin, challenge: challenge),
    );
    try {
      final session = await submit();
      _commit(
        operation,
        AuthState(phase: AuthPhase.authenticated, user: session.user),
      );
    } on ApiException catch (error) {
      final terminalReason = switch (error.code) {
        'invalid_two_factor_challenge' =>
          TwoFactorTerminalReason.invalidOrExpired,
        'two_factor_attempts_exceeded' =>
          TwoFactorTerminalReason.attemptsExceeded,
        _ => null,
      };
      _commit(
        operation,
        AuthState(
          phase: AuthPhase.twoFactorRequired,
          challenge: challenge,
          error: error,
          fieldErrors: error.fieldErrors,
          twoFactorTerminalReason: terminalReason,
        ),
      );
    } on Object {
      _commit(
        operation,
        AuthState(phase: AuthPhase.twoFactorRequired, challenge: challenge),
      );
    }
  }

  void clearTwoFactorError() {
    final current = state;
    if (current.phase != AuthPhase.twoFactorRequired ||
        current.challenge == null ||
        current.twoFactorTerminalReason != null) {
      return;
    }
    state = AuthState(
      phase: AuthPhase.twoFactorRequired,
      challenge: current.challenge,
    );
  }

  void returnToLogin() {
    _operationEpoch += 1;
    state = const AuthState(phase: AuthPhase.unauthenticated);
  }

  Future<void> logout() async {
    final user = state.user;
    if (user == null || state.phase == AuthPhase.loggingOut) {
      return;
    }
    final operation = _beginOperation();
    _commit(operation, AuthState(phase: AuthPhase.loggingOut, user: user));
    try {
      await _repository.logout();
      _commit(operation, const AuthState(phase: AuthPhase.unauthenticated));
    } on ApiException catch (error) {
      if (error.isAuthoritativeSessionRejection) {
        _commit(
          operation,
          AuthState(phase: AuthPhase.unauthenticated, error: error),
        );
      } else {
        _commit(
          operation,
          AuthState(phase: AuthPhase.authenticated, user: user, error: error),
        );
      }
    } on Object {
      _commit(operation, AuthState(phase: AuthPhase.authenticated, user: user));
    }
  }

  int _beginOperation() => ++_operationEpoch;

  void _commit(int operation, AuthState next) {
    if (!_disposed && operation == _operationEpoch) {
      state = next;
    }
  }
}
