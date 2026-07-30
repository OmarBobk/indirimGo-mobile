import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:indirimgo_mobile/features/auth/presentation/auth_controller.dart';
import 'package:indirimgo_mobile/features/auth/presentation/login_screen.dart';
import 'package:indirimgo_mobile/features/auth/presentation/startup_screen.dart';
import 'package:indirimgo_mobile/features/auth/presentation/two_factor_screen.dart';
import 'package:indirimgo_mobile/features/catalog/presentation/account/account_screen.dart';
import 'package:indirimgo_mobile/features/catalog/presentation/home/catalog_home_screen.dart';
import 'package:indirimgo_mobile/features/catalog/presentation/package_detail/package_detail_screen.dart';
import 'package:indirimgo_mobile/features/catalog/presentation/packages/package_list_screen.dart';

abstract final class AppRoutes {
  static const startup = '/startup';
  static const login = '/login';
  static const twoFactor = '/two-factor';
  static const shell = '/app';
  static const packages = '/app/packages';
  static const account = '/app/account';

  static String packageDetail(int id) => '/app/packages/$id';

  static String packagesWithCategory(int categoryId, {String? name}) {
    final params = <String, String>{'category_id': '$categoryId'};
    final trimmed = name?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      params['category_name'] = trimmed;
    }
    return Uri(path: '/app/packages', queryParameters: params).toString();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.onDispose(refresh.dispose);
  ref.listen<AuthState>(authControllerProvider, (_, _) => refresh.notify());

  final router = GoRouter(
    initialLocation: AppRoutes.startup,
    refreshListenable: refresh,
    redirect: (context, routeState) {
      final auth = ref.read(authControllerProvider);
      final location = routeState.matchedLocation;
      final isAppRoute =
          location == AppRoutes.shell ||
          location.startsWith('${AppRoutes.shell}/');

      return switch (auth.phase) {
        AuthPhase.initializing || AuthPhase.verificationFailed =>
          location == AppRoutes.startup ? null : AppRoutes.startup,
        AuthPhase.unauthenticated =>
          location == AppRoutes.login ? null : AppRoutes.login,
        AuthPhase.submittingLogin when auth.challenge != null =>
          location == AppRoutes.twoFactor ? null : AppRoutes.twoFactor,
        AuthPhase.submittingLogin =>
          location == AppRoutes.login ? null : AppRoutes.login,
        AuthPhase.twoFactorRequired when auth.challenge != null =>
          location == AppRoutes.twoFactor ? null : AppRoutes.twoFactor,
        AuthPhase.twoFactorRequired =>
          location == AppRoutes.login ? null : AppRoutes.login,
        AuthPhase.authenticated ||
        AuthPhase.loggingOut => isAppRoute ? null : AppRoutes.shell,
      };
    },
    routes: [
      GoRoute(
        path: AppRoutes.startup,
        builder: (context, state) => const StartupScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.twoFactor,
        builder: (context, state) => const TwoFactorScreen(),
      ),
      GoRoute(
        path: AppRoutes.shell,
        builder: (context, state) => const CatalogHomeScreen(),
        routes: [
          GoRoute(
            path: 'account',
            builder: (context, state) => const AccountScreen(),
          ),
          GoRoute(
            path: 'packages',
            builder: (context, state) {
              final categoryRaw = state.uri.queryParameters['category_id'];
              final categoryId = int.tryParse(categoryRaw ?? '');
              final q = state.uri.queryParameters['q'];
              final categoryName = state.uri.queryParameters['category_name'];
              return PackageListScreen(
                categoryId: (categoryId != null && categoryId >= 1)
                    ? categoryId
                    : null,
                categoryName: categoryName,
                initialQuery: q,
              );
            },
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = int.tryParse(state.pathParameters['id'] ?? '');
                  return PackageDetailScreen(packageId: id ?? 0);
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _RouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}
