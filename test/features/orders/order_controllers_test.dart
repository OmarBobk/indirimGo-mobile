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
import 'package:indirimgo_mobile/features/orders/domain/order_models.dart';
import 'package:indirimgo_mobile/features/orders/domain/order_repository.dart';
import 'package:indirimgo_mobile/features/orders/presentation/order_controllers.dart';
import 'package:indirimgo_mobile/features/purchase/domain/purchase_models.dart';
import 'package:indirimgo_mobile/features/purchase/domain/purchase_repository.dart';
import 'package:indirimgo_mobile/features/wallet/domain/wallet_repository.dart';

import '../../support/fake_catalog_repository.dart';
import '../../support/fake_order_repository.dart';
import '../../support/fake_purchase_repository.dart';
import '../../support/fake_wallet_repository.dart';
import '../../support/fakes.dart';
import '../../support/order_fixtures.dart';

void main() {
  Future<void> pump([int cycles = 4]) async {
    for (var i = 0; i < cycles; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<
    ({
      ProviderContainer container,
      FakeAuthRepository auth,
      InMemoryPendingCheckoutStore pending,
    })
  >
  createContainer(FakeOrderRepository orders) async {
    final storage = InMemoryTokenStorage(sampleStoredSession());
    final auth = FakeAuthRepository(tokenStorage: storage)
      ..restoreResult = sampleUser;
    final pending = InMemoryPendingCheckoutStore();
    final container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(storage),
        authRepositoryProvider.overrideWithValue(auth),
        catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
        purchaseRepositoryProvider.overrideWithValue(FakePurchaseRepository()),
        walletRepositoryProvider.overrideWithValue(FakeWalletRepository()),
        orderRepositoryProvider.overrideWithValue(orders),
        pendingCheckoutStoreProvider.overrideWithValue(pending),
        orderPollingPolicyProvider.overrideWithValue(
          const OrderPollingPolicy(
            interval: Duration(milliseconds: 1),
            maximumPolls: 8,
          ),
        ),
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
    return (container: container, auth: auth, pending: pending);
  }

  test('initial list, empty list and pull refresh', () async {
    final orders = FakeOrderRepository();
    final env = await createContainer(orders);
    env.container.read(orderListControllerProvider);
    await pump();
    expect(
      env.container.read(orderListControllerProvider).orders,
      hasLength(1),
    );

    orders.firstPage = OrderListPage.fromJson(orderListPageJson(orders: []));
    await env.container.read(orderListControllerProvider.notifier).refresh();
    expect(
      env.container.read(orderListControllerProvider).phase,
      OrderListPhase.empty,
    );
  });

  test('next page deduplicates order numbers', () async {
    final orders = FakeOrderRepository()
      ..firstPage = OrderListPage.fromJson(orderListPageJson(lastPage: 2))
      ..pages[2] = OrderListPage.fromJson(
        orderListPageJson(
          page: 2,
          lastPage: 2,
          orders: [
            orderListItemJson(),
            orderListItemJson(orderNumber: 'ORD-2026-000002'),
          ],
        ),
      );
    final env = await createContainer(orders);
    env.container.read(orderListControllerProvider);
    await pump();
    await env.container.read(orderListControllerProvider.notifier).loadMore();
    final state = env.container.read(orderListControllerProvider);
    expect(state.orders.map((order) => order.orderNumber).toSet(), {
      'ORD-2026-000001',
      'ORD-2026-000002',
    });
    expect(orders.queries.last.page, 2);
    expect(orders.queries.last.perPage, ordersPerPage);
  });

  test('refresh failure retains last safe in-memory list', () async {
    final orders = FakeOrderRepository();
    final env = await createContainer(orders);
    env.container.read(orderListControllerProvider);
    await pump();
    orders.listError = const ApiException(kind: ApiErrorKind.network);
    await env.container.read(orderListControllerProvider.notifier).refresh();
    final state = env.container.read(orderListControllerProvider);
    expect(state.phase, OrderListPhase.error);
    expect(state.orders.single.orderNumber, 'ORD-2026-000001');
    expect(
      env.container.read(authControllerProvider).phase,
      AuthPhase.authenticated,
    );
  });

  test('detail refresh retains data and bounded polling ends', () async {
    final orders = FakeOrderRepository()
      ..detail = CheckoutResult.fromJson(
        orderDetailJson(fulfillmentStatus: 'processing'),
      );
    final env = await createContainer(orders);
    final subscription = env.container.listen(
      orderDetailControllerProvider('ORD-2026-000001'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(orders.detailCalls, 9);
    expect(
      env.container
          .read(orderDetailControllerProvider('ORD-2026-000001'))
          .pollingEnded,
      isTrue,
    );

    orders.detailError = const ApiException(kind: ApiErrorKind.server);
    await env.container
        .read(orderDetailControllerProvider('ORD-2026-000001').notifier)
        .refresh();
    final state = env.container.read(
      orderDetailControllerProvider('ORD-2026-000001'),
    );
    expect(state.result?.order.orderNumber, 'ORD-2026-000001');
    expect(
      env.container.read(authControllerProvider).phase,
      AuthPhase.authenticated,
    );
  });

  test('polling stops when fulfillment becomes terminal', () async {
    final orders = FakeOrderRepository();
    var calls = 0;
    orders.detailHandler = (_, _) async {
      calls += 1;
      return CheckoutResult.fromJson(
        orderDetailJson(fulfillmentStatus: calls == 1 ? 'queued' : 'completed'),
      );
    };
    final env = await createContainer(orders);
    final subscription = env.container.listen(
      orderDetailControllerProvider('ORD-2026-000001'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(orders.detailCalls, 2);
    expect(
      env.container
          .read(orderDetailControllerProvider('ORD-2026-000001'))
          .result
          ?.order
          .fulfillmentStatus,
      'completed',
    );
  });

  test('logout and customer switch isolate delayed detail responses', () async {
    final orders = FakeOrderRepository();
    final delayedA = Completer<CheckoutResult>();
    var calls = 0;
    orders.detailHandler = (_, _) {
      calls += 1;
      if (calls == 1) {
        return delayedA.future;
      }
      return Future.value(
        CheckoutResult.fromJson(
          orderDetailJson(orderNumber: 'ORD-2026-000002'),
        ),
      );
    };
    final env = await createContainer(orders);
    env.auth.loginHandler = (_, _) async => LoginAuthenticated(sampleSessionB);
    final subscription = env.container.listen(
      orderDetailControllerProvider('ORD-2026-000001'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await pump();
    await env.container.read(authControllerProvider.notifier).logout();
    await pump();
    expect(
      env.container
          .read(orderDetailControllerProvider('ORD-2026-000001'))
          .result,
      isNull,
    );

    await env.container
        .read(authControllerProvider.notifier)
        .login(username: 'other', password: 'ignored');
    await pump();
    delayedA.complete(CheckoutResult.fromJson(orderDetailJson()));
    await pump();
    expect(
      env.container
          .read(orderDetailControllerProvider('ORD-2026-000001'))
          .result
          ?.order
          .orderNumber,
      'ORD-2026-000002',
    );
    expect(orders.detailTokens.first?.isCancelled, isTrue);
  });

  test(
    'history reads never persist bodies or clear another receipt anchor',
    () async {
      final orders = FakeOrderRepository();
      final env = await createContainer(orders);
      await env.pending.markCompleted(
        customerId: sampleUser.id,
        orderNumber: 'ORD-2026-RECENT',
      );
      final subscription = env.container.listen(
        orderDetailControllerProvider('ORD-2026-000001'),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await pump();
      final writesBefore = env.pending.writeCount;
      await env.container
          .read(orderDetailControllerProvider('ORD-2026-000001').notifier)
          .acknowledgeAndLeave();
      expect(env.pending.writeCount, writesBefore);
      expect(
        (await env.pending.readForCustomer(
          sampleUser.id,
        ))?.completedOrderNumber,
        'ORD-2026-RECENT',
      );
    },
  );
}
