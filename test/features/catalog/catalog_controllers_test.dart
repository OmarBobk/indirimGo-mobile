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
  Future<ProviderContainer> createContainer({
    FakeAuthRepository? auth,
    FakeCatalogRepository? catalog,
    MobileUser? restoreUser,
  }) async {
    final authRepo = auth ?? FakeAuthRepository()
      ..restoreResult = restoreUser ?? sampleUser;
    final catalogRepo = catalog ?? FakeCatalogRepository();
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepo),
        catalogRepositoryProvider.overrideWithValue(catalogRepo),
      ],
    );
    addTearDown(container.dispose);
    // Allow auth restore + home microtasks.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    return container;
  }

  test('home loads featured shelves and omits empty frequently ordered', () async {
    final catalog = FakeCatalogRepository(
      home: CatalogHome.fromJson(
        catalogHomeJson(frequentlyOrdered: const []),
      ),
    );
    final container = await createContainer(catalog: catalog);
    final state = container.read(catalogHomeControllerProvider);
    expect(state.phase, CatalogLoadPhase.ready);
    expect(state.home!.frequentlyOrdered, isEmpty);
    expect(state.home!.featuredPackages, isNotEmpty);
    expect(catalog.homeCalls, greaterThanOrEqualTo(1));
  });

  test('home refresh and retry preserve session on network failure', () async {
    final catalog = FakeCatalogRepository();
    final container = await createContainer(catalog: catalog);
    expect(container.read(catalogHomeControllerProvider).hasContent, isTrue);

    catalog.homeError = networkFailure();
    await container.read(catalogHomeControllerProvider.notifier).refresh();
    final failed = container.read(catalogHomeControllerProvider);
    expect(failed.phase, CatalogLoadPhase.error);
    expect(failed.hasContent, isTrue);
    expect(
      container.read(authControllerProvider).phase,
      AuthPhase.authenticated,
    );

    catalog.homeError = null;
    await container.read(catalogHomeControllerProvider.notifier).retry();
    expect(container.read(catalogHomeControllerProvider).phase, CatalogLoadPhase.ready);
  });

  test('package list search debounce ignores one character', () async {
    final catalog = FakeCatalogRepository();
    final container = await createContainer(catalog: catalog);
    final controller = container.read(packageListControllerProvider.notifier);
    controller.bootstrap();
    await Future<void>.delayed(Duration.zero);
    final baseline = catalog.listCalls;

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
    await Future<void>.delayed(const Duration(milliseconds: 100));

    controller.submitSearch('old');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    controller.submitSearch('new');
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(container.read(packageListControllerProvider).query.q, 'new');
    expect(catalog.listQueries.last.q, 'new');
  });

  test('category filtering and load-more failure preserve content', () async {
    final packages = [
      for (var i = 1; i <= 3; i++)
        PackageSummary.fromJson(
          packageSummaryJson(
            id: i,
            name: 'Pack $i',
            category: categorySummaryJson(id: i == 3 ? 9 : 3),
          ),
        ),
    ];
    final catalog = FakeCatalogRepository(packages: packages)
      ..nextPage = PackageListPage(
        packages: [
          PackageSummary.fromJson(packageSummaryJson(id: 99, name: 'More')),
        ],
        pricesVisible: true,
        pagination: const OffsetPagination(
          page: 2,
          perPage: 24,
          total: 4,
          lastPage: 2,
        ),
      );
    // Force first page to report another page exists.
    catalog.packages = packages;
    final container = await createContainer(catalog: catalog);
    final controller = container.read(packageListControllerProvider.notifier);
    controller.bootstrap(categoryId: 3);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    var state = container.read(packageListControllerProvider);
    expect(state.packages.every((p) => p.category?.id == 3), isTrue);

    // Make pagination claim a next page.
    state = PackageListState(
      phase: PackageListPhase.ready,
      query: state.query,
      packages: state.packages,
      pricesVisible: true,
      pagination: const OffsetPagination(
        page: 1,
        perPage: 24,
        total: 40,
        lastPage: 2,
      ),
      searchInput: state.searchInput,
      customerId: state.customerId,
    );
    // Directly drive load more through repository path by refreshing with patched fake.
    catalog.loadMoreError = networkFailure();
    // Re-bootstrap with open list then manually set pagination via fetch page1 that has last_page 2
    final wide = FakeCatalogRepository(
      packages: [
        for (var i = 1; i <= 30; i++)
          PackageSummary.fromJson(packageSummaryJson(id: i, name: 'P$i')),
      ],
    )..loadMoreError = networkFailure();
    final container2 = await createContainer(catalog: wide);
    final list = container2.read(packageListControllerProvider.notifier);
    list.bootstrap();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    // Fake returns all 30 on page 1 with last_page computed as 2 when per_page 24
    final ready = container2.read(packageListControllerProvider);
    expect(ready.packages.length, 24);
    expect(ready.canLoadMore, isTrue);
    await list.loadMore();
    final after = container2.read(packageListControllerProvider);
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
    await Future<void>.delayed(Duration.zero);
    final detail = container.read(packageDetailControllerProvider(42));
    expect(detail.phase, PackageDetailPhase.ready);

    catalog.detailError = const ApiException(
      kind: ApiErrorKind.notFound,
      code: 'package_not_found',
      statusCode: 404,
    );
    await container.read(packageDetailControllerProvider(42).notifier).retry();
    expect(
      container.read(packageDetailControllerProvider(42)).phase,
      PackageDetailPhase.notFound,
    );

    catalog.detailError = networkFailure();
    await container.read(packageDetailControllerProvider(7).notifier).load();
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
    expect(container.read(catalogHomeControllerProvider).hasContent, isTrue);

    await container.read(authControllerProvider.notifier).logout();
    await Future<void>.delayed(Duration.zero);
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
    auth
      ..restoreResult = otherUser
      ..loginHandler = (_, _) async => LoginAuthenticated(
        AuthSession(
          token: AuthToken(
            accessToken: '99|other',
            tokenType: 'Bearer',
            expiresAt: DateTime.utc(2026, 8, 28),
          ),
          user: otherUser,
        ),
      );
    // Simulate fresh login as another customer.
    container.read(authControllerProvider.notifier).returnToLogin();
    await container
        .read(authControllerProvider.notifier)
        .login(username: 'other', password: 'x');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(catalogCustomerIdProvider), 99);
    expect(container.read(catalogHomeControllerProvider).customerId, 99);
  });

  test('stale home response after customer switch is ignored', () async {
    final slow = FakeCatalogRepository()
      ..homeDelay = const Duration(milliseconds: 100);
    final auth = FakeAuthRepository()..restoreResult = sampleUser;
    final container = await createContainer(auth: auth, catalog: slow);
    final homeCallsAtStart = slow.homeCalls;

    // Switch customer before slow response completes.
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
    await container
        .read(authControllerProvider.notifier)
        .login(username: 'second', password: 'x');
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(container.read(catalogHomeControllerProvider).customerId, 55);
    expect(slow.homeCalls, greaterThan(homeCallsAtStart));
  });
}
