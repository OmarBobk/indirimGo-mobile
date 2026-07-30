/// Catalog OpenAPI models for the mobile commerce shell.
///
/// Money `amount` is always preserved as a string. Never parse it into `double`
/// or recompute prices. Customer-facing price text uses `display.formatted`.
library;

enum ProductAmountMode { fixed, custom }

class MoneyDisplay {
  const MoneyDisplay({required this.currency, required this.formatted});

  factory MoneyDisplay.fromJson(Map<String, Object?> json) {
    _requireKeys(json, const {'currency', 'formatted'});
    final currency = _requiredString(json, 'currency');
    if (currency != 'USD' && currency != 'TRY') {
      throw const FormatException('Money display currency must be USD or TRY.');
    }
    return MoneyDisplay(
      currency: currency,
      formatted: _requiredString(json, 'formatted'),
    );
  }

  final String currency;
  final String formatted;
}

class Money {
  const Money({
    required this.amount,
    required this.currency,
    required this.display,
  });

  factory Money.fromJson(Map<String, Object?> json) {
    _requireKeys(json, const {'amount', 'currency', 'display'});
    final amount = _requiredString(json, 'amount');
    if (!_moneyAmountPattern.hasMatch(amount)) {
      throw const FormatException(
        'Money amount must be a two-decimal USD string.',
      );
    }
    final currency = _requiredString(json, 'currency');
    if (currency != 'USD') {
      throw const FormatException('Money currency must be USD.');
    }
    return Money(
      amount: amount,
      currency: currency,
      display: MoneyDisplay.fromJson(_requiredMap(json, 'display')),
    );
  }

  /// Authoritative ledger amount in USD (`"12.50"`). Never convert to double.
  final String amount;
  final String currency;
  final MoneyDisplay display;
}

class CategorySummary {
  const CategorySummary({
    required this.id,
    required this.name,
    required this.slug,
  });

  factory CategorySummary.fromJson(Map<String, Object?> json) {
    _requireKeys(json, const {'id', 'name', 'slug'});
    return CategorySummary(
      id: _requiredInt(json, 'id'),
      name: _requiredString(json, 'name'),
      slug: _requiredString(json, 'slug'),
    );
  }

  final int id;
  final String name;
  final String slug;
}

class CategoryChip {
  const CategoryChip({
    required this.id,
    required this.name,
    required this.slug,
    required this.imageUrl,
  });

  factory CategoryChip.fromJson(Map<String, Object?> json) {
    _requireKeys(json, const {'id', 'name', 'slug', 'image_url'});
    return CategoryChip(
      id: _requiredInt(json, 'id'),
      name: _requiredString(json, 'name'),
      slug: _requiredString(json, 'slug'),
      imageUrl: _nullableHttpUrl(json, 'image_url'),
    );
  }

  final int id;
  final String name;
  final String slug;
  final Uri? imageUrl;
}

class CustomAmountConfig {
  const CustomAmountConfig({
    required this.min,
    required this.max,
    required this.step,
    required this.unitLabel,
  });

  factory CustomAmountConfig.fromJson(Map<String, Object?> json) {
    _requireKeys(json, const {'min', 'max', 'step', 'unit_label'});
    return CustomAmountConfig(
      min: _nullablePositiveInt(json, 'min'),
      max: _nullablePositiveInt(json, 'max'),
      step: _nullablePositiveInt(json, 'step'),
      unitLabel: _nullableStringAllowEmpty(json, 'unit_label'),
    );
  }

  final int? min;
  final int? max;
  final int? step;
  final String? unitLabel;

  bool get hasAnyBound =>
      min != null || max != null || step != null || unitLabel != null;
}

class ProductOption {
  const ProductOption({
    required this.id,
    required this.name,
    required this.amountMode,
    required this.unitPrice,
    required this.customAmount,
    required this.minimumPrice,
  });

  factory ProductOption.fromJson(Map<String, Object?> json) {
    _requireKeys(json, const {
      'id',
      'name',
      'amount_mode',
      'unit_price',
      'custom_amount',
      'minimum_price',
    });
    final modeRaw = _requiredString(json, 'amount_mode');
    final mode = switch (modeRaw) {
      'fixed' => ProductAmountMode.fixed,
      'custom' => ProductAmountMode.custom,
      _ => throw FormatException('Unsupported amount_mode: $modeRaw'),
    };
    return ProductOption(
      id: _requiredInt(json, 'id'),
      name: _requiredString(json, 'name'),
      amountMode: mode,
      unitPrice: _nullableMoney(json, 'unit_price'),
      customAmount: _nullableCustomAmount(json, 'custom_amount'),
      minimumPrice: _nullableMoney(json, 'minimum_price'),
    );
  }

  final int id;
  final String name;
  final ProductAmountMode amountMode;
  final Money? unitPrice;
  final CustomAmountConfig? customAmount;
  final Money? minimumPrice;

  bool get isFixed => amountMode == ProductAmountMode.fixed;
  bool get isCustom => amountMode == ProductAmountMode.custom;
}

class PackageSummary {
  const PackageSummary({
    required this.id,
    required this.name,
    required this.slug,
    required this.imageUrl,
    required this.productsCount,
    required this.fromPrice,
    required this.category,
  });

  factory PackageSummary.fromJson(Map<String, Object?> json) {
    _requireKeys(json, const {
      'id',
      'name',
      'slug',
      'image_url',
      'products_count',
      'from_price',
      'category',
    });
    return PackageSummary(
      id: _requiredInt(json, 'id'),
      name: _requiredString(json, 'name'),
      slug: _requiredString(json, 'slug'),
      imageUrl: _nullableHttpUrl(json, 'image_url'),
      productsCount: _requiredNonNegativeInt(json, 'products_count'),
      fromPrice: _nullableMoney(json, 'from_price'),
      category: _nullableCategorySummary(json, 'category'),
    );
  }

  final int id;
  final String name;
  final String slug;
  final Uri? imageUrl;
  final int productsCount;
  final Money? fromPrice;
  final CategorySummary? category;
}

class FrequentlyOrderedPackage extends PackageSummary {
  const FrequentlyOrderedPackage({
    required super.id,
    required super.name,
    required super.slug,
    required super.imageUrl,
    required super.productsCount,
    required super.fromPrice,
    required super.category,
    required this.timesOrdered,
  });

  factory FrequentlyOrderedPackage.fromJson(Map<String, Object?> json) {
    final base = PackageSummary.fromJson(json);
    _requireKeys(json, const {'times_ordered'});
    final times = _requiredInt(json, 'times_ordered');
    if (times < 1) {
      throw const FormatException('times_ordered must be at least 1.');
    }
    return FrequentlyOrderedPackage(
      id: base.id,
      name: base.name,
      slug: base.slug,
      imageUrl: base.imageUrl,
      productsCount: base.productsCount,
      fromPrice: base.fromPrice,
      category: base.category,
      timesOrdered: times,
    );
  }

  final int timesOrdered;
}

class PackageDetail extends PackageSummary {
  const PackageDetail({
    required super.id,
    required super.name,
    required super.slug,
    required super.imageUrl,
    required super.productsCount,
    required super.fromPrice,
    required super.category,
    required this.description,
    required this.products,
  });

  factory PackageDetail.fromJson(Map<String, Object?> json) {
    _requireKeys(json, const {
      'id',
      'name',
      'slug',
      'description',
      'image_url',
      'products_count',
      'from_price',
      'category',
      'products',
    });
    final productsRaw = json['products'];
    if (productsRaw is! List) {
      throw const FormatException('products must be an array.');
    }
    return PackageDetail(
      id: _requiredInt(json, 'id'),
      name: _requiredString(json, 'name'),
      slug: _requiredString(json, 'slug'),
      description: _nullableStringAllowEmpty(json, 'description'),
      imageUrl: _nullableHttpUrl(json, 'image_url'),
      productsCount: _requiredNonNegativeInt(json, 'products_count'),
      fromPrice: _nullableMoney(json, 'from_price'),
      category: _nullableCategorySummary(json, 'category'),
      products: [
        for (final item in productsRaw)
          ProductOption.fromJson(_asObjectMap(item, 'products item')),
      ],
    );
  }

  final String? description;
  final List<ProductOption> products;
}

class OffsetPagination {
  const OffsetPagination({
    required this.page,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });

  factory OffsetPagination.fromJson(Map<String, Object?> json) {
    _requireKeys(json, const {'page', 'per_page', 'total', 'last_page'});
    final page = _requiredInt(json, 'page');
    final perPage = _requiredInt(json, 'per_page');
    final total = _requiredNonNegativeInt(json, 'total');
    final lastPage = _requiredInt(json, 'last_page');
    if (page < 1 || lastPage < 1 || perPage < 1 || perPage > 50) {
      throw const FormatException('Invalid pagination metadata.');
    }
    return OffsetPagination(
      page: page,
      perPage: perPage,
      total: total,
      lastPage: lastPage,
    );
  }

  final int page;
  final int perPage;
  final int total;
  final int lastPage;

  bool get hasNextPage => page < lastPage;
}

class CatalogHome {
  const CatalogHome({
    required this.frequentlyOrdered,
    required this.featuredPackages,
    required this.categories,
    required this.pricesVisible,
  });

  factory CatalogHome.fromJson(Map<String, Object?> json) {
    _requireKeys(json, const {'data', 'meta'});
    final data = _requiredMap(json, 'data');
    final meta = _requiredMap(json, 'meta');
    _requireKeys(data, const {
      'frequently_ordered',
      'featured_packages',
      'categories',
    });
    _requireKeys(meta, const {'prices_visible'});
    return CatalogHome(
      frequentlyOrdered: _mapList(
        data['frequently_ordered'],
        'frequently_ordered',
        FrequentlyOrderedPackage.fromJson,
      ),
      featuredPackages: _mapList(
        data['featured_packages'],
        'featured_packages',
        PackageSummary.fromJson,
      ),
      categories: _mapList(
        data['categories'],
        'categories',
        CategoryChip.fromJson,
      ),
      pricesVisible: _requiredBool(meta, 'prices_visible'),
    );
  }

  final List<FrequentlyOrderedPackage> frequentlyOrdered;
  final List<PackageSummary> featuredPackages;
  final List<CategoryChip> categories;
  final bool pricesVisible;
}

class PackageListPage {
  const PackageListPage({
    required this.packages,
    required this.pricesVisible,
    required this.pagination,
  });

  factory PackageListPage.fromJson(Map<String, Object?> json) {
    _requireKeys(json, const {'data', 'meta'});
    final meta = _requiredMap(json, 'meta');
    _requireKeys(meta, const {'prices_visible', 'pagination'});
    final data = json['data'];
    if (data is! List) {
      throw const FormatException('Package list data must be an array.');
    }
    return PackageListPage(
      packages: [
        for (final item in data)
          PackageSummary.fromJson(_asObjectMap(item, 'package')),
      ],
      pricesVisible: _requiredBool(meta, 'prices_visible'),
      pagination: OffsetPagination.fromJson(_requiredMap(meta, 'pagination')),
    );
  }

  final List<PackageSummary> packages;
  final bool pricesVisible;
  final OffsetPagination pagination;
}

class PackageDetailResult {
  const PackageDetailResult({
    required this.package,
    required this.pricesVisible,
  });

  factory PackageDetailResult.fromJson(Map<String, Object?> json) {
    _requireKeys(json, const {'data', 'meta'});
    final meta = _requiredMap(json, 'meta');
    _requireKeys(meta, const {'prices_visible'});
    return PackageDetailResult(
      package: PackageDetail.fromJson(_requiredMap(json, 'data')),
      pricesVisible: _requiredBool(meta, 'prices_visible'),
    );
  }

  final PackageDetail package;
  final bool pricesVisible;
}

class PackageListQuery {
  const PackageListQuery({
    this.categoryId,
    this.q,
    this.page = 1,
    this.perPage = 24,
  });

  final int? categoryId;
  final String? q;
  final int page;
  final int perPage;

  PackageListQuery copyWith({
    int? categoryId,
    bool clearCategoryId = false,
    String? q,
    bool clearQ = false,
    int? page,
    int? perPage,
  }) {
    return PackageListQuery(
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      q: clearQ ? null : (q ?? this.q),
      page: page ?? this.page,
      perPage: perPage ?? this.perPage,
    );
  }

  Map<String, Object?> toQueryParameters() {
    final params = <String, Object?>{'page': page, 'per_page': perPage};
    if (categoryId != null) {
      params['category_id'] = categoryId;
    }
    final trimmed = q?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      params['q'] = trimmed;
    }
    return params;
  }
}

final _moneyAmountPattern = RegExp(r'^-?\d+\.\d{2}$');

void _requireKeys(Map<String, Object?> json, Set<String> keys) {
  for (final key in keys) {
    if (!json.containsKey(key)) {
      throw FormatException('Missing required catalog field: $key');
    }
  }
}

Map<String, Object?> _requiredMap(Map<String, Object?> json, String key) {
  return _asObjectMap(json[key], key);
}

Map<String, Object?> _asObjectMap(Object? value, String label) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((mapKey, mapValue) => MapEntry('$mapKey', mapValue));
  }
  throw FormatException('$label must be an object.');
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FormatException('$key must be a non-empty string.');
}

String? _nullableStringAllowEmpty(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }
  throw FormatException('$key must be a string or null.');
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  throw FormatException('$key must be an integer.');
}

int _requiredNonNegativeInt(Map<String, Object?> json, String key) {
  final value = _requiredInt(json, key);
  if (value < 0) {
    throw FormatException('$key must be >= 0.');
  }
  return value;
}

int? _nullablePositiveInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is int) {
    if (value < 1) {
      return null;
    }
    return value;
  }
  throw FormatException('$key must be an integer or null.');
}

bool _requiredBool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is bool) {
    return value;
  }
  throw FormatException('$key must be a boolean.');
}

Uri? _nullableHttpUrl(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('$key must be a string or null.');
  }
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !uri.isAbsolute ||
      !const {'http', 'https'}.contains(uri.scheme)) {
    // Laravel already nulls unsafe hosts; soft-null defensive leftovers.
    return null;
  }
  return uri;
}

Money? _nullableMoney(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  return Money.fromJson(_asObjectMap(value, key));
}

CustomAmountConfig? _nullableCustomAmount(
  Map<String, Object?> json,
  String key,
) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  return CustomAmountConfig.fromJson(_asObjectMap(value, key));
}

CategorySummary? _nullableCategorySummary(
  Map<String, Object?> json,
  String key,
) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  return CategorySummary.fromJson(_asObjectMap(value, key));
}

List<T> _mapList<T>(
  Object? value,
  String label,
  T Function(Map<String, Object?> json) map,
) {
  if (value is! List) {
    throw FormatException('$label must be an array.');
  }
  return [for (final item in value) map(_asObjectMap(item, '$label item'))];
}
