import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indirimgo_mobile/core/errors/api_exception.dart';
import 'package:indirimgo_mobile/core/storage/token_storage.dart';
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

  Future<({ProviderContainer container, InMemoryTokenStorage storage})>
  createHarness({
    FakeCatalogRepository? catalog,
    MobileUser? restoreUser,
  }) async {
    final storage = InMemoryTokenStorage(sampleStoredSession());
    final auth = FakeAuthRepository(tokenStorage: storage)
      ..restoreResult = restoreUser ?? sampleUser;
    final catalogRepo = catalog ?? FakeCatalogRepository();
    final container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(storage),
        authRepositoryProvider.overrideWithValue(auth),
        catalogRepositoryProvider.overrideWithValue(catalogRepo),
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
    expect(
      container.read(authControllerProvider).phase,
      AuthPhase.authenticated,
    );
    return (container: container, storage: storage);
  }

  Future<void> waitHomeReady(ProviderContainer container) async {
    container.read(catalogHomeControllerProvider);
    for (var i = 0; i < 40; i++) {
      await pump();
      final phase = container.read(catalogHomeControllerProvider).phase;
      if (phase == CatalogLoadPhase.ready ||
          phase == CatalogLoadPhase.error ||
          phase == CatalogLoadPhase.empty ||
          phase == CatalogLoadPhase.idle) {
        return;
      }
    }
  }

  SessionReference currentSession(InMemoryTokenStorage storage) {
    final session = storage.session;
    expect(session, isNotNull);
    return session!.reference;
  }

  group('authoritative session rejection', () {
    test('home 401 ends the current session and clears content', () async {
      final catalog = FakeCatalogRepository();
      final harness = await createHarness(catalog: catalog);
      await waitHomeReady(harness.container);
      expect(
        harness.container.read(catalogHomeControllerProvider).hasContent,
        isTrue,
      );

      catalog.homeError = unauthorizedRejection(
        currentSession(harness.storage),
      );
      await harness.container
          .read(catalogHomeControllerProvider.notifier)
          .refresh();
      await pump();

      expect(
        harness.container.read(authControllerProvider).phase,
        AuthPhase.unauthenticated,
      );
      expect(
        harness.container.read(catalogHomeControllerProvider).home,
        isNull,
      );
      expect(
        harness.container.read(catalogHomeControllerProvider).phase,
        CatalogLoadPhase.idle,
      );
      expect(harness.storage.session, isNull);
    });

    test('package list 401 ends the current session', () async {
      final catalog = FakeCatalogRepository();
      final harness = await createHarness(catalog: catalog);
      final list = harness.container.read(
        packageListControllerProvider.notifier,
      );
      list.bootstrap();
      await pump();
      expect(
        harness.container.read(packageListControllerProvider).hasContent,
        isTrue,
      );

      catalog.listError = unauthorizedRejection(
        currentSession(harness.storage),
      );
      await list.retry();
      await pump();

      expect(
        harness.container.read(authControllerProvider).phase,
        AuthPhase.unauthenticated,
      );
      expect(
        harness.container.read(packageListControllerProvider).packages,
        isEmpty,
      );
      expect(harness.storage.session, isNull);
    });

    test('package detail 401 ends the current session', () async {
      final catalog = FakeCatalogRepository();
      final harness = await createHarness(catalog: catalog);
      final sub = harness.container.listen(
        packageDetailControllerProvider(42),
        (_, _) {},
      );
      addTearDown(sub.close);
      for (var i = 0; i < 30; i++) {
        await pump();
        if (harness.container.read(packageDetailControllerProvider(42)).phase ==
            PackageDetailPhase.ready) {
          break;
        }
      }

      catalog.detailError = unauthorizedRejection(
        currentSession(harness.storage),
      );
      await harness.container
          .read(packageDetailControllerProvider(42).notifier)
          .retry();
      await pump();

      expect(
        harness.container.read(authControllerProvider).phase,
        AuthPhase.unauthenticated,
      );
      expect(
        harness.container.read(packageDetailControllerProvider(42)).phase,
        PackageDetailPhase.idle,
      );
    });

    for (final code in authoritativeSessionRejectionCodes) {
      test('403 $code ends the session', () async {
        final catalog = FakeCatalogRepository();
        final harness = await createHarness(catalog: catalog);
        await waitHomeReady(harness.container);

        catalog.homeError = forbiddenRejection(
          code,
          currentSession(harness.storage),
        );
        await harness.container
            .read(catalogHomeControllerProvider.notifier)
            .refresh();
        await pump();

        expect(
          harness.container.read(authControllerProvider).phase,
          AuthPhase.unauthenticated,
        );
        expect(
          harness.container.read(catalogHomeControllerProvider).home,
          isNull,
        );
      });
    }

    test('generic non-authoritative 403 retains the session', () async {
      final catalog = FakeCatalogRepository();
      final harness = await createHarness(catalog: catalog);
      await waitHomeReady(harness.container);

      catalog.homeError = ApiException(
        kind: ApiErrorKind.forbidden,
        code: null,
        statusCode: 403,
        requestSession: currentSession(harness.storage),
      );
      await harness.container
          .read(catalogHomeControllerProvider.notifier)
          .refresh();
      await pump();

      expect(
        harness.container.read(authControllerProvider).phase,
        AuthPhase.authenticated,
      );
      expect(harness.storage.session, isNotNull);
      expect(
        harness.container.read(catalogHomeControllerProvider).hasContent,
        isTrue,
      );
    });

    test('offline timeout and 5xx retain the session', () async {
      final catalog = FakeCatalogRepository();
      final harness = await createHarness(catalog: catalog);
      await waitHomeReady(harness.container);

      for (final error in [networkFailure(), serverFailure()]) {
        catalog.homeError = error;
        await harness.container
            .read(catalogHomeControllerProvider.notifier)
            .refresh();
        await pump();
        expect(
          harness.container.read(authControllerProvider).phase,
          AuthPhase.authenticated,
        );
        expect(harness.storage.session, isNotNull);
        expect(
          harness.container.read(catalogHomeControllerProvider).hasContent,
          isTrue,
        );
      }
    });

    test('ready home refresh 401 clears personalized content', () async {
      final catalog = FakeCatalogRepository();
      final harness = await createHarness(catalog: catalog);
      await waitHomeReady(harness.container);
      final before = harness.container.read(catalogHomeControllerProvider);
      expect(before.home!.featuredPackages, isNotEmpty);
      expect(before.home!.pricesVisible, isTrue);

      catalog.homeError = unauthorizedRejection(
        currentSession(harness.storage),
      );
      await harness.container
          .read(catalogHomeControllerProvider.notifier)
          .refresh();
      await pump();

      final after = harness.container.read(catalogHomeControllerProvider);
      expect(after.home, isNull);
      expect(after.phase, CatalogLoadPhase.idle);
      expect(
        harness.container.read(authControllerProvider).phase,
        AuthPhase.unauthenticated,
      );
    });

    test('ready list load-more 401 clears all list content', () async {
      final catalog = FakeCatalogRepository(
        packages: [
          for (var i = 1; i <= 30; i++)
            PackageSummary.fromJson(packageSummaryJson(id: i, name: 'P$i')),
        ],
      );
      final harness = await createHarness(catalog: catalog);
      final list = harness.container.read(
        packageListControllerProvider.notifier,
      );
      list.bootstrap();
      await pump();
      expect(
        harness.container.read(packageListControllerProvider).packages.length,
        24,
      );

      catalog.loadMoreError = unauthorizedRejection(
        currentSession(harness.storage),
      );
      await list.loadMore();
      await pump();

      expect(
        harness.container.read(packageListControllerProvider).packages,
        isEmpty,
      );
      expect(
        harness.container.read(authControllerProvider).phase,
        AuthPhase.unauthenticated,
      );
    });

    test('delayed A-session 401 after B login does not clear B', () async {
      final catalog = FakeCatalogRepository();
      final harness = await createHarness(catalog: catalog);
      await waitHomeReady(harness.container);
      final sessionA = currentSession(harness.storage);

      await harness.container.read(authControllerProvider.notifier).logout();
      await pump();

      final userB = MobileUser(
        id: 99,
        name: 'Customer B',
        username: 'bee',
        email: 'b@example.com',
        phone: null,
        countryCode: null,
        locale: 'en',
        preferredCurrency: 'USD',
        timezone: null,
        profilePhotoUrl: null,
        emailVerifiedAt: null,
      );
      final auth =
          harness.container.read(authRepositoryProvider) as FakeAuthRepository;
      auth.loginHandler = (_, _) async => LoginAuthenticated(
        AuthSession(
          token: AuthToken(
            accessToken: '99|token-b',
            tokenType: 'Bearer',
            expiresAt: DateTime.utc(2026, 9, 1),
          ),
          user: userB,
        ),
      );
      await harness.container
          .read(authControllerProvider.notifier)
          .login(username: 'bee', password: 'x');
      await pump();
      await waitHomeReady(harness.container);

      catalog.homeError = unauthorizedRejection(sessionA);
      await harness.container
          .read(catalogHomeControllerProvider.notifier)
          .refresh();
      await pump();

      expect(
        harness.container.read(authControllerProvider).phase,
        AuthPhase.authenticated,
      );
      expect(harness.container.read(authControllerProvider).user?.id, 99);
      expect(harness.storage.session?.token, '99|token-b');
      expect(
        harness.container.read(catalogHomeControllerProvider).hasContent,
        isTrue,
      );
    });

    test('two concurrent matching 401 responses are idempotent', () async {
      final harness = await createHarness();
      await waitHomeReady(harness.container);
      final session = currentSession(harness.storage);
      final error = unauthorizedRejection(session);
      final auth = harness.container.read(authControllerProvider.notifier);

      final results = await Future.wait([
        auth.applyAuthoritativeRejection(error),
        auth.applyAuthoritativeRejection(error),
      ]);
      await pump();

      expect(results, everyElement(isTrue));
      expect(
        harness.container.read(authControllerProvider).phase,
        AuthPhase.unauthenticated,
      );
      expect(harness.storage.session, isNull);
      expect(harness.storage.clearCount, 1);
    });

    test('storage-clear failure preserves rejection without secrets', () async {
      final storage = _FailingClearStorage(sampleStoredSession());
      final auth = FakeAuthRepository(tokenStorage: storage)
        ..restoreResult = sampleUser;
      final catalog = FakeCatalogRepository();
      final container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(storage),
          authRepositoryProvider.overrideWithValue(auth),
          catalogRepositoryProvider.overrideWithValue(catalog),
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
      await waitHomeReady(container);
      final session = storage.session!.reference;

      catalog.homeError = unauthorizedRejection(session);
      await container.read(catalogHomeControllerProvider.notifier).refresh();
      await pump();

      final authState = container.read(authControllerProvider);
      expect(authState.phase, AuthPhase.unauthenticated);
      expect(authState.error?.kind, ApiErrorKind.unauthorized);
      expect(authState.error.toString(), isNot(contains('test-secret')));
      expect(authState.error.toString(), isNot(contains('7|')));
      expect(container.read(catalogHomeControllerProvider).home, isNull);
    });
  });

  group('search max length', () {
    test('typed and programmatic 101-character values are clamped', () async {
      final catalog = FakeCatalogRepository();
      final harness = await createHarness(catalog: catalog);
      final list = harness.container.read(
        packageListControllerProvider.notifier,
      );
      list.bootstrap();
      await pump();
      final baseline = catalog.listCalls;

      final overlong = 'x' * 101;
      expect(clampCatalogSearchInput(overlong).runes.length, 100);

      list.onSearchChanged(overlong);
      await Future<void>.delayed(const Duration(milliseconds: 450));
      expect(catalog.listQueries.last.q!.length, 100);

      list.submitSearch('${'y' * 101}z');
      await pump();
      expect(catalog.listQueries.last.q!.length, lessThanOrEqualTo(100));
      expect(catalog.listCalls, greaterThan(baseline));
    });
  });

  group('lifecycle and invalid id', () {
    test(
      'package ids below 1 are local not-found without repository calls',
      () async {
        final catalog = FakeCatalogRepository();
        final harness = await createHarness(catalog: catalog);
        final before = catalog.detailCalls;
        final sub = harness.container.listen(
          packageDetailControllerProvider(0),
          (_, _) {},
        );
        addTearDown(sub.close);
        await pump();
        expect(
          harness.container.read(packageDetailControllerProvider(0)).phase,
          PackageDetailPhase.notFound,
        );
        expect(catalog.detailCalls, before);
      },
    );

    test('detail providers dispose after listeners are removed', () async {
      final catalog = FakeCatalogRepository();
      final harness = await createHarness(catalog: catalog);
      final sub = harness.container.listen(
        packageDetailControllerProvider(42),
        (_, _) {},
      );
      for (var i = 0; i < 30; i++) {
        await pump();
        if (harness.container.read(packageDetailControllerProvider(42)).phase ==
            PackageDetailPhase.ready) {
          break;
        }
      }
      expect(
        harness.container.exists(packageDetailControllerProvider(42)),
        isTrue,
      );
      sub.close();
      await pump();
      await pump();
      expect(
        harness.container.exists(packageDetailControllerProvider(42)),
        isFalse,
      );
    });
  });
}

final class _FailingClearStorage extends InMemoryTokenStorage {
  _FailingClearStorage([super.session]);

  @override
  Future<bool> clearIfCurrent(SessionReference reference) async {
    throw const TokenStorageException(TokenStorageOperation.delete);
  }
}
