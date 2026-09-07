import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indirimgo_mobile/app.dart';
import 'package:indirimgo_mobile/core/config/app_config.dart';
import 'package:indirimgo_mobile/core/errors/api_exception.dart';
import 'package:indirimgo_mobile/core/routing/app_router.dart';
import 'package:indirimgo_mobile/core/storage/pending_checkout_store.dart';
import 'package:indirimgo_mobile/core/storage/token_storage.dart';
import 'package:indirimgo_mobile/features/auth/domain/auth_repository.dart';
import 'package:indirimgo_mobile/features/auth/presentation/auth_controller.dart';
import 'package:indirimgo_mobile/features/catalog/domain/catalog_repository.dart';
import 'package:indirimgo_mobile/features/orders/domain/order_models.dart';
import 'package:indirimgo_mobile/features/orders/domain/order_repository.dart';
import 'package:indirimgo_mobile/features/purchase/domain/purchase_repository.dart';
import 'package:indirimgo_mobile/features/purchase/presentation/purchase_controllers.dart';
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
    var container = await _pumpAuthenticated(tester, loading, settle: false);
    container.read(routerProvider).go(AppRoutes.orders);
    await tester.pump();
    expect(find.byKey(const Key('orders-loading')), findsOneWidget);
    completer.complete(OrderListPage.fromJson(orderListPageJson(orders: [])));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('orders-empty')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    final failed = FakeOrderRepository()
      ..listError = const ApiException(kind: ApiErrorKind.network);
    container = await _pumpAuthenticated(tester, failed);
    container.read(routerProvider).go(AppRoutes.orders);
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

Future<ProviderContainer> _pumpAuthenticated(
  WidgetTester tester,
  FakeOrderRepository orders, {
  bool settle = true,
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
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      if (container.read(authControllerProvider).phase ==
              AuthPhase.authenticated &&
          container.read(checkoutRecoveryControllerProvider).phase ==
              CheckoutRecoveryPhase.idle) {
        break;
      }
    }
    await tester.pump();
  }
  return container;
}
