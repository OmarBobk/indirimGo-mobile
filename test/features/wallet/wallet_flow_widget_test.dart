import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indirimgo_mobile/app.dart';
import 'package:indirimgo_mobile/core/config/app_config.dart';
import 'package:indirimgo_mobile/core/errors/api_exception.dart';
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
import '../../support/laravel_wallet_envelopes.dart';
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
    await _pumpAuthenticated(tester, wallet);

    await tester.tap(find.byKey(const Key('nav-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-wallet')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wallet-screen')), findsOneWidget);
    expect(find.byKey(const Key('wallet-screen-available')), findsOneWidget);
    expect(find.textContaining('waiting for staff approval'), findsOneWidget);
    expect(find.text(r'$42.50'), findsWidgets);

    await tester.tap(find.byKey(const Key('wallet-view-pending')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('topup-detail-status')), findsOneWidget);
    expect(find.textContaining('does not add funds yet'), findsOneWidget);
  });

  testWidgets('add funds submits entered amount without converting currency', (
    tester,
  ) async {
    final wallet = FakeWalletRepository(
      topups: TopupListPage.fromJson(topupListPageJson(items: [])),
      paymentMethods: [
        PaymentMethod.fromJson(paymentMethodJson(instructions: 'IBAN')),
      ],
    );
    await _pumpAuthenticated(tester, wallet);
    await tester.tap(find.byKey(const Key('nav-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-wallet')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wallet-add-funds')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('topup-amount-field')),
      '100.00',
    );
    await tester.tap(find.byKey(const Key('topup-currency-try')));
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

  testWidgets('populated Laravel history renders instead of empty copy', (
    tester,
  ) async {
    final wallet = FakeWalletRepository(
      summary: WalletSummary.fromJson(laravelWalletEnvelope('summary')),
      transactions: WalletTransactionPage.fromJson(
        laravelWalletEnvelope('transactions'),
      ),
      topups: TopupListPage.fromJson(laravelWalletEnvelope('topups')),
    );
    await _pumpAuthenticated(tester, wallet);
    await _openWallet(tester);

    expect(_key('wallet-topup-TUP-63C22699F0'), findsOneWidget);
    expect(_key('wallet-topup-TUP-0A8B2AF3B9'), findsOneWidget);
    expect(_key('wallet-tx-WTX-1A3DA54349'), findsOneWidget);
    expect(_key('wallet-tx-Reference pending'), findsOneWidget);
    expect(_key('wallet-topups-empty'), findsNothing);
    expect(_key('wallet-transactions-empty'), findsNothing);
    expect(find.text('This package is not available.'), findsNothing);
  });

  testWidgets('malformed activity shows retry instead of empty copy', (
    tester,
  ) async {
    final wallet = FakeWalletRepository(
      topups: TopupListPage.fromJson(laravelWalletEnvelope('topups')),
    )..transactionsError = const FormatException('ledger was truncated');
    await _pumpAuthenticated(tester, wallet);
    await _openWallet(tester);
    expect(_key('wallet-transactions-error'), findsOneWidget);
    expect(_key('wallet-retry-transactions'), findsOneWidget);
    expect(_key('wallet-transactions-empty'), findsNothing);
    expect(_key('wallet-topup-TUP-63C22699F0'), findsOneWidget);
  });

  testWidgets('genuine empty history is distinct from a failed section', (
    tester,
  ) async {
    final wallet = FakeWalletRepository(
      transactions: WalletTransactionPage.fromJson(
        laravelWalletEnvelope('empty_transactions'),
      ),
      topups: TopupListPage.fromJson(laravelWalletEnvelope('empty_topups')),
    );
    await _pumpAuthenticated(tester, wallet);
    await _openWallet(tester);

    expect(_key('wallet-topups-empty'), findsOneWidget);
    expect(_key('wallet-transactions-empty'), findsOneWidget);
    expect(_key('wallet-retry-topups'), findsNothing);
    expect(_key('wallet-retry-transactions'), findsNothing);
  });

  testWidgets('a failed top-up section shows retry without emptying activity', (
    tester,
  ) async {
    final wallet =
        FakeWalletRepository(
            transactions: WalletTransactionPage.fromJson(
              laravelWalletEnvelope('transactions'),
            ),
            topups: TopupListPage.fromJson(
              laravelWalletEnvelope('empty_topups'),
            ),
          )
          ..topupsError = const ApiException(
            kind: ApiErrorKind.notFound,
            statusCode: 404,
          );
    await _pumpAuthenticated(tester, wallet);
    await _openWallet(tester);

    expect(_key('wallet-topups-error'), findsOneWidget);
    expect(_key('wallet-retry-topups'), findsOneWidget);
    expect(_key('wallet-topups-empty'), findsNothing);
    expect(_key('wallet-tx-WTX-1A3DA54349'), findsOneWidget);
    expect(find.text('This package is not available.'), findsNothing);
    expect(
      find.text('The operation could not be completed. Try again.'),
      findsOneWidget,
    );
  });

  testWidgets('generic 404 on add funds is not package copy and can retry', (
    tester,
  ) async {
    final wallet = FakeWalletRepository()
      ..paymentMethodsError = const ApiException(
        kind: ApiErrorKind.notFound,
        statusCode: 404,
      );
    await _pumpAuthenticated(tester, wallet);
    await _openWallet(tester);
    await tester.tap(find.byKey(const Key('wallet-add-funds')));
    await tester.pumpAndSettle();

    expect(find.text('This package is not available.'), findsNothing);
    expect(_key('topup-methods-error'), findsOneWidget);
    expect(_key('topup-retry-methods'), findsOneWidget);
    expect(find.text('Payment method'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('topup-submit')))
          .onPressed,
      isNull,
    );

    wallet.paymentMethodsError = null;
    await _tapKey(tester, 'topup-retry-methods');
    expect(_key('topup-method-11'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('topup-submit')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('server and network method failures stay retryable', (
    tester,
  ) async {
    final wallet = FakeWalletRepository()
      ..paymentMethodsError = const ApiException(
        kind: ApiErrorKind.server,
        statusCode: 503,
      );
    await _pumpAuthenticated(tester, wallet);
    await _openWallet(tester);
    await tester.tap(find.byKey(const Key('wallet-add-funds')));
    await tester.pumpAndSettle();
    expect(_key('topup-retry-methods'), findsOneWidget);
    expect(find.text('This package is not available.'), findsNothing);

    wallet.paymentMethodsError = const ApiException(kind: ApiErrorKind.network);
    await _tapKey(tester, 'topup-retry-methods');
    expect(_key('topup-retry-methods'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('topup-submit')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('malformed payment methods become a recoverable error', (
    tester,
  ) async {
    final wallet = FakeWalletRepository()
      ..paymentMethodsError = const FormatException('methods were not a list');
    await _pumpAuthenticated(tester, wallet);
    await _openWallet(tester);
    await tester.tap(find.byKey(const Key('wallet-add-funds')));
    await tester.pumpAndSettle();

    expect(_key('topup-methods-error'), findsOneWidget);
    expect(find.byKey(const Key('topup-form-loading')), findsNothing);
    expect(find.text('This package is not available.'), findsNothing);
  });

  testWidgets('zero active methods disable submit and show empty guidance', (
    tester,
  ) async {
    final wallet = FakeWalletRepository(paymentMethods: []);
    await _pumpAuthenticated(tester, wallet);
    await _openWallet(tester);
    await tester.tap(find.byKey(const Key('wallet-add-funds')));
    await tester.pumpAndSettle();

    expect(_key('topup-methods-empty'), findsOneWidget);
    expect(find.text('Payment method'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('topup-submit')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('selecting between two methods submits that payment_method_id', (
    tester,
  ) async {
    final methods = [
      for (final item
          in (laravelWalletEnvelope('payment_methods')['data']! as List))
        PaymentMethod.fromJson(
          (item as Map).map((key, value) => MapEntry('$key', value)),
        ),
    ];
    final wallet = FakeWalletRepository(paymentMethods: methods);
    await _pumpAuthenticated(tester, wallet);
    await _openWallet(tester);
    await tester.tap(find.byKey(const Key('wallet-add-funds')));
    await tester.pumpAndSettle();

    expect(_key('topup-method-1'), findsOneWidget);
    expect(_key('topup-method-2'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('topup-amount-field')),
      '25.00',
    );
    await _tapKey(tester, 'topup-method-2');
    await _tapKey(tester, 'topup-submit');

    expect(wallet.lastPaymentMethodId, 2);
    expect(wallet.lastAmount, '25.00');
  });

  testWidgets('Arabic add-funds 404 is not package wording', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .localesTestValue = const [
      Locale('ar'),
    ];
    final wallet = FakeWalletRepository()
      ..paymentMethodsError = const ApiException(
        kind: ApiErrorKind.notFound,
        statusCode: 404,
      );
    await _pumpAuthenticated(tester, wallet);
    await _openWallet(tester);
    await tester.tap(find.byKey(const Key('wallet-add-funds')));
    await tester.pumpAndSettle();
    expect(find.text('هذه الباقة غير متاحة.'), findsNothing);
    expect(_key('topup-retry-methods'), findsOneWidget);
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

Future<void> _openWallet(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('nav-account')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('open-wallet')));
  await tester.pumpAndSettle();
}

Finder _key(String name) => find.byKey(Key(name), skipOffstage: false);

Future<void> _tapKey(WidgetTester tester, String name) async {
  final finder = _key(name);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
