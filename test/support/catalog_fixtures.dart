import 'package:indirimgo_mobile/features/catalog/domain/catalog_models.dart';

/// Fictional fixture values derived from OpenAPI catalog examples.
Map<String, Object?> moneyJson({
  String amount = '5.00',
  String currency = 'USD',
  String displayCurrency = 'USD',
  String formatted = r'$5.00',
}) {
  return {
    'amount': amount,
    'currency': currency,
    'display': {'currency': displayCurrency, 'formatted': formatted},
  };
}

Map<String, Object?> categorySummaryJson({
  int id = 3,
  String name = 'Games',
  String slug = 'games',
}) {
  return {'id': id, 'name': name, 'slug': slug};
}

Map<String, Object?> packageSummaryJson({
  int id = 42,
  String name = 'Example Game Top-up',
  String slug = 'example-game-top-up',
  Object? imageUrl = 'https://example.test/images/packages/abc.webp',
  int productsCount = 2,
  Object? fromPrice,
  Object? category,
}) {
  return {
    'id': id,
    'name': name,
    'slug': slug,
    'image_url': imageUrl,
    'products_count': productsCount,
    'from_price': fromPrice ?? moneyJson(),
    'category': category ?? categorySummaryJson(),
  };
}

Map<String, Object?> frequentlyOrderedJson({
  int timesOrdered = 4,
}) {
  return {...packageSummaryJson(), 'times_ordered': timesOrdered};
}

Map<String, Object?> featuredPackageJson() {
  return packageSummaryJson(
    id: 43,
    name: 'Featured Cards Pack',
    slug: 'featured-cards-pack',
    imageUrl: null,
    productsCount: 1,
    fromPrice: moneyJson(
      amount: '12.50',
      displayCurrency: 'TRY',
      formatted: '₺425.00',
    ),
    category: categorySummaryJson(id: 5, name: 'Cards', slug: 'cards'),
  );
}

Map<String, Object?> categoryChipJson({
  int id = 3,
  String name = 'Games',
  String slug = 'games',
  Object? imageUrl = 'https://example.test/images/categories/games.webp',
}) {
  return {
    'id': id,
    'name': name,
    'slug': slug,
    'image_url': imageUrl,
  };
}

Map<String, Object?> fixedProductJson() {
  return {
    'id': 901,
    'name': '100 Coins',
    'amount_mode': 'fixed',
    'unit_price': moneyJson(),
    'custom_amount': null,
    'minimum_price': null,
  };
}

Map<String, Object?> customProductJson({
  Object? customAmount = const {
    'min': 100,
    'max': 10000,
    'step': 100,
    'unit_label': 'Coins',
  },
  Object? minimumPrice,
}) {
  return {
    'id': 902,
    'name': 'Custom amount',
    'amount_mode': 'custom',
    'unit_price': null,
    'custom_amount': customAmount is Map
        ? Map<String, Object?>.from(customAmount)
        : customAmount,
    'minimum_price': minimumPrice ?? moneyJson(),
  };
}

Map<String, Object?> catalogHomeJson({
  bool pricesVisible = true,
  List<Map<String, Object?>>? frequentlyOrdered,
  List<Map<String, Object?>>? featured,
  List<Map<String, Object?>>? categories,
}) {
  return {
    'data': {
      'frequently_ordered': frequentlyOrdered ?? [frequentlyOrderedJson()],
      'featured_packages':
          featured ?? [featuredPackageJson(), packageSummaryJson()],
      'categories': categories ?? [categoryChipJson()],
    },
    'meta': {'prices_visible': pricesVisible},
  };
}

Map<String, Object?> packageListJson({
  bool pricesVisible = true,
  List<Map<String, Object?>>? packages,
  int page = 1,
  int perPage = 24,
  int total = 2,
  int lastPage = 1,
}) {
  return {
    'data': packages ?? [packageSummaryJson(), featuredPackageJson()],
    'meta': {
      'prices_visible': pricesVisible,
      'pagination': {
        'page': page,
        'per_page': perPage,
        'total': total,
        'last_page': lastPage,
      },
    },
  };
}

Map<String, Object?> packageDetailJson({
  bool pricesVisible = true,
  Object? description = 'Digital top-up options.',
  List<Map<String, Object?>>? products,
  Object? fromPrice,
}) {
  return {
    'data': {
      ...packageSummaryJson(fromPrice: fromPrice),
      'description': description,
      'products': products ?? [fixedProductJson(), customProductJson()],
    },
    'meta': {'prices_visible': pricesVisible},
  };
}

final sampleCatalogHome = CatalogHome.fromJson(catalogHomeJson());

final samplePackageSummaries = [
  PackageSummary.fromJson(packageSummaryJson()),
  PackageSummary.fromJson(featuredPackageJson()),
];

final samplePackageDetailResult = PackageDetailResult.fromJson(
  packageDetailJson(),
);
