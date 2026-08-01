import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:indirimgo_mobile/app.dart';
import 'package:indirimgo_mobile/core/config/app_config.dart';
import 'package:indirimgo_mobile/core/storage/pending_checkout_store.dart';
import 'package:indirimgo_mobile/core/storage/token_storage.dart';
import 'package:indirimgo_mobile/features/auth/data/remote_auth_repository.dart';
import 'package:indirimgo_mobile/features/auth/domain/auth_repository.dart';
import 'package:indirimgo_mobile/features/catalog/data/remote_catalog_repository.dart';
import 'package:indirimgo_mobile/features/catalog/domain/catalog_repository.dart';
import 'package:indirimgo_mobile/features/purchase/data/remote_purchase_repository.dart';
import 'package:indirimgo_mobile/features/purchase/domain/purchase_repository.dart';
import 'package:indirimgo_mobile/features/wallet/data/remote_wallet_repository.dart';
import 'package:indirimgo_mobile/features/wallet/domain/wallet_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    const buildMode = kDebugMode
        ? AppBuildMode.debug
        : kProfileMode
        ? AppBuildMode.profile
        : AppBuildMode.release;
    final config = AppConfig.fromEnvironment(buildMode: buildMode);
    final storage = SecureTokenStorage();
    final pendingCheckoutStore = SecurePendingCheckoutStore();
    runApp(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          tokenStorageProvider.overrideWithValue(storage),
          pendingCheckoutStoreProvider.overrideWithValue(pendingCheckoutStore),
          authRepositoryProvider.overrideWith(
            (ref) => ref.watch(remoteAuthRepositoryProvider),
          ),
          catalogRepositoryProvider.overrideWith(
            (ref) => ref.watch(remoteCatalogRepositoryProvider),
          ),
          purchaseRepositoryProvider.overrideWith(
            (ref) => ref.watch(remotePurchaseRepositoryProvider),
          ),
          walletRepositoryProvider.overrideWith(
            (ref) => ref.watch(remoteWalletRepositoryProvider),
          ),
        ],
        child: const IndirimGoApp(),
      ),
    );
  } on FormatException {
    runApp(const ConfigurationErrorApp());
  }
}
