import 'package:indirimgo_mobile/features/catalog/domain/catalog_models.dart';

class WalletSummary {
  const WalletSummary({
    required this.availableToSpend,
    required this.pricesVisible,
  });

  factory WalletSummary.fromJson(Map<String, Object?> json) {
    _requireKeys(json, const {'data', 'meta'});
    final data = _asObjectMap(json['data'], 'data');
    final meta = _asObjectMap(json['meta'], 'meta');
    _requireKeys(data, const {'available_to_spend'});
    _requireKeys(meta, const {'prices_visible'});
    return WalletSummary(
      availableToSpend: Money.fromJson(
        _asObjectMap(data['available_to_spend'], 'available_to_spend'),
      ),
      pricesVisible: _requiredBool(meta, 'prices_visible'),
    );
  }

  final Money availableToSpend;

  /// Catalog visibility flag from the wallet response meta. Wallet money remains
  /// available even when this is false.
  final bool pricesVisible;
}

void _requireKeys(Map<String, Object?> json, Set<String> keys) {
  for (final key in keys) {
    if (!json.containsKey(key)) {
      throw FormatException('Missing required wallet field: $key');
    }
  }
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

bool _requiredBool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is bool) {
    return value;
  }
  throw FormatException('$key must be a boolean.');
}
