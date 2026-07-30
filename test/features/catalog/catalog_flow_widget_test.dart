import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indirimgo_mobile/app.dart';
import 'package:indirimgo_mobile/core/config/app_config.dart';
import 'package:indirimgo_mobile/core/errors/api_exception.dart';
import 'package:indirimgo_mobile/core/routing/app_router.dart';
import 'package:indirimgo_mobile/core/storage/token_storage.dart';
import 'package:indirimgo_mobile/features/auth/domain/auth_repository.dart';
import 'package:indirimgo_mobile/features/auth/presentation/auth_controller.dart';
import 'package:indirimgo_mobile/features/catalog/domain/catalog_models.dart';
import 'package:indirimgo_mobile/features/catalog/domain/catalog_repository.dart';
import 'package:indirimgo_mobile/features/catalog/presentation/catalog_controllers.dart';

import '../../support/catalog_fixtures.dart';
import '../../support/fake_catalog_repository.dart';
import '../../support/fakes.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .localesTestValue = const [
      Locale('ar'),
    ];
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .clearLocalesTestValue();
  });

  testWidgets('Arabic RTL home shows shelves and browse-all', (tester) async {
    await _pumpAuthenticated(tester);
    expect(find.byKey(const Key('authenticated-shell')), findsOneWidget);
    expect(find.text('طلبتها كثيراً'), findsOneWidget);
    expect(find.text('باقات مميزة'), findsOneWidget);
    expect(find.text('Example Game Top-up'), findsWidgets);
    expect(find.byKey(const Key('browse-all-packages')), findsOneWidget);
    expect(
      tester
          .widget<Directionality>(
            find
                .ancestor(
                  of: find.byKey(const Key('authenticated-shell')),
                  matching: find.byType(Directionality),
                )
                .first,
          )
          .textDirection,
      TextDirection.rtl,
    );
  });

  testWidgets('empty frequently ordered shelf is omitted', (tester) async {
    await _pumpAuthenticated(
      tester,
      catalog: FakeCatalogRepository(
        home: CatalogHome.fromJson(
          catalogHomeJson(frequentlyOrdered: const []),
        ),
      ),
    );
    expect(find.text('طلبتها كثيراً'), findsNothing);
    expect(find.text('باقات مميزة'), findsOneWidget);
  });

  testWidgets('category chip opens filtered package list', (tester) async {
    await _pumpAuthenticated(tester);
    final chip = find.byKey(const Key('category-chip-3'));
    await tester.scrollUntilVisible(chip, 200);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('package-list')), findsOneWidget);
    expect(find.byKey(const Key('active-category-chip')), findsOneWidget);
    expect(find.text('Games'), findsWidgets);
  });

  testWidgets('frequently ordered count is visible for 1 and plurals', (
    tester,
  ) async {
    await _pumpAuthenticated(
      tester,
      catalog: FakeCatalogRepository(
        home: CatalogHome.fromJson(
          catalogHomeJson(
            frequentlyOrdered: [
              frequentlyOrderedJson(timesOrdered: 1),
              {
                ...packageSummaryJson(id: 44, name: 'Twice Pack'),
                'times_ordered': 2,
              },
              {
                ...packageSummaryJson(id: 45, name: 'Many Pack'),
                'times_ordered': 5,
              },
            ],
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('times-ordered-42')), findsOneWidget);
    expect(find.text('طُلبت مرة واحدة'), findsOneWidget);
    expect(find.text('طُلبت مرتين'), findsOneWidget);
    final many = find.byKey(const Key('times-ordered-45'));
    await tester.scrollUntilVisible(many, 200);
    await tester.pumpAndSettle();
    expect(many, findsOneWidget);
    expect(find.textContaining('5'), findsWidgets);
  });

  testWidgets('package card chevron mirrors for Arabic RTL and English LTR', (
    tester,
  ) async {
    await _pumpAuthenticated(tester);
    final rtlMirror = tester.widget<Transform>(
      find.byKey(const Key('package-card-chevron-mirror')).first,
    );
    expect(rtlMirror.transform.entry(0, 0), -1.0);

    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .localesTestValue = const [
      Locale('en'),
    ];
    await _pumpAuthenticated(tester);
    final ltrMirror = tester.widget<Transform>(
      find.byKey(const Key('package-card-chevron-mirror')).first,
    );
    expect(ltrMirror.transform.entry(0, 0), 1.0);
  });

  testWidgets('home refresh 401 exits /app and clears prices', (tester) async {
    final storage = InMemoryTokenStorage(sampleStoredSession());
    final catalog = FakeCatalogRepository();
    final container = await _pumpApp(
      tester,
      auth: FakeAuthRepository(tokenStorage: storage)
        ..restoreResult = sampleUser,
      catalog: catalog,
      storage: storage,
    );
    expect(find.byKey(const Key('authenticated-shell')), findsOneWidget);
    expect(find.textContaining(r'$'), findsWidgets);

    catalog.homeError = unauthorizedRejection(storage.session!.reference);
    await container.read(catalogHomeControllerProvider.notifier).refresh();
    await tester.pumpAndSettle();

    expect(
      container.read(authControllerProvider).phase,
      AuthPhase.unauthenticated,
    );
    expect(find.byKey(const Key('authenticated-shell')), findsNothing);
    expect(find.byKey(const Key('login-button')), findsOneWidget);
    expect(find.textContaining(r'$5.00'), findsNothing);
  });

  testWidgets('package detail renders fixed and custom options', (
    tester,
  ) async {
    final container = await _pumpAuthenticated(tester);
    container.read(routerProvider).go(AppRoutes.packageDetail(42));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('package-detail')), findsOneWidget);
    expect(find.text('100 Coins'), findsOneWidget);
    expect(find.text('سعر ثابت'), findsOneWidget);
    final custom = find.text('Custom amount', skipOffstage: false);
    await tester.ensureVisible(custom);
    await tester.pumpAndSettle();
    expect(find.text('Custom amount'), findsOneWidget);
    expect(find.text('مبلغ مخصص'), findsOneWidget);
    expect(find.textContaining('يُحسب السعر النهائي'), findsOneWidget);
    expect(find.text(r'$5.00', skipOffstage: false), findsWidgets);
  });

  testWidgets('prices hidden shows localized copy without amounts', (
    tester,
  ) async {
    final container = await _pumpAuthenticated(
      tester,
      catalog: FakeCatalogRepository(
        home: CatalogHome.fromJson(
          catalogHomeJson(
            pricesVisible: false,
            featured: [packageSummaryJson(fromPrice: null)],
            frequentlyOrdered: const [],
          ),
        ),
        detail: PackageDetailResult.fromJson(
          packageDetailJson(
            pricesVisible: false,
            fromPrice: null,
            products: [
              {...fixedProductJson(), 'unit_price': null},
              customProductJson(minimumPrice: null),
            ],
          ),
        ),
      ),
    );
    expect(find.text('السعر غير ظاهر'), findsWidgets);
    expect(find.text(r'$5.00'), findsNothing);

    container.read(routerProvider).go(AppRoutes.packageDetail(42));
    await tester.pumpAndSettle();
    expect(find.text('السعر غير ظاهر'), findsWidgets);
    expect(find.text(r'$5.00'), findsNothing);
  });

  testWidgets('price unavailable is distinct from hidden', (tester) async {
    final container = await _pumpAuthenticated(
      tester,
      catalog: FakeCatalogRepository(
        detail: PackageDetailResult.fromJson(
          packageDetailJson(
            pricesVisible: true,
            fromPrice: null,
            products: [
              {...fixedProductJson(), 'unit_price': null},
            ],
          ),
        ),
      ),
    );
    container.read(routerProvider).go(AppRoutes.packageDetail(42));
    await tester.pumpAndSettle();
    expect(find.text('السعر غير متاح'), findsWidgets);
    expect(find.text('السعر غير ظاهر'), findsNothing);
  });

  testWidgets('package not found offers route back to browsing', (
    tester,
  ) async {
    final container = await _pumpAuthenticated(
      tester,
      catalog: FakeCatalogRepository()
        ..detailError = const ApiException(
          kind: ApiErrorKind.notFound,
          code: 'package_not_found',
          statusCode: 404,
        ),
    );
    container.read(routerProvider).go(AppRoutes.packageDetail(404));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('package-not-found')), findsOneWidget);
    await tester.tap(find.byKey(const Key('catalog-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('package-list')), findsOneWidget);
  });

  testWidgets('home error retry and offline keep session', (tester) async {
    final catalog = FakeCatalogRepository()..homeError = networkFailure();
    final auth = FakeAuthRepository()..restoreResult = sampleUser;
    await _pumpApp(tester, auth: auth, catalog: catalog);
    expect(find.byKey(const Key('catalog-home-error')), findsOneWidget);
    expect(find.byKey(const Key('login-button')), findsNothing);

    catalog.homeError = null;
    await tester.tap(find.byKey(const Key('catalog-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('authenticated-shell')), findsOneWidget);
  });

  testWidgets('English LTR catalog home', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .localesTestValue = const [
      Locale('en'),
    ];
    await _pumpAuthenticated(tester);
    expect(find.text('Featured packages'), findsOneWidget);
    expect(find.text('Browse all packages'), findsOneWidget);
  });

  testWidgets('account logout remains available from home', (tester) async {
    await _pumpAuthenticated(tester);
    await tester.tap(find.byKey(const Key('account-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('logout-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('logout-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-button')), findsOneWidget);
  });

  testWidgets('auth protects catalog routes', (tester) async {
    final container = await _pumpApp(
      tester,
      auth: FakeAuthRepository(),
      catalog: FakeCatalogRepository(),
    );
    container.read(routerProvider).go(AppRoutes.packages);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-button')), findsOneWidget);
  });

  testWidgets('back from detail preserves package list filters', (
    tester,
  ) async {
    final container = await _pumpAuthenticated(tester);
    container.read(routerProvider).go(AppRoutes.packagesWithCategory(3));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('active-category-chip')), findsOneWidget);
    container.read(routerProvider).push(AppRoutes.packageDetail(42));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('package-detail')), findsOneWidget);
    container.read(routerProvider).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('package-list')), findsOneWidget);
    expect(find.byKey(const Key('active-category-chip')), findsOneWidget);
  });

  testWidgets('large text and dark mode do not crash catalog', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pumpAuthenticated(tester, dark: true);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('authenticated-shell')), findsOneWidget);
    expect(find.byKey(const Key('browse-all-packages')), findsOneWidget);
  });

  testWidgets('session restoration opens home without login flash', (
    tester,
  ) async {
    final completion = Completer<void>();
    final auth = FakeAuthRepository()
      ..restoreHandler = () async {
        await completion.future;
        return sampleUser;
      };
    await _pumpApp(
      tester,
      auth: auth,
      catalog: FakeCatalogRepository(),
      settle: false,
    );
    await tester.pump();
    expect(find.byKey(const Key('login-button')), findsNothing);
    completion.complete();
    // Allow auth restore + catalog home load without relying on unbounded
    // animations from indeterminate indicators during the transition.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byKey(const Key('authenticated-shell')).evaluate().isNotEmpty) {
        break;
      }
    }
    expect(find.byKey(const Key('authenticated-shell')), findsOneWidget);
    expect(find.byKey(const Key('login-button')), findsNothing);
  });
}

Future<ProviderContainer> _pumpAuthenticated(
  WidgetTester tester, {
  FakeCatalogRepository? catalog,
  bool dark = false,
}) {
  final storage = InMemoryTokenStorage(sampleStoredSession());
  return _pumpApp(
    tester,
    auth: FakeAuthRepository(tokenStorage: storage)..restoreResult = sampleUser,
    catalog: catalog ?? FakeCatalogRepository(),
    storage: storage,
    dark: dark,
  );
}

Future<ProviderContainer> _pumpApp(
  WidgetTester tester, {
  required FakeAuthRepository auth,
  required FakeCatalogRepository catalog,
  InMemoryTokenStorage? storage,
  bool settle = true,
  bool dark = false,
}) async {
  if (dark) {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  }
  final tokenStorage = storage ?? InMemoryTokenStorage(sampleStoredSession());
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig(
          apiBaseUrl: 'https://api.example.test/api/v1',
          buildMode: AppBuildMode.release,
        ),
      ),
      tokenStorageProvider.overrideWithValue(tokenStorage),
      authRepositoryProvider.overrideWithValue(auth),
      catalogRepositoryProvider.overrideWithValue(catalog),
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
