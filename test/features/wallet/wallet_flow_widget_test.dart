import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indirimgo_mobile/app.dart';
import 'package:indirimgo_mobile/core/config/app_config.dart';
import 'package:indirimgo_mobile/core/routing/app_router.dart';
import 'package:indirimgo_mobile/core/storage/locale_preference_store.dart';
import 'package:indirimgo_mobile/core/storage/pending_checkout_store.dart';
import 'package:indirimgo_mobile/core/storage/pending_topup_store.dart';
import 'package:indirimgo_mobile/core/storage/token_storage.dart';
import 'package:indirimgo_mobile/features/auth/domain/auth_repository.dart';
import 'package:indirimgo_mobile/features/catalog/domain/catalog_repository.dart';
import 'package:indirimgo_mobile/features/orders/domain/order_repository.dart';
import 'package:indirimgo_mobile/features/purchase/domain/purchase_repository.dart';
import 'package:indirimgo_mobile/features/wallet/domain/wallet_models.dart';
import 'package:indirimgo_mobile/features/wallet/domain/wallet_repository.dart';

import '../../support/fake_catalog_repository.dart';
import '../../support/fake_order_repository.dart';
import '../../support/fake_purchase_repository.dart';
import '../../support/fake_wallet_repository.dart';
import '../../support/fakes.dart';
import '../../support/wallet_fixtures.dart';

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

  testWidgets('account opens wallet and shows pending versus credited funds', (
    tester,
  ) async {
    final wallet = FakeWalletRepository(
      summary: WalletSummary.fromJson(
        walletSummaryJson(pendingTopupPublicRef: 'TUP-ABC123'),
      ),
      transactions: sampleTransactionPage(),
      topups: sampleTopupPage(pendingTopupPublicRef: 'TUP-ABC123'),
    )..details['TUP-ABC123'] = samplePendingTopup();
    final container = await _pumpAuthenticated(tester, wallet);

    await tester.tap(find.byKey(const Key('nav-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-wallet')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wallet-screen')), findsOneWidget);
    expect(find.byKey(const Key('wallet-screen-available')), findsOneWidget);
    expect(find.textContaining('waiting for staff approval'), findsOneWidget);
    expect(find.text(r'$42.50'), findsWidgets);

    await tester.tap(find.byKey(const Key('wallet-topup-TUP-ABC123')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('topup-detail-status')), findsOneWidget);
    expect(find.textContaining('does not add funds yet'), findsOneWidget);
  });

  testWidgets('add funds submits entered amount without converting currency', (
    tester,
  ) async {
    final wallet = FakeWalletRepository(
      transactions: sampleTransactionPage(lastPage: 1),
      topups: TopupListPage.fromJson(topupListPageJson(items: [])),
    );
    final container = await _pumpAuthenticated(tester, wallet);
    container.read(routerProvider).go(AppRoutes.walletTopup);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('topup-amount-field')),
      '100.00',
    );
    await tester.tap(find.text('TRY'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('topup-submit')));
    await tester.pumpAndSettle();

    expect(wallet.lastAmount, '100.00');
    expect(wallet.lastCurrency, 'TRY');
    expect(find.byKey(const Key('topup-detail-screen')), findsOneWidget);
    expect(find.textContaining('Waiting for approval'), findsOneWidget);
  });

  testWidgets('Arabic wallet keeps money and TUP refs LTR', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .localesTestValue = const [
      Locale('ar'),
    ];
    final wallet = FakeWalletRepository(
      transactions: sampleTransactionPage(),
      topups: sampleTopupPage(),
    );
    final container = await _pumpAuthenticated(tester, wallet);
    container.read(routerProvider).go(AppRoutes.wallet);
    await tester.pumpAndSettle();

    final refText = tester.widget<Text>(find.text('TUP-ABC123').first);
    expect(refText.textDirection, TextDirection.ltr);
    final money = tester.widget<Text>(find.text(r'$25.00').first);
    expect(money.textDirection, TextDirection.ltr);
  });
}

Future<ProviderContainer> _pumpAuthenticated(
  WidgetTester tester,
  FakeWalletRepository wallet,
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
      pendingTopupStoreProvider.overrideWithValue(InMemoryPendingTopupStore()),
      localePreferenceStoreProvider.overrideWithValue(
        InMemoryLocalePreferenceStore(),
      ),
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(tokenStorage: storage)..restoreResult = sampleUser,
      ),
      catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
      purchaseRepositoryProvider.overrideWithValue(FakePurchaseRepository()),
      walletRepositoryProvider.overrideWithValue(wallet),
      orderRepositoryProvider.overrideWithValue(FakeOrderRepository()),
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
