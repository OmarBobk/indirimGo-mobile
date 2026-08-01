import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indirimgo_mobile/core/errors/api_exception.dart';
import 'package:indirimgo_mobile/core/storage/pending_checkout_store.dart';
import 'package:indirimgo_mobile/core/storage/token_storage.dart';
import 'package:indirimgo_mobile/features/auth/domain/auth_models.dart';
import 'package:indirimgo_mobile/features/auth/domain/auth_repository.dart';
import 'package:indirimgo_mobile/features/auth/presentation/auth_controller.dart';
import 'package:indirimgo_mobile/features/catalog/domain/catalog_repository.dart';
import 'package:indirimgo_mobile/features/purchase/domain/purchase_models.dart';
import 'package:indirimgo_mobile/features/purchase/domain/purchase_repository.dart';
import 'package:indirimgo_mobile/features/purchase/presentation/purchase_controllers.dart';
import 'package:indirimgo_mobile/features/wallet/domain/wallet_repository.dart';
import 'package:indirimgo_mobile/features/wallet/presentation/wallet_controllers.dart';

import '../../support/fake_catalog_repository.dart';
import '../../support/fake_purchase_repository.dart';
import '../../support/fake_wallet_repository.dart';
import '../../support/fakes.dart';
import '../../support/purchase_fixtures.dart';

void main() {
  Future<void> pump() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  Future<ProviderContainer> createContainer({
    FakePurchaseRepository? purchase,
    InMemoryPendingCheckoutStore? pending,
    MobileUser? user,
  }) async {
    final storage = InMemoryTokenStorage(sampleStoredSession());
    final auth = FakeAuthRepository(tokenStorage: storage)
      ..restoreResult = user ?? sampleUser;
    final container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(storage),
        authRepositoryProvider.overrideWithValue(auth),
        catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
        purchaseRepositoryProvider.overrideWithValue(
          purchase ?? FakePurchaseRepository(),
        ),
        walletRepositoryProvider.overrideWithValue(FakeWalletRepository()),
        pendingCheckoutStoreProvider.overrideWithValue(
          pending ?? InMemoryPendingCheckoutStore(),
        ),
      ],
    );
    addTearDown(container.dispose);
    for (var i = 0; i < 40; i++) {
      await pump();
      if (container.read(authControllerProvider).phase !=
          AuthPhase.initializing) {
        break;
      }
    }
    return container;
  }

  PurchaseDraft seedDraft(ProviderContainer container) {
    container.read(purchaseDraftControllerProvider.notifier).start(
          packageId: 42,
          packageName: 'Example Game Top-up',
          product: ProductOption.fromJson(fixedProductJson()),
          requirements: [
            PackageRequirementField.fromJson(requirementFieldJson()),
          ],
          requirementsSupported: true,
          pricesVisible: true,
        );
    container
        .read(purchaseDraftControllerProvider.notifier)
        .updateRequirementValue('id', 'player-1');
    return container.read(purchaseDraftControllerProvider).draft!;
  }

  test('draft clears on logout and customer switch', () async {
    final container = await createContainer();
    seedDraft(container);
    expect(container.read(purchaseDraftControllerProvider).draft, isNotNull);

    await container.read(authControllerProvider.notifier).logout();
    await pump();
    expect(container.read(purchaseDraftControllerProvider).draft, isNull);
  });

  test('starting a different product clears previous draft values', () async {
    final container = await createContainer();
    seedDraft(container);
    container
        .read(purchaseDraftControllerProvider.notifier)
        .updateQuantity(3);
    container.read(purchaseDraftControllerProvider.notifier).start(
          packageId: 42,
          packageName: 'Example Game Top-up',
          product: ProductOption.fromJson(customProductJson()),
          requirements: const [],
          requirementsSupported: true,
          pricesVisible: true,
        );
    final draft = container.read(purchaseDraftControllerProvider).draft!;
    expect(draft.product.id, 902);
    expect(draft.quantity, isNull);
    expect(draft.requirementValues, isEmpty);
  });

  test('local validation and successful quote navigation', () async {
    final purchase = FakePurchaseRepository();
    final container = await createContainer(purchase: purchase);
    seedDraft(container);
    container.read(purchaseDraftControllerProvider.notifier).updateQuantity(null);

    final invalid = await container
        .read(purchaseFormControllerProvider.notifier)
        .requestQuote();
    expect(invalid, isFalse);
    expect(
      container.read(purchaseFormControllerProvider).phase,
      PurchaseFormPhase.validationError,
    );

    container.read(purchaseDraftControllerProvider.notifier).updateQuantity(2);
    container
        .read(purchaseDraftControllerProvider.notifier)
        .updateRequirementValue('id', 'player-1');
    final ok = await container
        .read(purchaseFormControllerProvider.notifier)
        .requestQuote();
    expect(ok, isTrue);
    expect(purchase.quoteCalls, 1);
    expect(purchase.quoteItems.single.quantity, 2);
    expect(container.read(purchaseDraftControllerProvider).draft?.quote, isNotNull);
  });

  test('confirm persists key before request and reuses after timeout', () async {
    final pending = InMemoryPendingCheckoutStore();
    final purchase = FakePurchaseRepository()
      ..checkoutDelay = const Duration(milliseconds: 20)
      ..checkoutError = const ApiException(kind: ApiErrorKind.network);
    final container = await createContainer(
      purchase: purchase,
      pending: pending,
    );
    seedDraft(container);
    container.read(purchaseDraftControllerProvider.notifier).setQuote(
          sampleCheckoutQuote,
        );

    await container
        .read(checkoutReviewControllerProvider.notifier)
        .confirmPurchase();
    expect(pending.writeCount, 1);
    expect(pending.attempt, isNotNull);
    expect(purchase.checkoutCalls, 1);
    expect(
      container.read(checkoutReviewControllerProvider).phase,
      CheckoutReviewPhase.recoveryRequired,
    );

    purchase.checkoutError = null;
    await container
        .read(checkoutReviewControllerProvider.notifier)
        .confirmPurchase();
    expect(purchase.checkoutKeys, hasLength(2));
    expect(purchase.checkoutKeys[0], purchase.checkoutKeys[1]);
  });

  test('terminal success clears pending key and draft', () async {
    final pending = InMemoryPendingCheckoutStore();
    final purchase = FakePurchaseRepository();
    final container = await createContainer(
      purchase: purchase,
      pending: pending,
    );
    seedDraft(container);
    container.read(purchaseDraftControllerProvider.notifier).setQuote(
          sampleCheckoutQuote,
        );

    final receipt = await container
        .read(checkoutReviewControllerProvider.notifier)
        .confirmPurchase();
    expect(receipt?.orderNumber, 'ORD-2026-000001');
    expect(pending.attempt, isNull);
    expect(container.read(purchaseDraftControllerProvider).draft, isNull);
  });

  test('double confirm is prevented while in flight', () async {
    final purchase = FakePurchaseRepository()
      ..checkoutDelay = const Duration(milliseconds: 40);
    final container = await createContainer(purchase: purchase);
    seedDraft(container);
    container.read(purchaseDraftControllerProvider.notifier).setQuote(
          sampleCheckoutQuote,
        );

    final first = container
        .read(checkoutReviewControllerProvider.notifier)
        .confirmPurchase();
    final second = container
        .read(checkoutReviewControllerProvider.notifier)
        .confirmPurchase();
    await Future.wait([first, second]);
    expect(purchase.checkoutCalls, 1);
  });

  test('price_changed refreshes quote and requires reconfirmation', () async {
    final refreshed = CheckoutQuote.fromSuccessJson(
      checkoutQuoteJson(totalAmount: '25.00', fingerprint: 'quote-fingerprint-example-999999'),
    );
    final purchase = FakePurchaseRepository()
      ..checkoutError = ApiException(
        kind: ApiErrorKind.conflict,
        code: 'price_changed',
        statusCode: 409,
        details: {'current_quote': checkoutQuoteJson(totalAmount: '25.00', fingerprint: refreshed.quoteFingerprint)['data']},
      );
    final pending = InMemoryPendingCheckoutStore();
    final container = await createContainer(
      purchase: purchase,
      pending: pending,
    );
    seedDraft(container);
    container.read(purchaseDraftControllerProvider.notifier).setQuote(
          sampleCheckoutQuote,
        );

    await container
        .read(checkoutReviewControllerProvider.notifier)
        .confirmPurchase();
    expect(
      container.read(checkoutReviewControllerProvider).phase,
      CheckoutReviewPhase.priceChanged,
    );
    expect(
      container.read(purchaseDraftControllerProvider).draft?.quote?.total.amount,
      '25.00',
    );
    expect(pending.attempt, isNull);
  });

  Future<void> waitRecoveryPhase(
    ProviderContainer container,
    CheckoutRecoveryPhase phase,
  ) async {
    container.read(checkoutRecoveryControllerProvider);
    for (var i = 0; i < 40; i++) {
      await pump();
      if (container.read(checkoutRecoveryControllerProvider).phase == phase) {
        return;
      }
    }
  }

  test('startup recovery completed shows receipt and clears key', () async {
    final pending = InMemoryPendingCheckoutStore()
      ..attempt = PendingCheckoutAttempt(
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
    final container = await createContainer(
      purchase: purchase,
      pending: pending,
    );
    await waitRecoveryPhase(container, CheckoutRecoveryPhase.completed);
    expect(
      container.read(checkoutRecoveryControllerProvider).phase,
      CheckoutRecoveryPhase.completed,
    );
    expect(pending.attempt, isNull);
  });

  test('startup processing enters bounded recovery', () async {
    final pending = InMemoryPendingCheckoutStore()
      ..attempt = PendingCheckoutAttempt(
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
    final container = await createContainer(
      purchase: purchase,
      pending: pending,
    );
    await waitRecoveryPhase(container, CheckoutRecoveryPhase.processing);
    expect(
      container.read(checkoutRecoveryControllerProvider).phase,
      CheckoutRecoveryPhase.processing,
    );
    expect(pending.attempt, isNotNull);
  });

  test('startup retry-required clears key and requires restart', () async {
    final pending = InMemoryPendingCheckoutStore()
      ..attempt = PendingCheckoutAttempt(
        customerId: sampleUser.id,
        idempotencyKey: 'ig-pending',
        createdAt: DateTime.utc(2026, 8, 1),
      );
    final purchase = FakePurchaseRepository()
      ..statusError = const ApiException(
        kind: ApiErrorKind.conflict,
        code: 'checkout_retry_required',
        statusCode: 409,
      );
    final container = await createContainer(
      purchase: purchase,
      pending: pending,
    );
    await waitRecoveryPhase(
      container,
      CheckoutRecoveryPhase.retryRequiredRestart,
    );
    expect(
      container.read(checkoutRecoveryControllerProvider).phase,
      CheckoutRecoveryPhase.retryRequiredRestart,
    );
    expect(pending.attempt, isNull);
  });

  test('wrong-customer pending key is cleared', () async {
    final pending = InMemoryPendingCheckoutStore()
      ..attempt = PendingCheckoutAttempt(
        customerId: 999,
        idempotencyKey: 'ig-other',
        createdAt: DateTime.utc(2026, 8, 1),
      );
    final purchase = FakePurchaseRepository();
    final container = await createContainer(
      purchase: purchase,
      pending: pending,
    );
    container.read(checkoutRecoveryControllerProvider);
    for (var i = 0; i < 40; i++) {
      await pump();
      if (pending.attempt == null) {
        break;
      }
    }
    expect(pending.attempt, isNull);
    expect(purchase.statusCalls, 0);
  });

  test('wallet summary clears for customer switch and rejects 401', () async {
    final wallet = FakeWalletRepository();
    final storage = InMemoryTokenStorage(sampleStoredSession());
    final auth = FakeAuthRepository(tokenStorage: storage)
      ..restoreResult = sampleUser;
    final container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(storage),
        authRepositoryProvider.overrideWithValue(auth),
        catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
        purchaseRepositoryProvider.overrideWithValue(FakePurchaseRepository()),
        walletRepositoryProvider.overrideWithValue(wallet),
      ],
    );
    addTearDown(container.dispose);
    for (var i = 0; i < 40; i++) {
      await pump();
      if (container.read(authControllerProvider).phase !=
          AuthPhase.initializing) {
        break;
      }
    }
    container.read(walletSummaryControllerProvider);
    for (var i = 0; i < 20; i++) {
      await pump();
      if (container.read(walletSummaryControllerProvider).phase ==
          WalletLoadPhase.ready) {
        break;
      }
    }
    expect(wallet.summaryCalls, greaterThan(0));

    wallet.summaryError = unauthorizedRejection(storage.session!.reference);
    await container.read(walletSummaryControllerProvider.notifier).refresh();
    await pump();
    expect(
      container.read(authControllerProvider).phase,
      AuthPhase.unauthenticated,
    );
  });
}
