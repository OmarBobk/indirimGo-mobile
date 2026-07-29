import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indirimgo_mobile/app.dart';
import 'package:indirimgo_mobile/core/config/app_config.dart';
import 'package:indirimgo_mobile/core/errors/api_exception.dart';
import 'package:indirimgo_mobile/core/routing/app_router.dart';
import 'package:indirimgo_mobile/core/storage/token_storage.dart';
import 'package:indirimgo_mobile/features/auth/domain/auth_models.dart';
import 'package:indirimgo_mobile/features/auth/domain/auth_repository.dart';

import 'support/fakes.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .localeTestValue = const Locale(
      'ar',
    );
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .clearLocaleTestValue();
  });

  testWidgets('Arabic is RTL and English can be selected', (tester) async {
    final repository = FakeAuthRepository();
    await _pumpApp(tester, repository);

    final title = find.text('أهلاً بعودتك');
    expect(title, findsOneWidget);
    expect(
      tester
          .widget<Directionality>(
            find
                .ancestor(of: title, matching: find.byType(Directionality))
                .first,
          )
          .textDirection,
      TextDirection.rtl,
    );

    await tester.tap(find.byKey(const Key('language-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('required fields validate locally', (tester) async {
    final repository = FakeAuthRepository();
    await _pumpApp(tester, repository);

    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pump();

    expect(find.text('اسم المستخدم مطلوب.'), findsOneWidget);
    expect(find.text('كلمة المرور مطلوبة.'), findsOneWidget);
    expect(repository.loginCalls, 0);
  });

  testWidgets('loading disables duplicate login submissions', (tester) async {
    final result = Completer<LoginOutcome>();
    final repository = FakeAuthRepository()
      ..loginHandler = (_, _) => result.future;
    await _pumpApp(tester, repository);
    await _fillLogin(tester);

    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pump();
    expect(repository.loginCalls, 1);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('login-button')))
          .onPressed,
      isNull,
    );

    result.complete(LoginAuthenticated(sampleSession));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('authenticated-shell')), findsOneWidget);
  });

  testWidgets('Laravel field errors and general errors are presented', (
    tester,
  ) async {
    final repository = FakeAuthRepository()
      ..loginHandler = (_, _) async => throw const ApiException(
        kind: ApiErrorKind.validation,
        code: 'invalid_credentials',
        fieldErrors: {
          'username': ['Server username error'],
        },
      );
    await _pumpApp(tester, repository);
    await _fillLogin(tester);
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();

    expect(find.text('Server username error'), findsOneWidget);
    expect(find.text('اسم المستخدم أو كلمة المرور غير صحيحة.'), findsOneWidget);
  });

  testWidgets(
    'two-factor navigation switches authenticator and recovery modes',
    (tester) async {
      final repository = FakeAuthRepository()
        ..loginHandler = (_, _) async =>
            LoginTwoFactorRequired(sampleChallenge);
      await _pumpApp(tester, repository);
      await _fillLogin(tester);
      await tester.tap(find.byKey(const Key('login-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('authenticator-field')), findsOneWidget);
      await tester.tap(find.text('رمز الاسترداد'));
      await tester.pump();
      expect(find.byKey(const Key('recovery-field')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('recovery-field')),
        'recovery-code',
      );
      await tester.tap(find.byKey(const Key('verify-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('authenticated-shell')), findsOneWidget);
    },
  );

  testWidgets('expired challenge shows recovery and returns to login', (
    tester,
  ) async {
    final expired = TwoFactorChallenge(
      token: 'expired',
      expiresAt: DateTime.now().toUtc().subtract(const Duration(seconds: 1)),
    );
    final repository = FakeAuthRepository()
      ..loginHandler = (_, _) async => LoginTwoFactorRequired(expired);
    await _pumpApp(tester, repository);
    await _fillLogin(tester);
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('challenge-expired')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('return-to-login')));
    await tester.tap(find.byKey(const Key('return-to-login')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-button')), findsOneWidget);
  });

  testWidgets('startup restoration never flashes the login screen', (
    tester,
  ) async {
    final completion = Completer<MobileUser?>();
    final repository = FakeAuthRepository()
      ..restoreHandler = () => completion.future;
    await _pumpApp(tester, repository, settle: false);
    await tester.pump();

    expect(find.text('جارٍ التحقق من جلستك'), findsOneWidget);
    expect(find.byKey(const Key('login-button')), findsNothing);

    completion.complete(sampleUser);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('authenticated-shell')), findsOneWidget);
    expect(find.byKey(const Key('login-button')), findsNothing);
  });

  testWidgets('unauthenticated routes are protected', (tester) async {
    final repository = FakeAuthRepository();
    final container = await _pumpApp(tester, repository);

    container.read(routerProvider).go(AppRoutes.shell);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-button')), findsOneWidget);
    expect(find.byKey(const Key('authenticated-shell')), findsNothing);
  });

  testWidgets('authenticated users redirect away from login and can logout', (
    tester,
  ) async {
    final repository = FakeAuthRepository()..restoreResult = sampleUser;
    final container = await _pumpApp(tester, repository);

    container.read(routerProvider).go(AppRoutes.login);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('authenticated-shell')), findsOneWidget);

    await tester.tap(find.byKey(const Key('logout-button')));
    await tester.pumpAndSettle();
    expect(repository.logoutCalls, 1);
    expect(find.byKey(const Key('login-button')), findsOneWidget);
  });

  testWidgets(
    'offline session verification offers retry without clearing login',
    (tester) async {
      final repository = FakeAuthRepository()..restoreError = networkFailure();
      await _pumpApp(tester, repository);

      expect(find.byKey(const Key('session-retry')), findsOneWidget);
      expect(repository.clearCalls, 0);

      repository
        ..restoreError = null
        ..restoreResult = sampleUser;
      await tester.tap(find.byKey(const Key('session-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('authenticated-shell')), findsOneWidget);
    },
  );

  testWidgets('login survives large text scaling without overflow', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _pumpApp(tester, FakeAuthRepository());
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('login-button')), findsOneWidget);
  });
}

Future<ProviderContainer> _pumpApp(
  WidgetTester tester,
  FakeAuthRepository repository, {
  bool settle = true,
}) async {
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig(apiBaseUrl: 'https://api.example.test/api/v1'),
      ),
      tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
      authRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const IndirimGoApp(),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  }
  return container;
}

Future<void> _fillLogin(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('username-field')), 'omar');
  await tester.enterText(find.byKey(const Key('password-field')), 'password');
}
