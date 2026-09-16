import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indirimgo_mobile/core/errors/api_exception.dart';
import 'package:indirimgo_mobile/core/storage/pending_checkout_store.dart';
import 'package:indirimgo_mobile/core/storage/pending_topup_store.dart';
import 'package:indirimgo_mobile/core/storage/token_storage.dart';
import 'package:indirimgo_mobile/features/auth/domain/auth_models.dart';
import 'package:indirimgo_mobile/features/auth/domain/auth_repository.dart';
import 'package:indirimgo_mobile/features/auth/presentation/auth_controller.dart';
import 'package:indirimgo_mobile/features/catalog/domain/catalog_repository.dart';
import 'package:indirimgo_mobile/features/purchase/domain/purchase_repository.dart';
import 'package:indirimgo_mobile/features/wallet/domain/wallet_models.dart';
import 'package:indirimgo_mobile/features/wallet/domain/wallet_repository.dart';
import 'package:indirimgo_mobile/features/wallet/presentation/topup_form_controller.dart';
import 'package:indirimgo_mobile/features/wallet/presentation/wallet_controllers.dart';
import 'package:indirimgo_mobile/features/wallet/presentation/wallet_workspace_controller.dart';

import '../../support/fake_catalog_repository.dart';
import '../../support/fake_purchase_repository.dart';
import '../../support/fake_wallet_repository.dart';
import '../../support/fakes.dart';
import '../../support/wallet_fixtures.dart';

void main() {
  Future<void> pump([int cycles = 6]) async {
    for (var i = 0; i < cycles; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<
    ({
      ProviderContainer container,
      FakeAuthRepository auth,
      FakeWalletRepository wallet,
      InMemoryPendingTopupStore topups,
      InMemoryPendingCheckoutStore checkout,
    })
  >
  createContainer({
    FakeWalletRepository? wallet,
    InMemoryPendingTopupStore? topups,
    MobileUser? user,
  }) async {
    final storage = InMemoryTokenStorage(sampleStoredSession());
    final auth = FakeAuthRepository(tokenStorage: storage)
      ..restoreResult = user ?? sampleUser;
    final pendingTopups = topups ?? InMemoryPendingTopupStore();
    final pendingCheckout = InMemoryPendingCheckoutStore();
    final fakeWallet = wallet ?? FakeWalletRepository();
    final container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(storage),
        authRepositoryProvider.overrideWithValue(auth),
        catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
        purchaseRepositoryProvider.overrideWithValue(FakePurchaseRepository()),
        walletRepositoryProvider.overrideWithValue(fakeWallet),
        pendingTopupStoreProvider.overrideWithValue(pendingTopups),
        pendingCheckoutStoreProvider.overrideWithValue(pendingCheckout),
      ],
    );
    addTearDown(container.dispose);
    for (var i = 0; i < 40; i++) {
      await pump();
      if (container.read(authControllerProvider).phase ==
          AuthPhase.authenticated) {
        break;
      }
    }
    return (
      container: container,
      auth: auth,
      wallet: fakeWallet,
      topups: pendingTopups,
      checkout: pendingCheckout,
    );
  }

  test('workspace loads history and retains it on refresh failure', () async {
    final wallet = FakeWalletRepository(
      transactions: sampleTransactionPage(),
      topups: sampleTopupPage(pendingTopupPublicRef: 'TUP-ABC123'),
    );
    final env = await createContainer(wallet: wallet);
    env.container.read(walletWorkspaceControllerProvider);
    await pump();
    expect(
      env.container.read(walletWorkspaceControllerProvider).topups,
      hasLength(1),
    );

    wallet.transactionsError = const ApiException(kind: ApiErrorKind.network);
    await env.container
        .read(walletWorkspaceControllerProvider.notifier)
        .refresh();
    final state = env.container.read(walletWorkspaceControllerProvider);
    expect(state.phase, WalletListPhase.error);
    expect(state.topups.single.publicRef, 'TUP-ABC123');
    expect(
      env.container.read(authControllerProvider).phase,
      AuthPhase.authenticated,
    );
  });

  test('submit sends entered currency and does not credit locally', () async {
    final wallet = FakeWalletRepository();
    final env = await createContainer(wallet: wallet);
    final sub = env.container.listen(
      topupFormControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);
    await pump();
    env.container
        .read(topupFormControllerProvider.notifier)
        .setAmount('100.00');
    env.container.read(topupFormControllerProvider.notifier).setCurrency('TRY');
    final submitted = await env.container
        .read(topupFormControllerProvider.notifier)
        .submit();
    expect(wallet.lastAmount, '100.00');
    expect(wallet.lastCurrency, 'TRY');
    expect(submitted?.credited, isFalse);
    expect(submitted?.pendingUntilAdminApproval, isTrue);
    expect(
      env.container
          .read(walletSummaryControllerProvider)
          .summary
          ?.availableToSpend
          .amount,
      '42.50',
    );
    expect(await env.topups.readForCustomer(7), isNull);
    expect(await env.checkout.readForCustomer(7), isNull);
  });

  test(
    'duplicate in-flight submit is ignored and pending error is kept',
    () async {
      final wallet = FakeWalletRepository()
        ..submitDelay = const Duration(milliseconds: 20);
      final env = await createContainer(wallet: wallet);
      final sub = env.container.listen(
        topupFormControllerProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);
      for (var i = 0; i < 40; i++) {
        await pump();
        if (env.container.read(topupFormControllerProvider).phase ==
            TopupFormPhase.ready) {
          break;
        }
      }
      env.container
          .read(topupFormControllerProvider.notifier)
          .setAmount('25.00');
      final first = env.container
          .read(topupFormControllerProvider.notifier)
          .submit();
      final second = env.container
          .read(topupFormControllerProvider.notifier)
          .submit();
      await Future.wait([first, second]);
      expect(wallet.submitCalls, 1);

      wallet
        ..submitDelay = null
        ..submitError = const ApiException(
          kind: ApiErrorKind.validation,
          code: 'topup_request_pending',
        );
      env.container
          .read(topupFormControllerProvider.notifier)
          .setAmount('25.00');
      await env.container.read(topupFormControllerProvider.notifier).submit();
      final state = env.container.read(topupFormControllerProvider);
      expect(state.amount, '25.00');
      expect(state.error?.code, 'topup_request_pending');
    },
  );

  test('lost response recovers with the stored request identity', () async {
    final store = InMemoryPendingTopupStore();
    await store.writeUnresolved(
      customerId: 7,
      idempotencyKey: 'ig-lost-key',
      createdAt: DateTime.utc(2026, 9, 1),
    );
    final wallet = FakeWalletRepository()
      ..statusResult = TopupStatusResult.fromResponse(
        statusCode: 200,
        json: topupStatusCompletedJson(),
      );
    final env = await createContainer(wallet: wallet, topups: store);
    final sub = env.container.listen(
      topupFormControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);
    await pump(20);
    expect(wallet.lastStatusKey, 'ig-lost-key');
    expect(
      env.container.read(topupFormControllerProvider).phase,
      TopupFormPhase.submitted,
    );
    expect(await store.readForCustomer(7), isNull);
  });

  test('logout clears in-memory wallet history for the session', () async {
    final wallet = FakeWalletRepository(transactions: sampleTransactionPage());
    final env = await createContainer(wallet: wallet);
    env.container.read(walletWorkspaceControllerProvider);
    await pump();
    expect(
      env.container.read(walletWorkspaceControllerProvider).transactions,
      isNotEmpty,
    );

    await env.container.read(authControllerProvider.notifier).logout();
    await pump();
    expect(
      env.container.read(walletWorkspaceControllerProvider).customerId,
      isNull,
    );
    expect(
      env.container.read(walletWorkspaceControllerProvider).transactions,
      isEmpty,
    );

    env.auth.loginHandler = (_, _) async => LoginAuthenticated(sampleSessionB);
    await env.container
        .read(authControllerProvider.notifier)
        .login(username: 'other', password: 'ignored');
    await pump(20);
    expect(env.container.read(walletWorkspaceControllerProvider).customerId, 8);
  });
}
