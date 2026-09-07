import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indirimgo_mobile/app.dart';
import 'package:indirimgo_mobile/core/config/app_config.dart';
import 'package:indirimgo_mobile/core/errors/api_exception.dart';
import 'package:indirimgo_mobile/core/localization/generated/app_localizations.dart';
import 'package:indirimgo_mobile/core/routing/app_router.dart';
import 'package:indirimgo_mobile/core/storage/pending_checkout_store.dart';
import 'package:indirimgo_mobile/core/storage/token_storage.dart';
import 'package:indirimgo_mobile/features/auth/domain/auth_repository.dart';
import 'package:indirimgo_mobile/features/catalog/domain/catalog_repository.dart';
import 'package:indirimgo_mobile/features/orders/domain/order_models.dart';
import 'package:indirimgo_mobile/features/orders/domain/order_repository.dart';
import 'package:indirimgo_mobile/features/orders/presentation/order_controllers.dart';
import 'package:indirimgo_mobile/features/orders/presentation/orders_list_screen.dart';
import 'package:indirimgo_mobile/features/purchase/domain/purchase_repository.dart';
import 'package:indirimgo_mobile/features/wallet/domain/wallet_repository.dart';

import '../../support/fake_catalog_repository.dart';
import '../../support/fake_order_repository.dart';
import '../../support/fake_purchase_repository.dart';
import '../../support/fake_wallet_repository.dart';
import '../../support/fakes.dart';
import '../../support/order_fixtures.dart';

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

  testWidgets('Arabic RTL history renders LTR money and order number', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final container = await _pumpAuthenticated(tester, FakeOrderRepository());
    container.read(routerProvider).go(AppRoutes.orders);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('orders-list')), findsOneWidget);
    expect(
      tester
          .widget<Directionality>(
            find
                .ancestor(
                  of: find.byKey(const Key('order-number-ORD-2026-000001')),
                  matching: find.byType(Directionality),
                )
                .first,
          )
          .textDirection,
      TextDirection.ltr,
    );
    final moneyText = tester.widget<Text>(find.text(r'$20.00').first);
    expect(moneyText.textDirection, TextDirection.ltr);
    expect(
      tester
          .getSemantics(find.byKey(const Key('order-card-ORD-2026-000001')))
          .label,
      contains('ORD-2026-000001'),
    );
    semantics.dispose();
  });

  testWidgets('English history navigates to localized detail', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .localesTestValue = const [
      Locale('en'),
    ];
    final container = await _pumpAuthenticated(tester, FakeOrderRepository());
    container.read(routerProvider).go(AppRoutes.orders);
    await tester.pumpAndSettle();
    expect(find.text('Orders'), findsOneWidget);

    await tester.tap(find.byKey(const Key('order-card-ORD-2026-000001')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('order-detail')), findsOneWidget);
    expect(find.text('Payment: Paid'), findsOneWidget);
    expect(find.text('Fulfillment: Completed'), findsOneWidget);
  });

  testWidgets('history exposes loading, empty and safe error states', (
    tester,
  ) async {
    final completer = Completer<OrderListPage>();
    final loading = FakeOrderRepository()
      ..listHandler = (_, _) => completer.future;
    await _pumpOrdersScreen(tester, loading);
    expect(find.byKey(const Key('orders-loading')), findsOneWidget);
    completer.complete(OrderListPage.fromJson(orderListPageJson(orders: [])));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('orders-empty')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    final failed = FakeOrderRepository()
      ..listError = const ApiException(kind: ApiErrorKind.network);
    await _pumpOrdersScreen(tester, failed);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('orders-error')), findsOneWidget);
    expect(find.textContaining('الخادم'), findsOneWidget);
  });

  testWidgets('direct detail handles invalid route and large text', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final container = await _pumpAuthenticated(tester, FakeOrderRepository());
    container
        .read(routerProvider)
        .go(AppRoutes.orderReceipt('invalid-order-number'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('order-detail-not-found')), findsOneWidget);

    container
        .read(routerProvider)
        .go(AppRoutes.orderReceipt('ORD-2026-000001'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('order-detail')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpOrdersScreen(
  WidgetTester tester,
  FakeOrderRepository orders,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        orderCustomerIdProvider.overrideWithValue(7),
        orderRepositoryProvider.overrideWithValue(orders),
      ],
      child: const MaterialApp(
        locale: Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: OrdersListScreen(),
      ),
    ),
  );
}

Future<ProviderContainer> _pumpAuthenticated(
  WidgetTester tester,
  FakeOrderRepository orders,
) async {
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
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(tokenStorage: storage)..restoreResult = sampleUser,
      ),
      catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
      purchaseRepositoryProvider.overrideWithValue(FakePurchaseRepository()),
      walletRepositoryProvider.overrideWithValue(FakeWalletRepository()),
      orderRepositoryProvider.overrideWithValue(orders),
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
  return container;
}
