import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indirimgo_mobile/app.dart';
import 'package:indirimgo_mobile/core/config/app_config.dart';
import 'package:indirimgo_mobile/core/routing/app_router.dart';
import 'package:indirimgo_mobile/core/storage/locale_preference_store.dart';
import 'package:indirimgo_mobile/core/storage/pending_checkout_store.dart';
import 'package:indirimgo_mobile/core/storage/token_storage.dart';
import 'package:indirimgo_mobile/features/auth/domain/auth_repository.dart';
import 'package:indirimgo_mobile/features/auth/presentation/auth_controller.dart';
import 'package:indirimgo_mobile/features/catalog/domain/catalog_repository.dart';
import 'package:indirimgo_mobile/features/orders/domain/order_repository.dart';
import 'package:indirimgo_mobile/features/purchase/domain/purchase_repository.dart';
import 'package:indirimgo_mobile/features/wallet/domain/wallet_repository.dart';

import '../../support/fake_catalog_repository.dart';
import '../../support/fake_order_repository.dart';
import '../../support/fake_purchase_repository.dart';
import '../../support/fake_wallet_repository.dart';
import '../../support/fakes.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .localesTestValue = const [
      Locale('en'),
    ];
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .clearLocalesTestValue();
  });

  testWidgets('four destinations preserve nested selection and branch state', (
    tester,
  ) async {
    final container = await _pumpAuthenticated(tester);
    expect(find.byKey(const Key('app-navigation-bar')), findsOneWidget);
    expect(_selectedIndex(tester), 0);

    await tester.tap(find.byKey(const Key('nav-packages')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('package-search-field')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('package-search-field')),
      'game',
    );
    await tester.pump();
    expect(_selectedIndex(tester), 1);

    await tester.tap(find.byKey(const Key('package-card-42')).hitTestable());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('package-detail')), findsOneWidget);
    expect(_selectedIndex(tester), 1);

    await tester.tap(find.byKey(const Key('nav-orders')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('orders-list')), findsOneWidget);
    expect(_selectedIndex(tester), 2);

    await tester.tap(find.byKey(const Key('order-card-ORD-2026-000001')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('order-detail')), findsOneWidget);
    expect(_selectedIndex(tester), 2);

    await tester.tap(find.byKey(const Key('nav-packages')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('package-detail')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('package-search-field'), skipOffstage: false),
          )
          .controller
          ?.text,
      'game',
    );

    await tester.tap(find.byKey(const Key('nav-packages')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('package-search-field')), findsOneWidget);
    expect(find.byKey(const Key('package-detail')), findsNothing);

    await tester.tap(find.byKey(const Key('nav-account')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account-screen')), findsOneWidget);
    expect(find.byKey(const Key('account-orders')), findsNothing);
    expect(_selectedIndex(tester), 3);

    container.read(routerProvider).go(AppRoutes.packageBuy(42, 901));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-navigation-bar')), findsNothing);
  });

  testWidgets('Android back returns to Home from a branch root', (
    tester,
  ) async {
    await _pumpAuthenticated(tester);
    await tester.tap(find.byKey(const Key('nav-orders')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('orders-list')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('authenticated-shell')), findsOneWidget);
    expect(_selectedIndex(tester), 0);
  });

  testWidgets('NavigationRail is used at 840 logical pixels', (tester) async {
    tester.view.physicalSize = const Size(840, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await _pumpAuthenticated(tester);
    expect(find.byKey(const Key('app-navigation-rail')), findsOneWidget);
    expect(find.byKey(const Key('app-navigation-bar')), findsNothing);
  });

  testWidgets('language change keeps route, auth, and typed input', (
    tester,
  ) async {
    final store = InMemoryLocalePreferenceStore();
    await _pumpAuthenticated(tester, localeStore: store);
    await tester.tap(find.byKey(const Key('nav-account')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('logout-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('account-language')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('language-option-ar')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('account-screen')), findsOneWidget);
    expect(find.byKey(const Key('logout-button')), findsOneWidget);
    expect(store.preference, LocalePreference.ar);
  });
}

int _selectedIndex(WidgetTester tester) {
  return tester
      .widget<NavigationBar>(find.byKey(const Key('app-navigation-bar')))
      .selectedIndex;
}

Future<ProviderContainer> _pumpAuthenticated(
  WidgetTester tester, {
  InMemoryLocalePreferenceStore? localeStore,
}) async {
  final storage = InMemoryTokenStorage(sampleStoredSession());
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig(
          apiBaseUrl: 'https://api.example.test/api/v1',
          buildMode: AppBuildMode.release,
        ),
      ),
      tokenStorageProvider.overrideWithValue(storage),
      pendingCheckoutStoreProvider.overrideWithValue(
        InMemoryPendingCheckoutStore(),
      ),
      localePreferenceStoreProvider.overrideWithValue(
        localeStore ?? InMemoryLocalePreferenceStore(),
      ),
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(tokenStorage: storage)..restoreResult = sampleUser,
      ),
      catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
      orderRepositoryProvider.overrideWithValue(FakeOrderRepository()),
      purchaseRepositoryProvider.overrideWithValue(FakePurchaseRepository()),
      walletRepositoryProvider.overrideWithValue(FakeWalletRepository()),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const IndirimGoApp(),
    ),
  );
  await tester.pumpAndSettle();
  expect(container.read(authControllerProvider).phase, AuthPhase.authenticated);
  return container;
}
