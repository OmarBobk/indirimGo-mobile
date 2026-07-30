import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indirimgo_mobile/core/errors/api_exception.dart';
import 'package:indirimgo_mobile/features/auth/domain/auth_models.dart';
import 'package:indirimgo_mobile/features/auth/domain/auth_repository.dart';
import 'package:indirimgo_mobile/features/auth/presentation/auth_controller.dart';
import 'package:indirimgo_mobile/features/catalog/domain/catalog_models.dart';
import 'package:indirimgo_mobile/features/catalog/domain/catalog_repository.dart';
import 'package:indirimgo_mobile/features/catalog/presentation/catalog_controllers.dart';

import '../../support/catalog_fixtures.dart';
import '../../support/fake_catalog_repository.dart';
import '../../support/fakes.dart';

void main() {
  Future<void> pump() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  Future<ProviderContainer> createContainer({
    FakeAuthRepository? auth,
    FakeCatalogRepository? catalog,
    MobileUser? restoreUser,
  }) async {
    final authRepo =
        auth ??
        (FakeAuthRepository()..restoreResult = restoreUser ?? sampleUser);
    final catalogRepo = catalog ?? FakeCatalogRepository();
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepo),
        catalogRepositoryProvider.overrideWithValue(catalogRepo),
      ],
    );
    addTearDown(container.dispose);
    for (var i = 0; i < 30; i++) {
      await pump();
      final phase = container.read(authControllerProvider).phase;
      if (phase != AuthPhase.initializing) {
        break;
      }
    }
    return container;
  }

  Future<void> waitHomeReady(ProviderContainer container) async {
    container.read(catalogHomeControllerProvider);
    for (var i = 0; i < 30; i++) {
      await pump();
      final phase = container.read(catalogHomeControllerProvider).phase;
      if (phase == CatalogLoadPhase.ready ||
          phase == CatalogLoadPhase.error ||
          phase == CatalogLoadPhase.empty) {
        return;
      }
    }
  }

  test(
    'home loads featured shelves and omits empty frequently ordered',
    () async {
      final catalog = FakeCatalogRepository(
        home: CatalogHome.fromJson(
          catalogHomeJson(frequentlyOrdered: const []),
        ),
      );
      final container = await createContainer(catalog: catalog);
      await waitHomeReady(container);
      final state = container.read(catalogHomeControllerProvider);
      expect(state.phase, CatalogLoadPhase.ready);
      expect(state.home!.frequentlyOrdered, isEmpty);
      expect(state.home!.featuredPackages, isNotEmpty);
      expect(catalog.homeCalls, greaterThanOrEqualTo(1));
    },
  );

  test('home refresh and retry preserve session on network failure', () async {
    final catalog = FakeCatalogRepository();
    final container = await createContainer(catalog: catalog);
    await waitHomeReady(container);
    expect(container.read(catalogHomeControllerProvider).hasContent, isTrue);

    catalog.homeError = networkFailure();
    await container.read(catalogHomeControllerProvider.notifier).refresh();
    await pump();
    final failed = container.read(catalogHomeControllerProvider);
    expect(failed.phase, CatalogLoadPhase.error);
    expect(failed.hasContent, isTrue);
    expect(
      container.read(authControllerProvider).phase,
      AuthPhase.authenticated,
    );

    catalog.homeError = null;
    await container.read(catalogHomeControllerProvider.notifier).retry();
    await pump();
    expect(
      container.read(catalogHomeControllerProvider).phase,
      CatalogLoadPhase.ready,
    );
  });

  test('package list search debounce ignores one character', () async {
    final catalog = FakeCatalogRepository();
    final container = await createContainer(catalog: catalog);
    final controller = container.read(packageListControllerProvider.notifier);
    controller.bootstrap();
    await pump();
    final baseline = catalog.listCalls;
    expect(baseline, greaterThanOrEqualTo(1));

    controller.onSearchChanged('a');
    await Future<void>.delayed(const Duration(milliseconds: 450));
    expect(catalog.listCalls, baseline);

    controller.onSearchChanged('ab');
    await Future<void>.delayed(const Duration(milliseconds: 450));
    expect(catalog.listCalls, baseline + 1);
    expect(catalog.listQueries.last.q, 'ab');
  });

  test('stale search responses do not overwrite newer queries', () async {
    final catalog = FakeCatalogRepository()
      ..listDelay = const Duration(milliseconds: 80);
    final container = await createContainer(catalog: catalog);
    final controller = container.read(packageListControllerProvider.notifier);
    controller.bootstrap();
    await Future<void>.delayed(const Duration(milliseconds: 120));

    controller.submitSearch('old');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    controller.submitSearch('new');
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(container.read(packageListControllerProvider).query.q, 'new');
    expect(catalog.listQueries.last.q, 'new');
  });

  test('category filtering and load-more failure preserve content', () async {
    final wide = FakeCatalogRepository(
      packages: [
        for (var i = 1; i <= 30; i++)
          PackageSummary.fromJson(packageSummaryJson(id: i, name: 'P$i')),
      ],
    )..loadMoreError = networkFailure();
    final container = await createContainer(catalog: wide);
    final list = container.read(packageListControllerProvider.notifier);
    list.bootstrap();
    await pump();
    await pump();
    final ready = container.read(packageListControllerProvider);
    expect(ready.packages.length, 24);
    expect(ready.canLoadMore, isTrue);
    await list.loadMore();
    await pump();
    final after = container.read(packageListControllerProvider);
    expect(after.packages.length, 24);
    expect(after.loadMoreError?.kind, ApiErrorKind.network);
    expect(after.phase, PackageListPhase.ready);
  });

  test('duplicate load-more is prevented while in flight', () async {
    final catalog = FakeCatalogRepository(
      packages: [
        for (var i = 1; i <= 30; i++)
          PackageSummary.fromJson(packageSummaryJson(id: i, name: 'P$i')),
      ],
    )..listDelay = const Duration(milliseconds: 100);
    final container = await createContainer(catalog: catalog);
    final list = container.read(packageListControllerProvider.notifier);
    list.bootstrap();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final before = catalog.listCalls;
    unawaited(list.loadMore());
    unawaited(list.loadMore());
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(catalog.listCalls, before + 1);
  });

  test('detail success, not-found, and offline retry', () async {
    final catalog = FakeCatalogRepository();
    final container = await createContainer(catalog: catalog);
    container.read(packageDetailControllerProvider(42));
    for (var i = 0; i < 20; i++) {
      await pump();
      if (container.read(packageDetailControllerProvider(42)).phase ==
          PackageDetailPhase.ready) {
        break;
      }
    }
    expect(
      container.read(packageDetailControllerProvider(42)).phase,
      PackageDetailPhase.ready,
    );

    catalog.detailError = const ApiException(
      kind: ApiErrorKind.notFound,
      code: 'package_not_found',
      statusCode: 404,
    );
    await container.read(packageDetailControllerProvider(42).notifier).retry();
    await pump();
    expect(
      container.read(packageDetailControllerProvider(42)).phase,
      PackageDetailPhase.notFound,
    );

    catalog.detailError = networkFailure();
    container.read(packageDetailControllerProvider(7));
    await container.read(packageDetailControllerProvider(7).notifier).load();
    await pump();
    expect(
      container.read(packageDetailControllerProvider(7)).phase,
      PackageDetailPhase.error,
    );
    expect(
      container.read(authControllerProvider).phase,
      AuthPhase.authenticated,
    );
  });

  test('logout and customer switch clear personalized catalog state', () async {
    final catalog = FakeCatalogRepository();
    final auth = FakeAuthRepository()..restoreResult = sampleUser;
    final container = await createContainer(auth: auth, catalog: catalog);
    await waitHomeReady(container);
    expect(container.read(catalogHomeControllerProvider).hasContent, isTrue);

    await container.read(authControllerProvider.notifier).logout();
    await pump();
    expect(container.read(catalogHomeControllerProvider).home, isNull);
    expect(
      container.read(catalogHomeControllerProvider).phase,
      CatalogLoadPhase.idle,
    );

    final otherUser = MobileUser(
      id: 99,
      name: 'Other Customer',
      username: 'other',
      email: 'other@example.com',
      phone: null,
      countryCode: null,
      locale: 'en',
      preferredCurrency: 'USD',
      timezone: null,
      profilePhotoUrl: null,
      emailVerifiedAt: null,
    );
    auth.loginHandler = (_, _) async => LoginAuthenticated(
      AuthSession(
        token: AuthToken(
          accessToken: '99|other',
          tokenType: 'Bearer',
          expiresAt: DateTime.utc(2026, 8, 28),
        ),
        user: otherUser,
      ),
    );
    await container
        .read(authControllerProvider.notifier)
        .login(username: 'other', password: 'x');
    await pump();
    await waitHomeReady(container);
    expect(container.read(catalogCustomerIdProvider), 99);
    expect(container.read(catalogHomeControllerProvider).customerId, 99);
  });

  test('stale home response after customer switch is ignored', () async {
    final slow = FakeCatalogRepository()
      ..homeDelay = const Duration(milliseconds: 100);
    final auth = FakeAuthRepository()..restoreResult = sampleUser;
    final container = await createContainer(auth: auth, catalog: slow);
    await waitHomeReady(container);
    final homeCallsAtStart = slow.homeCalls;

    final other = MobileUser(
      id: 55,
      name: 'Second',
      username: 'second',
      email: 'second@example.com',
      phone: null,
      countryCode: null,
      locale: 'ar',
      preferredCurrency: 'USD',
      timezone: null,
      profilePhotoUrl: null,
      emailVerifiedAt: null,
    );
    auth.loginHandler = (_, _) async => LoginAuthenticated(
      AuthSession(
        token: AuthToken(
          accessToken: '55|second',
          tokenType: 'Bearer',
          expiresAt: DateTime.utc(2026, 8, 28),
        ),
        user: other,
      ),
    );
    await container.read(authControllerProvider.notifier).logout();
    await pump();
    await container
        .read(authControllerProvider.notifier)
        .login(username: 'second', password: 'x');
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await waitHomeReady(container);
    expect(container.read(catalogHomeControllerProvider).customerId, 55);
    expect(slow.homeCalls, greaterThan(homeCallsAtStart));
  });
}
