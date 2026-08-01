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
import 'package:indirimgo_mobile/features/catalog/domain/catalog_models.dart';
import 'package:indirimgo_mobile/features/catalog/domain/catalog_repository.dart';
import 'package:indirimgo_mobile/features/purchase/domain/purchase_models.dart';
import 'package:indirimgo_mobile/features/purchase/domain/purchase_repository.dart';
import 'package:indirimgo_mobile/features/purchase/presentation/purchase_controllers.dart';
import 'package:indirimgo_mobile/features/wallet/domain/wallet_repository.dart';

import '../../support/fake_catalog_repository.dart';
import '../../support/fake_purchase_repository.dart';
import '../../support/fake_wallet_repository.dart';
import '../../support/fakes.dart';
import '../../support/purchase_fixtures.dart';

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

  testWidgets('Arabic RTL purchase form with requirements and money LTR', (
    tester,
  ) async {
    final purchase = FakePurchaseRepository();
    final container = await _pumpAuthenticated(tester, purchase: purchase);

    container.read(routerProvider).go(AppRoutes.packageBuy(42, 901));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('purchase-form')), findsOneWidget);
    expect(
      tester
          .widget<Directionality>(
            find
                .ancestor(
                  of: find.byKey(const Key('purchase-form')),
                  matching: find.byType(Directionality),
                )
                .first,
          )
          .textDirection,
      TextDirection.rtl,
    );
    expect(find.byKey(const Key('quantity-field')), findsOneWidget);
    expect(find.byKey(const Key('requirement-id')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('quantity-field')), '2');
    await tester.enterText(find.byKey(const Key('requirement-id')), 'player-1');
    await tester.ensureVisible(find.byKey(const Key('continue-to-quote')));
    await tester.tap(find.byKey(const Key('continue-to-quote')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('checkout-review')), findsOneWidget);
    expect(find.byKey(const Key('final-total')), findsOneWidget);
    final money = tester.widget<Text>(
      find
          .descendant(
            of: find.byKey(const Key('final-total')),
            matching: find.byType(Text),
          )
          .first,
    );
    expect(money.textDirection, TextDirection.ltr);
    expect(find.textContaining(r'$20.00'), findsWidgets);
    expect(purchase.quoteCalls, 1);
  });

  testWidgets('English form custom amount and insufficient balance', (
    tester,
  ) async {
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .localesTestValue = const [
      Locale('en'),
    ];
    final purchase = FakePurchaseRepository(
      quote: CheckoutQuote.fromSuccessJson(
        checkoutQuoteJson(canAfford: false, available: '1.00'),
      ),
    );
    final container = await _pumpAuthenticated(tester, purchase: purchase);
    container.read(routerProvider).go(AppRoutes.packageBuy(42, 902));
    await tester.pumpAndSettle();

    expect(find.text('Buy now'), findsWidgets);
    expect(find.byKey(const Key('requested-amount-field')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('requested-amount-field')),
      '200',
    );
    await tester.enterText(find.byKey(const Key('requirement-id')), 'player-1');
    await tester.ensureVisible(find.byKey(const Key('continue-to-quote')));
    await tester.tap(find.byKey(const Key('continue-to-quote')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('insufficient-balance-message')),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('confirm-wallet-purchase')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('prices_visible false hides buy now', (tester) async {
    final container = await _pumpAuthenticated(
      tester,
      catalog: FakeCatalogRepository(
        detail: PackageDetailResult.fromJson(
          packageDetailJson(pricesVisible: false),
        ),
      ),
    );
    container.read(routerProvider).go(AppRoutes.packageDetail(42));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('buy-now-901')), findsNothing);
    expect(find.textContaining('السعر غير ظاهر'), findsWidgets);
  });

  testWidgets('buy now appears for purchasable products', (tester) async {
    final container = await _pumpAuthenticated(tester);
    container.read(routerProvider).go(AppRoutes.packageDetail(42));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('buy-now-901')), 200);
    expect(find.byKey(const Key('buy-now-901')), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('buy-now-902')), 200);
    expect(find.byKey(const Key('buy-now-902')), findsOneWidget);
  });

  testWidgets('receipt screen shows server totals only', (tester) async {
    final container = await _pumpAuthenticated(tester);
    container
        .read(routerProvider)
        .go(AppRoutes.orderReceipt('ORD-2026-000001'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('order-receipt')), findsOneWidget);
    expect(find.byKey(const Key('receipt-total')), findsOneWidget);
    expect(find.textContaining('ORD-2026-000001'), findsOneWidget);
  });

  testWidgets('unknown-result recovery processing UI', (tester) async {
    final pending = InMemoryPendingCheckoutStore()
      ..attempt = CheckoutRecoveryRecord(
        customerId: sampleUser.id,
        idempotencyKey: 'ig-pending',
        createdAt: DateTime.utc(2026, 8, 1),
      );
    final purchase = FakePurchaseRepository(
      status: CheckoutStatus.fromResponse(
        statusCode: 202,
        json: checkoutStatusProcessingJson(),
      ),
    );
    final container = await _pumpAuthenticated(
      tester,
      purchase: purchase,
      pending: pending,
      settle: false,
    );
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (container.read(authControllerProvider).phase ==
          AuthPhase.authenticated) {
        break;
      }
    }
    container.read(routerProvider).go(AppRoutes.checkoutRecovery);
    // Avoid pumpAndSettle: processing schedules a retry timer.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find
          .byKey(const Key('checkout-recovery-processing'))
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }
    expect(
      find.byKey(const Key('checkout-recovery-processing')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('checkout-recovery-manual-retry')),
      findsOneWidget,
    );
    container
        .read(checkoutRecoveryControllerProvider.notifier)
        .acknowledgeTerminal();
    await tester.pump();
  });

  testWidgets('auth redirect protects purchase routes', (tester) async {
    await _pumpApp(
      tester,
      auth: FakeAuthRepository()..restoreResult = null,
      catalog: FakeCatalogRepository(),
      purchase: FakePurchaseRepository(),
    );
    expect(find.byKey(const Key('login-button')), findsOneWidget);
  });

  testWidgets('large text smoke on review', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final purchase = FakePurchaseRepository();
    final container = await _pumpAuthenticated(tester, purchase: purchase);
    container.read(routerProvider).go(AppRoutes.packageBuy(42, 901));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('purchase-form')), findsOneWidget);
    container
        .read(purchaseDraftControllerProvider.notifier)
        .updateRequirementValue('id', 'player-1');
    final quoted = await container
        .read(purchaseFormControllerProvider.notifier)
        .requestQuote();
    expect(quoted, isTrue);
    container.read(routerProvider).go(AppRoutes.checkoutReview);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('checkout-review')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('server field errors surface on purchase form', (tester) async {
    final purchase = FakePurchaseRepository()
      ..quoteError = const ApiException(
        kind: ApiErrorKind.validation,
        statusCode: 422,
        fieldErrors: {
          'items.0.quantity': ['invalid'],
          'items.0.requirements.id': ['invalid'],
        },
      );
    final container = await _pumpAuthenticated(tester, purchase: purchase);
    container.read(routerProvider).go(AppRoutes.packageBuy(42, 901));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('requirement-id')), 'player-1');
    await tester.ensureVisible(find.byKey(const Key('continue-to-quote')));
    await tester.tap(find.byKey(const Key('continue-to-quote')));
    await tester.pumpAndSettle();
    expect(find.textContaining('كمية'), findsWidgets);
  });

  testWidgets('confirm button semantics describe wallet charge', (
    tester,
  ) async {
    final purchase = FakePurchaseRepository();
    final container = await _pumpAuthenticated(tester, purchase: purchase);
    container.read(routerProvider).go(AppRoutes.packageBuy(42, 901));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('requirement-id')), 'player-1');
    await tester.ensureVisible(find.byKey(const Key('continue-to-quote')));
    await tester.tap(find.byKey(const Key('continue-to-quote')));
    await tester.pumpAndSettle();
    expect(find.textContaining('محفظتك'), findsWidgets);
    expect(find.byKey(const Key('confirm-wallet-purchase')), findsOneWidget);
  });

  testWidgets('PopScope blocks back during submission', (tester) async {
    final purchase = FakePurchaseRepository()
      ..checkoutDelay = const Duration(milliseconds: 300);
    final container = await _pumpAuthenticated(tester, purchase: purchase);
    container.read(routerProvider).go(AppRoutes.packageBuy(42, 901));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('requirement-id')), 'player-1');
    await tester.ensureVisible(find.byKey(const Key('continue-to-quote')));
    await tester.tap(find.byKey(const Key('continue-to-quote')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirm-wallet-purchase')));
    await tester.pump();
    expect(
      container.read(checkoutReviewControllerProvider).phase,
      CheckoutReviewPhase.submitting,
    );
    final popScope = tester.widget<PopScope<Object?>>(
      find.byKey(const Key('checkout-review-popscope')),
    );
    expect(popScope.canPop, isFalse);

    await tester.pumpAndSettle();
  });

  testWidgets('completed recovery navigates to receipt and keeps anchor', (
    tester,
  ) async {
    final pending = InMemoryPendingCheckoutStore()
      ..attempt = CheckoutRecoveryRecord(
        customerId: sampleUser.id,
        idempotencyKey: 'ig-pending',
        createdAt: DateTime.utc(2026, 8, 1),
      );
    final purchase = FakePurchaseRepository(
      status: CheckoutStatus.fromResponse(
        statusCode: 200,
        json: checkoutStatusCompletedJson(),
      ),
    );
    await _pumpAuthenticated(
      tester,
      purchase: purchase,
      pending: pending,
      settle: false,
    );
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (find.byKey(const Key('order-receipt')).evaluate().isNotEmpty ||
          find.byKey(const Key('receipt-loading')).evaluate().isNotEmpty) {
        break;
      }
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('order-receipt')), findsOneWidget);
    final record = await pending.readForCustomer(sampleUser.id);
    expect(record?.hasCompletedAnchor, isTrue);
    expect(record?.hasUnresolvedKey, isFalse);

    await tester.tap(find.byKey(const Key('receipt-done')));
    await tester.pumpAndSettle();
    expect(await pending.readForCustomer(sampleUser.id), isNull);
  });
}

Future<ProviderContainer> _pumpAuthenticated(
  WidgetTester tester, {
  FakeCatalogRepository? catalog,
  FakePurchaseRepository? purchase,
  InMemoryPendingCheckoutStore? pending,
  bool settle = true,
}) {
  final storage = InMemoryTokenStorage(sampleStoredSession());
  return _pumpApp(
    tester,
    auth: FakeAuthRepository(tokenStorage: storage)..restoreResult = sampleUser,
    catalog: catalog ?? FakeCatalogRepository(),
    purchase: purchase ?? FakePurchaseRepository(),
    storage: storage,
    pending: pending,
    settle: settle,
  );
}

Future<ProviderContainer> _pumpApp(
  WidgetTester tester, {
  required FakeAuthRepository auth,
  required FakeCatalogRepository catalog,
  required FakePurchaseRepository purchase,
  InMemoryTokenStorage? storage,
  InMemoryPendingCheckoutStore? pending,
  bool settle = true,
}) async {
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig(
          apiBaseUrl: 'https://api.example.test/api/v1',
          buildMode: AppBuildMode.release,
        ),
      ),
      tokenStorageProvider.overrideWithValue(storage ?? InMemoryTokenStorage()),
      pendingCheckoutStoreProvider.overrideWithValue(
        pending ?? InMemoryPendingCheckoutStore(),
      ),
      authRepositoryProvider.overrideWithValue(auth),
      catalogRepositoryProvider.overrideWithValue(catalog),
      purchaseRepositoryProvider.overrideWithValue(purchase),
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
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }
  return container;
}
