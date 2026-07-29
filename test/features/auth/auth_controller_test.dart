import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indirimgo_mobile/core/errors/api_exception.dart';
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

  test('expired challenge stays local and asks for a fresh login', () async {
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

    expect(container.read(authControllerProvider).challengeExpired, isTrue);
    expect(completions, 0);
    container.dispose();
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
