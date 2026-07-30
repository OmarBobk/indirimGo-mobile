import 'package:flutter_test/flutter_test.dart';
import 'package:indirimgo_mobile/features/catalog/domain/catalog_models.dart';

import '../../support/catalog_fixtures.dart';

void main() {
  group('Money', () {
    test('parses authoritative string amount and display', () {
      final money = Money.fromJson(moneyJson());
      expect(money.amount, '5.00');
      expect(money.amount, isA<String>());
      expect(money.currency, 'USD');
      expect(money.display.formatted, r'$5.00');
      expect(money.display.currency, 'USD');
    });

    test('rejects non-string amount and wrong currency', () {
      expect(
        () => Money.fromJson(moneyJson()..['amount'] = 5.0),
        throwsFormatException,
      );
      expect(
        () => Money.fromJson(moneyJson(currency: 'TRY')),
        throwsFormatException,
      );
      expect(
        () => Money.fromJson(moneyJson(amount: '5')),
        throwsFormatException,
      );
    });

    test('ignores unknown additive fields', () {
      final json = moneyJson()..['tier'] = 'gold';
      expect(Money.fromJson(json).amount, '5.00');
    });
  });

  group('PackageSummary', () {
    test('parses required fields and nullable image/category/price', () {
      final package = PackageSummary.fromJson(
        packageSummaryJson(imageUrl: null, fromPrice: null, category: null),
      );
      expect(package.id, 42);
      expect(package.imageUrl, isNull);
      expect(package.fromPrice, isNull);
      expect(package.category, isNull);
    });

    test('soft-nulls invalid image URLs and rejects bad types', () {
      final soft = PackageSummary.fromJson(
        packageSummaryJson(imageUrl: 'ftp://evil.test/x'),
      );
      expect(soft.imageUrl, isNull);
      expect(
        () => PackageSummary.fromJson(packageSummaryJson()..remove('name')),
        throwsFormatException,
      );
      expect(
        () => PackageSummary.fromJson(packageSummaryJson()..['id'] = '42'),
        throwsFormatException,
      );
    });
  });

  group('FrequentlyOrderedPackage', () {
    test('requires times_ordered >= 1', () {
      expect(
        FrequentlyOrderedPackage.fromJson(frequentlyOrderedJson()).timesOrdered,
        4,
      );
      expect(
        () => FrequentlyOrderedPackage.fromJson(
          frequentlyOrderedJson(timesOrdered: 0),
        ),
        throwsFormatException,
      );
    });
  });

  group('ProductOption', () {
    test('parses fixed and custom products', () {
      final fixed = ProductOption.fromJson(fixedProductJson());
      expect(fixed.isFixed, isTrue);
      expect(fixed.unitPrice?.amount, '5.00');
      expect(fixed.customAmount, isNull);

      final custom = ProductOption.fromJson(customProductJson());
      expect(custom.isCustom, isTrue);
      expect(custom.unitPrice, isNull);
      expect(custom.customAmount?.min, 100);
      expect(custom.minimumPrice?.display.formatted, r'$5.00');
    });

    test('handles malformed custom metadata with nulls', () {
      final product = ProductOption.fromJson(
        customProductJson(
          customAmount: {
            'min': null,
            'max': null,
            'step': null,
            'unit_label': null,
          },
          minimumPrice: null,
        ),
      );
      expect(product.customAmount?.min, isNull);
      expect(product.minimumPrice, isNull);
      expect(product.customAmount?.hasAnyBound, isFalse);
    });

    test('normalizes custom bounds below 1 to null', () {
      final product = ProductOption.fromJson(
        customProductJson(
          customAmount: {'min': 0, 'max': -1, 'step': 0, 'unit_label': 'Coins'},
        ),
      );
      expect(product.customAmount?.min, isNull);
      expect(product.customAmount?.max, isNull);
      expect(product.customAmount?.step, isNull);
      expect(product.customAmount?.unitLabel, 'Coins');
    });
  });

  group('CatalogHome', () {
    test('parses shelves and prices_visible', () {
      final home = CatalogHome.fromJson(catalogHomeJson());
      expect(home.frequentlyOrdered, hasLength(1));
      expect(home.featuredPackages, hasLength(2));
      expect(home.categories.single.id, 3);
      expect(home.pricesVisible, isTrue);
    });

    test('parses prices_visible false with null money keys present', () {
      final home = CatalogHome.fromJson(
        catalogHomeJson(
          pricesVisible: false,
          featured: [packageSummaryJson(fromPrice: null)],
          frequentlyOrdered: [
            {...packageSummaryJson(fromPrice: null), 'times_ordered': 2},
          ],
        ),
      );
      expect(home.pricesVisible, isFalse);
      expect(home.featuredPackages.single.fromPrice, isNull);
      expect(home.frequentlyOrdered.single.fromPrice, isNull);
    });

    test('allows empty frequently ordered shelf', () {
      final home = CatalogHome.fromJson(
        catalogHomeJson(frequentlyOrdered: const []),
      );
      expect(home.frequentlyOrdered, isEmpty);
    });
  });

  group('PackageListPage', () {
    test('parses pagination metadata', () {
      final page = PackageListPage.fromJson(
        packageListJson(page: 2, perPage: 24, total: 50, lastPage: 3),
      );
      expect(page.pagination.page, 2);
      expect(page.pagination.hasNextPage, isTrue);
      expect(page.packages, hasLength(2));
    });
  });

  group('PackageDetailResult', () {
    test('parses OpenAPI detail example shape', () {
      final result = PackageDetailResult.fromJson(packageDetailJson());
      expect(result.package.id, 42);
      expect(result.package.description, 'Digital top-up options.');
      expect(result.package.products, hasLength(2));
      expect(result.pricesVisible, isTrue);
    });

    test('allows null description', () {
      final result = PackageDetailResult.fromJson(
        packageDetailJson(description: null),
      );
      expect(result.package.description, isNull);
    });
  });

  group('PackageListQuery', () {
    test('emits only set query parameters', () {
      expect(const PackageListQuery().toQueryParameters(), {
        'page': 1,
        'per_page': 24,
      });
      expect(
        const PackageListQuery(
          categoryId: 3,
          q: '  game  ',
          page: 2,
          perPage: 10,
        ).toQueryParameters(),
        {'page': 2, 'per_page': 10, 'category_id': 3, 'q': 'game'},
      );
    });
  });
}
