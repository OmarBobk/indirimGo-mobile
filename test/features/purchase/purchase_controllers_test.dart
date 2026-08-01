import 'dart:async';

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

  Future<({ProviderContainer container, FakeAuthRepository auth})>
  createContainer({
    FakePurchaseRepository? purchase,
    InMemoryPendingCheckoutStore? pending,
    MobileUser? user,
    FakeAuthRepository? authRepository,
    InMemoryTokenStorage? storage,
  }) async {
    final tokenStorage = storage ?? InMemoryTokenStorage(sampleStoredSession());
    final auth =
        authRepository ??
        (FakeAuthRepository(tokenStorage: tokenStorage)
          ..restoreResult = user ?? sampleUser);
    final container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(tokenStorage),
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
    return (container: container, auth: auth);
  }

  PurchaseDraft seedDraft(ProviderContainer container) {
    container
        .read(purchaseDraftControllerProvider.notifier)
        .start(
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

  test('draft clears on logout and customer switch', () async {
    final env = await createContainer();
    seedDraft(env.container);
    expect(
      env.container.read(purchaseDraftControllerProvider).draft,
      isNotNull,
    );

    await env.container.read(authControllerProvider.notifier).logout();
    await pump();
    expect(env.container.read(purchaseDraftControllerProvider).draft, isNull);
  });

  test('starting a different product clears previous draft values', () async {
    final env = await createContainer();
    seedDraft(env.container);
    env.container
        .read(purchaseDraftControllerProvider.notifier)
        .updateQuantity(3);
    env.container
        .read(purchaseDraftControllerProvider.notifier)
        .start(
          packageId: 42,
          packageName: 'Example Game Top-up',
          product: ProductOption.fromJson(customProductJson()),
          requirements: const [],
          requirementsSupported: true,
          pricesVisible: true,
        );
    final draft = env.container.read(purchaseDraftControllerProvider).draft!;
    expect(draft.product.id, 902);
    expect(draft.quantity, isNull);
    expect(draft.requirementValues, isEmpty);
  });

  test('local validation and successful quote navigation', () async {
    final purchase = FakePurchaseRepository();
    final env = await createContainer(purchase: purchase);
    seedDraft(env.container);
    env.container
        .read(purchaseDraftControllerProvider.notifier)
        .updateQuantity(null);

    final invalid = await env.container
        .read(purchaseFormControllerProvider.notifier)
        .requestQuote();
    expect(invalid, isFalse);
    expect(
      env.container.read(purchaseFormControllerProvider).phase,
      PurchaseFormPhase.validationError,
    );

    env.container
        .read(purchaseDraftControllerProvider.notifier)
        .updateQuantity(2);
    env.container
        .read(purchaseDraftControllerProvider.notifier)
        .updateRequirementValue('id', 'player-1');
    final ok = await env.container
        .read(purchaseFormControllerProvider.notifier)
        .requestQuote();
    expect(ok, isTrue);
    expect(purchase.quoteCalls, 1);
    expect(purchase.quoteItems.single.quantity, 2);
    expect(
      env.container.read(purchaseDraftControllerProvider).draft?.quote,
      isNotNull,
    );
  });

  test(
    'confirm persists key before request; recovery owns unknown result',
    () async {
      final pending = InMemoryPendingCheckoutStore();
      final purchase = FakePurchaseRepository()
        ..checkoutDelay = const Duration(milliseconds: 20)
        ..checkoutError = const ApiException(kind: ApiErrorKind.network);
      final env = await createContainer(purchase: purchase, pending: pending);
      seedDraft(env.container);
      env.container
          .read(purchaseDraftControllerProvider.notifier)
          .setQuote(sampleCheckoutQuote);
      await env.container
          .read(checkoutReviewControllerProvider.notifier)
          .ensureFreshQuote();

      await env.container
          .read(checkoutReviewControllerProvider.notifier)
          .confirmPurchase();
      expect(pending.writeCount, greaterThanOrEqualTo(1));
      expect(
        (await pending.readForCustomer(sampleUser.id))?.hasUnresolvedKey,
        isTrue,
      );
      expect(purchase.checkoutCalls, 1);
      expect(
        env.container.read(checkoutReviewControllerProvider).phase,
        CheckoutReviewPhase.recoveryRequired,
      );

      // Confirm disabled while recovery owns the attempt.
      purchase.checkoutError = null;
      await env.container
          .read(checkoutReviewControllerProvider.notifier)
          .confirmPurchase();
      expect(purchase.checkoutCalls, 1);
    },
  );

  test(
    'durable success writes anchor before key removal and keeps receipt state',
    () async {
      final pending = InMemoryPendingCheckoutStore();
      final purchase = FakePurchaseRepository();
      final env = await createContainer(purchase: purchase, pending: pending);
      seedDraft(env.container);
      env.container
          .read(purchaseDraftControllerProvider.notifier)
          .setQuote(sampleCheckoutQuote);
      await env.container
          .read(checkoutReviewControllerProvider.notifier)
          .ensureFreshQuote();

      final receipt = await env.container
          .read(checkoutReviewControllerProvider.notifier)
          .confirmPurchase();
      expect(receipt?.orderNumber, 'ORD-2026-000001');
      expect(
        env.container.read(checkoutReviewControllerProvider).phase,
        CheckoutReviewPhase.success,
      );
      expect(
        env.container
            .read(checkoutReviewControllerProvider)
            .receipt
            ?.orderNumber,
        'ORD-2026-000001',
      );
      expect(env.container.read(purchaseDraftControllerProvider).draft, isNull);

      final record = await pending.readForCustomer(sampleUser.id);
      expect(record?.hasCompletedAnchor, isTrue);
      expect(record?.hasUnresolvedKey, isFalse);
      expect(record?.completedOrderNumber, 'ORD-2026-000001');
      final completedAt = pending.writeOps.indexOf('completed:ORD-2026-000001');
      final clearKeyAt = pending.writeOps.indexOf('clearKey');
      expect(completedAt, greaterThanOrEqualTo(0));
      expect(clearKeyAt, greaterThan(completedAt));
    },
  );

  test('double confirm is prevented while in flight', () async {
    final purchase = FakePurchaseRepository()
      ..checkoutDelay = const Duration(milliseconds: 40);
    final env = await createContainer(purchase: purchase);
    seedDraft(env.container);
    env.container
        .read(purchaseDraftControllerProvider.notifier)
        .setQuote(sampleCheckoutQuote);
    await env.container
        .read(checkoutReviewControllerProvider.notifier)
        .ensureFreshQuote();

    final first = env.container
        .read(checkoutReviewControllerProvider.notifier)
        .confirmPurchase();
    final second = env.container
        .read(checkoutReviewControllerProvider.notifier)
        .confirmPurchase();
    await Future.wait([first, second]);
    expect(purchase.checkoutCalls, 1);
  });

  test('price_changed refreshes quote and requires reconfirmation', () async {
    final refreshed = CheckoutQuote.fromSuccessJson(
      checkoutQuoteJson(
        totalAmount: '25.00',
        fingerprint: 'quote-fingerprint-example-999999',
      ),
    );
    final purchase = FakePurchaseRepository()
      ..checkoutError = ApiException(
        kind: ApiErrorKind.conflict,
        code: 'price_changed',
        statusCode: 409,
        details: {
          'current_quote': checkoutQuoteJson(
            totalAmount: '25.00',
            fingerprint: refreshed.quoteFingerprint,
          )['data'],
        },
      );
    final pending = InMemoryPendingCheckoutStore();
    final env = await createContainer(purchase: purchase, pending: pending);
    seedDraft(env.container);
    env.container
        .read(purchaseDraftControllerProvider.notifier)
        .setQuote(sampleCheckoutQuote);
    await env.container
        .read(checkoutReviewControllerProvider.notifier)
        .ensureFreshQuote();

    await env.container
        .read(checkoutReviewControllerProvider.notifier)
        .confirmPurchase();
    expect(
      env.container.read(checkoutReviewControllerProvider).phase,
      CheckoutReviewPhase.priceChanged,
    );
    expect(
      env.container
          .read(purchaseDraftControllerProvider)
          .draft
          ?.quote
          ?.total
          .amount,
      '25.00',
    );
    expect(await pending.readForCustomer(sampleUser.id), isNull);
    expect(
      isCheckoutConfirmEnabled(
        quote: env.container.read(purchaseDraftControllerProvider).draft?.quote,
        review: env.container.read(checkoutReviewControllerProvider),
      ),
      isTrue,
    );
  });

  test(
    'startup recovery completed keeps anchor until acknowledgement',
    () async {
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
      final env = await createContainer(purchase: purchase, pending: pending);
      await waitRecoveryPhase(env.container, CheckoutRecoveryPhase.completed);
      expect(
        env.container.read(checkoutRecoveryControllerProvider).phase,
        CheckoutRecoveryPhase.completed,
      );
      final record = await pending.readForCustomer(sampleUser.id);
      expect(record?.hasCompletedAnchor, isTrue);
      expect(record?.hasUnresolvedKey, isFalse);
      final completedAt = pending.writeOps.indexOf('completed:ORD-2026-000001');
      final clearKeyAt = pending.writeOps.indexOf('clearKey');
      expect(clearKeyAt, greaterThan(completedAt));

      await env.container
          .read(checkoutRecoveryControllerProvider.notifier)
          .acknowledgeCompletedReceipt();
      expect(await pending.readForCustomer(sampleUser.id), isNull);
    },
  );

  test('startup processing enters bounded recovery', () async {
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
    final env = await createContainer(purchase: purchase, pending: pending);
    await waitRecoveryPhase(env.container, CheckoutRecoveryPhase.processing);
    expect(
      env.container.read(checkoutRecoveryControllerProvider).phase,
      CheckoutRecoveryPhase.processing,
    );
    expect(
      (await pending.readForCustomer(sampleUser.id))?.hasUnresolvedKey,
      isTrue,
    );
  });

  test('startup retry-required clears key and requires restart', () async {
    final pending = InMemoryPendingCheckoutStore()
      ..attempt = CheckoutRecoveryRecord(
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
    final env = await createContainer(purchase: purchase, pending: pending);
    await waitRecoveryPhase(
      env.container,
      CheckoutRecoveryPhase.retryRequiredRestart,
    );
    expect(
      env.container.read(checkoutRecoveryControllerProvider).phase,
      CheckoutRecoveryPhase.retryRequiredRestart,
    );
    expect(await pending.readForCustomer(sampleUser.id), isNull);
  });

  test('other-customer pending key is preserved for that customer', () async {
    final pending = InMemoryPendingCheckoutStore()
      ..attempt = CheckoutRecoveryRecord(
        customerId: 999,
        idempotencyKey: 'ig-other',
        createdAt: DateTime.utc(2026, 8, 1),
      );
    final purchase = FakePurchaseRepository();
    final env = await createContainer(purchase: purchase, pending: pending);
    env.container.read(checkoutRecoveryControllerProvider);
    for (var i = 0; i < 40; i++) {
      await pump();
    }
    expect((await pending.readForCustomer(999))?.idempotencyKey, 'ig-other');
    expect(purchase.statusCalls, 0);
  });

  test('A pending unknown survives login as B and returns for A', () async {
    final pending = InMemoryPendingCheckoutStore();
    await pending.writeUnresolved(
      customerId: sampleUser.id,
      idempotencyKey: 'ig-a-pending',
      createdAt: DateTime.utc(2026, 8, 1),
    );
    await pending.writeUnresolved(
      customerId: sampleUserB.id,
      idempotencyKey: 'ig-b-pending',
      createdAt: DateTime.utc(2026, 8, 1),
    );
    final purchase = FakePurchaseRepository(
      status: CheckoutStatus.fromResponse(
        statusCode: 202,
        json: checkoutStatusProcessingJson(),
      ),
    );
    final storage = InMemoryTokenStorage(sampleStoredSession());
    final auth = FakeAuthRepository(tokenStorage: storage)
      ..restoreResult = sampleUser;
    final env = await createContainer(
      purchase: purchase,
      pending: pending,
      authRepository: auth,
      storage: storage,
    );
    await waitRecoveryPhase(env.container, CheckoutRecoveryPhase.processing);

    await env.container.read(authControllerProvider.notifier).logout();
    await pump();
    auth.loginHandler = (username, password) async =>
        LoginAuthenticated(sampleSessionB);
    await env.container
        .read(authControllerProvider.notifier)
        .login(username: 'other', password: 'secret');
    for (var i = 0; i < 40; i++) {
      await pump();
      if (env.container.read(authControllerProvider).user?.id ==
          sampleUserB.id) {
        break;
      }
    }
    expect(
      (await pending.readForCustomer(sampleUser.id))?.idempotencyKey,
      'ig-a-pending',
    );
    expect(
      (await pending.readForCustomer(sampleUserB.id))?.idempotencyKey,
      'ig-b-pending',
    );

    await env.container.read(authControllerProvider.notifier).logout();
    await pump();
    auth.loginHandler = (username, password) async =>
        LoginAuthenticated(sampleSession);
    await env.container
        .read(authControllerProvider.notifier)
        .login(username: 'omar', password: 'secret');
    for (var i = 0; i < 40; i++) {
      await pump();
      if (env.container.read(authControllerProvider).user?.id ==
          sampleUser.id) {
        break;
      }
    }
    await waitRecoveryPhase(env.container, CheckoutRecoveryPhase.processing);
    expect(
      (await pending.readForCustomer(sampleUser.id))?.idempotencyKey,
      'ig-a-pending',
    );
  });

  test(
    'delayed A success while B active anchors A without affecting B',
    () async {
      final pending = InMemoryPendingCheckoutStore();
      final completer = Completer<CheckoutResult>();
      final purchase = FakePurchaseRepository()
        ..checkoutHandler =
            ({
              required CheckoutLineItemRequest item,
              required String quoteFingerprint,
              required String idempotencyKey,
            }) => completer.future;
      final storage = InMemoryTokenStorage(sampleStoredSession());
      final auth = FakeAuthRepository(tokenStorage: storage)
        ..restoreResult = sampleUser;
      final env = await createContainer(
        purchase: purchase,
        pending: pending,
        authRepository: auth,
        storage: storage,
      );
      seedDraft(env.container);
      env.container
          .read(purchaseDraftControllerProvider.notifier)
          .setQuote(sampleCheckoutQuote);
      await env.container
          .read(checkoutReviewControllerProvider.notifier)
          .ensureFreshQuote();

      final confirmFuture = env.container
          .read(checkoutReviewControllerProvider.notifier)
          .confirmPurchase();

      for (var i = 0; i < 20; i++) {
        await pump();
        if ((await pending.readForCustomer(sampleUser.id))?.hasUnresolvedKey ==
            true) {
          break;
        }
      }

      await env.container.read(authControllerProvider.notifier).logout();
      await pump();
      auth.loginHandler = (username, password) async =>
          LoginAuthenticated(sampleSessionB);
      await env.container
          .read(authControllerProvider.notifier)
          .login(username: 'other', password: 'secret');
      for (var i = 0; i < 40; i++) {
        await pump();
        if (env.container.read(authControllerProvider).user?.id ==
            sampleUserB.id) {
          break;
        }
      }

      completer.complete(sampleCheckoutResult);
      await confirmFuture;
      await pump();

      expect(
        env.container.read(checkoutReviewControllerProvider).phase,
        isNot(CheckoutReviewPhase.success),
      );
      expect(env.container.read(purchaseDraftControllerProvider).draft, isNull);
      final aRecord = await pending.readForCustomer(sampleUser.id);
      expect(aRecord?.completedOrderNumber, 'ORD-2026-000001');
      expect(aRecord?.hasUnresolvedKey, isFalse);
      expect(await pending.readForCustomer(sampleUserB.id), isNull);
    },
  );

  test('returning to A recovers completed receipt from anchor', () async {
    final pending = InMemoryPendingCheckoutStore();
    await pending.markCompleted(
      customerId: sampleUser.id,
      orderNumber: 'ORD-2026-000001',
    );
    final purchase = FakePurchaseRepository();
    final env = await createContainer(purchase: purchase, pending: pending);
    await waitRecoveryPhase(env.container, CheckoutRecoveryPhase.completed);
    expect(
      env.container
          .read(checkoutRecoveryControllerProvider)
          .receipt
          ?.orderNumber,
      'ORD-2026-000001',
    );
    expect(purchase.orderCalls, greaterThan(0));
    expect(
      (await pending.readForCustomer(sampleUser.id))?.hasCompletedAnchor,
      isTrue,
    );
  });

  test(
    'null in-memory key reuses stored pending key after notifier recreate',
    () async {
      final pending = InMemoryPendingCheckoutStore();
      final purchase = FakePurchaseRepository();
      final env = await createContainer(purchase: purchase, pending: pending);
      // Let startup recovery settle with an empty store first.
      for (var i = 0; i < 20; i++) {
        await pump();
        if (env.container.read(checkoutRecoveryControllerProvider).phase ==
            CheckoutRecoveryPhase.idle) {
          break;
        }
      }
      seedDraft(env.container);
      env.container
          .read(purchaseDraftControllerProvider.notifier)
          .setQuote(sampleCheckoutQuote);
      await env.container
          .read(checkoutReviewControllerProvider.notifier)
          .ensureFreshQuote();
      expect(
        env.container.read(checkoutReviewControllerProvider).phase,
        CheckoutReviewPhase.ready,
      );

      await pending.writeUnresolved(
        customerId: sampleUser.id,
        idempotencyKey: 'ig-stored-reuse',
        createdAt: DateTime.utc(2026, 8, 1),
      );

      // Simulate in-memory key loss (e.g. notifier recreation) while the durable
      // unresolved key remains for this customer.
      env.container
          .read(checkoutReviewControllerProvider.notifier)
          .debugClearActiveIdempotencyKey();
      expect(
        (await pending.readForCustomer(sampleUser.id))?.idempotencyKey,
        'ig-stored-reuse',
      );

      final receipt = await env.container
          .read(checkoutReviewControllerProvider.notifier)
          .confirmPurchase();
      expect(receipt?.orderNumber, 'ORD-2026-000001');
      expect(purchase.checkoutKeys, ['ig-stored-reuse']);
    },
  );

  test('existing completed anchor prevents a new checkout POST', () async {
    final pending = InMemoryPendingCheckoutStore();
    await pending.markCompleted(
      customerId: sampleUser.id,
      orderNumber: 'ORD-2026-000001',
    );
    final purchase = FakePurchaseRepository();
    final env = await createContainer(purchase: purchase, pending: pending);
    seedDraft(env.container);
    env.container
        .read(purchaseDraftControllerProvider.notifier)
        .setQuote(sampleCheckoutQuote);
    await env.container
        .read(checkoutReviewControllerProvider.notifier)
        .ensureFreshQuote();

    final receipt = await env.container
        .read(checkoutReviewControllerProvider.notifier)
        .confirmPurchase();
    expect(receipt?.orderNumber, 'ORD-2026-000001');
    expect(purchase.checkoutCalls, 0);
    expect(purchase.orderCalls, greaterThan(0));
    expect(
      env.container.read(checkoutReviewControllerProvider).phase,
      CheckoutReviewPhase.success,
    );
  });

  test('confirm allowlist permits ready/priceChanged/retry only', () {
    final quote = sampleCheckoutQuote;
    const ready = CheckoutReviewState(phase: CheckoutReviewPhase.ready);
    expect(isCheckoutConfirmEnabled(quote: quote, review: ready), isTrue);
    expect(
      isCheckoutConfirmEnabled(
        quote: quote,
        review: const CheckoutReviewState(
          phase: CheckoutReviewPhase.priceChanged,
        ),
      ),
      isTrue,
    );
    expect(
      isCheckoutConfirmEnabled(
        quote: quote,
        review: const CheckoutReviewState(
          phase: CheckoutReviewPhase.error,
          error: ApiException(
            kind: ApiErrorKind.conflict,
            code: 'checkout_retry_required',
          ),
        ),
      ),
      isTrue,
    );

    for (final phase in [
      CheckoutReviewPhase.submitting,
      CheckoutReviewPhase.refreshingQuote,
      CheckoutReviewPhase.insufficientBalance,
      CheckoutReviewPhase.recoveryRequired,
      CheckoutReviewPhase.success,
      CheckoutReviewPhase.unavailable,
      CheckoutReviewPhase.restartRequired,
      CheckoutReviewPhase.idle,
    ]) {
      expect(
        isCheckoutConfirmEnabled(
          quote: quote,
          review: CheckoutReviewState(phase: phase),
        ),
        isFalse,
        reason: '$phase must disable confirm',
      );
    }

    final unaffordable = CheckoutQuote.fromSuccessJson(
      checkoutQuoteJson(canAfford: false),
    );
    expect(
      isCheckoutConfirmEnabled(quote: unaffordable, review: ready),
      isFalse,
    );
  });

  test('offline completed-anchor reload retains the anchor', () async {
    final pending = InMemoryPendingCheckoutStore();
    await pending.markCompleted(
      customerId: sampleUser.id,
      orderNumber: 'ORD-2026-000001',
    );
    final purchase = FakePurchaseRepository()
      ..orderError = const ApiException(kind: ApiErrorKind.network);
    final env = await createContainer(purchase: purchase, pending: pending);
    await waitRecoveryPhase(env.container, CheckoutRecoveryPhase.error);
    expect(
      (await pending.readForCustomer(sampleUser.id))?.completedOrderNumber,
      'ORD-2026-000001',
    );
  });

  test('restart crash windows with completed anchor reach receipt', () async {
    final pending = InMemoryPendingCheckoutStore();
    // Crash after markCompleted, before clearPendingKey: key + anchor.
    await pending.writeUnresolved(
      customerId: sampleUser.id,
      idempotencyKey: 'ig-crash',
      createdAt: DateTime.utc(2026, 8, 1),
    );
    await pending.markCompleted(
      customerId: sampleUser.id,
      orderNumber: 'ORD-2026-000001',
    );
    final purchase = FakePurchaseRepository();
    final env = await createContainer(purchase: purchase, pending: pending);
    await waitRecoveryPhase(env.container, CheckoutRecoveryPhase.completed);
    expect(
      env.container
          .read(checkoutRecoveryControllerProvider)
          .receipt
          ?.orderNumber,
      'ORD-2026-000001',
    );

    // Crash after clearPendingKey, before navigation: anchor only.
    final pending2 = InMemoryPendingCheckoutStore();
    await pending2.markCompleted(
      customerId: sampleUser.id,
      orderNumber: 'ORD-2026-000001',
    );
    await pending2.clearPendingKey(sampleUser.id);
    final purchase2 = FakePurchaseRepository();
    final env2 = await createContainer(purchase: purchase2, pending: pending2);
    await waitRecoveryPhase(env2.container, CheckoutRecoveryPhase.completed);
    expect(
      env2.container
          .read(checkoutRecoveryControllerProvider)
          .receipt
          ?.orderNumber,
      'ORD-2026-000001',
    );
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
