import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:indirimgo_mobile/app.dart';
import 'package:indirimgo_mobile/core/config/app_config.dart';
import 'package:indirimgo_mobile/core/storage/token_storage.dart';
import 'package:indirimgo_mobile/features/auth/data/remote_auth_repository.dart';
import 'package:indirimgo_mobile/features/auth/domain/auth_repository.dart';

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
    runApp(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          tokenStorageProvider.overrideWithValue(storage),
          authRepositoryProvider.overrideWith(
            (ref) => ref.watch(remoteAuthRepositoryProvider),
          ),
        ],
        child: const IndirimGoApp(),
      ),
    );
  } on FormatException {
    runApp(const ConfigurationErrorApp());
  }
}
