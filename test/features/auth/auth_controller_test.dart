import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indirimgo_mobile/core/errors/api_exception.dart';
import 'package:indirimgo_mobile/core/storage/token_storage.dart';
import 'package:indirimgo_mobile/features/auth/domain/auth_models.dart';
import 'package:indirimgo_mobile/features/auth/domain/auth_repository.dart';
import 'package:indirimgo_mobile/features/auth/presentation/auth_controller.dart';

import '../../support/fakes.dart';

void main() {
  test('restores an existing session without exposing login state', () async {
    final repository = FakeAuthRepository()..restoreResult = sampleUser;
    final container = _container(repository);

    expect(
      container.read(authControllerProvider).phase,
      AuthPhase.initializing,
    );
    await _settle();

    expect(
      container.read(authControllerProvider).phase,
      AuthPhase.authenticated,
    );
    expect(container.read(authControllerProvider).user, sampleUser);
    container.dispose();
  });

  test('an authoritative 401 becomes unauthenticated', () async {
    final repository = FakeAuthRepository()
      ..restoreError = const ApiException(
        kind: ApiErrorKind.unauthorized,
        code: 'unauthenticated',
      );
    final container = _container(repository);
    container.read(authControllerProvider);
    await _settle();

    expect(
      container.read(authControllerProvider).phase,
      AuthPhase.unauthenticated,
    );
    container.dispose();
  });

  test('offline restore keeps a retryable verification state', () async {
    final repository = FakeAuthRepository()..restoreError = networkFailure();
    final container = _container(repository);
    container.read(authControllerProvider);
    await _settle();

    expect(
      container.read(authControllerProvider).phase,
      AuthPhase.verificationFailed,
    );
    expect(repository.clearCalls, 0);
    container.dispose();
  });

  test(
    'login transitions through the two-factor challenge and authenticates',
    () async {
      final repository = FakeAuthRepository()
        ..loginHandler = (_, _) async =>
            LoginTwoFactorRequired(sampleChallenge);
      final container = _container(repository);
      container.read(authControllerProvider);
      await _settle();

      await container
          .read(authControllerProvider.notifier)
          .login(username: ' OMAR ', password: 'password');
      expect(
        container.read(authControllerProvider).phase,
        AuthPhase.twoFactorRequired,
      );
      expect(repository.lastUsername, 'OMAR');

      await container
          .read(authControllerProvider.notifier)
          .completeTwoFactorWithAuthenticator('123456');
      expect(
        container.read(authControllerProvider).phase,
        AuthPhase.authenticated,
      );
      expect(container.read(authControllerProvider).challenge, isNull);
      container.dispose();
    },
  );

  test(
    'recovery completion is supported and fresh login drops challenge',
    () async {
      var suppliedRecovery = '';
      final repository = FakeAuthRepository();
      repository.loginHandler = (_, _) async =>
          LoginTwoFactorRequired(sampleChallenge);
      repository.recoveryHandler = (_, recovery) async {
        suppliedRecovery = recovery;
        return sampleSession;
      };
      final container = _container(repository);
      container.read(authControllerProvider);
      await _settle();

      final notifier = container.read(authControllerProvider.notifier);
      await notifier.login(username: 'omar', password: 'password');
      await notifier.completeTwoFactorWithRecoveryCode('recovery-code');
      expect(suppliedRecovery, 'recovery-code');
      expect(
        container.read(authControllerProvider).phase,
        AuthPhase.authenticated,
      );

      notifier.returnToLogin();
      expect(container.read(authControllerProvider).challenge, isNull);
      container.dispose();
    },
  );

  test('a fast client clock cannot prevent server 2FA evaluation', () async {
    var completions = 0;
    final expired = TwoFactorChallenge(
      token: 'expired-challenge',
      expiresAt: DateTime.now().toUtc().subtract(const Duration(seconds: 1)),
    );
    final repository = FakeAuthRepository();
    repository.loginHandler = (_, _) async => LoginTwoFactorRequired(expired);
    repository.authenticatorHandler = (_, _) async {
      completions += 1;
      return sampleSession;
    };
    final container = _container(repository);
    container.read(authControllerProvider);
    await _settle();

    final notifier = container.read(authControllerProvider.notifier);
    await notifier.login(username: 'omar', password: 'password');
    await notifier.completeTwoFactorWithAuthenticator('123456');

    expect(completions, 1);
    expect(
      container.read(authControllerProvider).phase,
      AuthPhase.authenticated,
    );
    container.dispose();
  });

  test('server terminal 2FA reasons remain distinct', () async {
    for (final entry in {
      'invalid_two_factor_challenge': TwoFactorTerminalReason.invalidOrExpired,
      'two_factor_attempts_exceeded': TwoFactorTerminalReason.attemptsExceeded,
    }.entries) {
      final repository = FakeAuthRepository()
        ..loginHandler = (_, _) async {
          return LoginTwoFactorRequired(sampleChallenge);
        }
        ..authenticatorHandler = (_, _) async {
          throw ApiException(kind: ApiErrorKind.validation, code: entry.key);
        };
      final container = _container(repository);
      container.read(authControllerProvider);
      await _settle();

      final notifier = container.read(authControllerProvider.notifier);
      await notifier.login(username: 'omar', password: 'password');
      await notifier.completeTwoFactorWithAuthenticator('123456');

      final state = container.read(authControllerProvider);
      expect(state.phase, AuthPhase.twoFactorRequired);
      expect(state.twoFactorTerminalReason, entry.value);
      container.dispose();
    }
  });

  test('duplicate two-factor submissions invoke the repository once', () async {
    final completion = Completer<AuthSession>();
    final repository = FakeAuthRepository()
      ..loginHandler = (_, _) async {
        return LoginTwoFactorRequired(sampleChallenge);
      }
      ..authenticatorHandler = (_, _) => completion.future;
    final container = _container(repository);
    container.read(authControllerProvider);
    await _settle();

    final notifier = container.read(authControllerProvider.notifier);
    await notifier.login(username: 'omar', password: 'password');
    final first = notifier.completeTwoFactorWithAuthenticator('123456');
    final duplicate = notifier.completeTwoFactorWithAuthenticator('123456');
    expect(repository.authenticatorCalls, 1);

    completion.complete(sampleSession);
    await Future.wait([first, duplicate]);
    expect(
      container.read(authControllerProvider).phase,
      AuthPhase.authenticated,
    );
    container.dispose();
  });

  test('stale two-factor completion cannot override return to login', () async {
    final completion = Completer<AuthSession>();
    final repository = FakeAuthRepository()
      ..loginHandler = (_, _) async {
        return LoginTwoFactorRequired(sampleChallenge);
      }
      ..authenticatorHandler = (_, _) => completion.future;
    final container = _container(repository);
    container.read(authControllerProvider);
    await _settle();

    final notifier = container.read(authControllerProvider.notifier);
    await notifier.login(username: 'omar', password: 'password');
    final pending = notifier.completeTwoFactorWithAuthenticator('123456');
    notifier.returnToLogin();
    completion.complete(sampleSession);
    await pending;

    expect(
      container.read(authControllerProvider).phase,
      AuthPhase.unauthenticated,
    );
    container.dispose();
  });

  test('newest session restoration wins when completions reverse', () async {
    final first = Completer<MobileUser?>();
    final second = Completer<MobileUser?>();
    var invocation = 0;
    final repository = FakeAuthRepository()
      ..restoreHandler = () {
        invocation += 1;
        return invocation == 1 ? first.future : second.future;
      };
    final container = _container(repository);
    container.read(authControllerProvider);
    await Future<void>.delayed(Duration.zero);

    final newest = container
        .read(authControllerProvider.notifier)
        .restoreSession();
    second.complete(sampleUser);
    await newest;
    first.complete(null);
    await _settle();

    expect(
      container.read(authControllerProvider).phase,
      AuthPhase.authenticated,
    );
    container.dispose();
  });

  test(
    'pending restoration completes safely after provider disposal',
    () async {
      final completion = Completer<MobileUser?>();
      final repository = FakeAuthRepository()
        ..restoreHandler = () => completion.future;
      final container = _container(repository);
      container.read(authControllerProvider);
      await Future<void>.delayed(Duration.zero);

      container.dispose();
      completion.complete(sampleUser);
      await _settle();
    },
  );

  test('restoration failures expose safe distinct categories', () async {
    for (final entry in <Object, SessionRestorationFailure>{
      const ApiException(kind: ApiErrorKind.network):
          SessionRestorationFailure.network,
      const ApiException(kind: ApiErrorKind.server):
          SessionRestorationFailure.server,
      const TokenStorageException(TokenStorageOperation.read):
          SessionRestorationFailure.storage,
      const FormatException('malformed response'):
          SessionRestorationFailure.unexpected,
    }.entries) {
      final repository = FakeAuthRepository()..restoreError = entry.key;
      final container = _container(repository);
      container.read(authControllerProvider);
      await _settle();

      expect(
        container.read(authControllerProvider).restorationFailure,
        entry.value,
      );
      container.dispose();
    }
  });

  test('failed logout restores authenticated state for retry', () async {
    final repository = FakeAuthRepository()
      ..restoreResult = sampleUser
      ..logoutHandler = () async => throw networkFailure();
    final container = _container(repository);
    container.read(authControllerProvider);
    await _settle();

    await container.read(authControllerProvider.notifier).logout();

    expect(
      container.read(authControllerProvider).phase,
      AuthPhase.authenticated,
    );
    expect(
      container.read(authControllerProvider).error?.kind,
      ApiErrorKind.network,
    );
    container.dispose();
  });
}

ProviderContainer _container(FakeAuthRepository repository) {
  return ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(repository)],
  );
}

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
