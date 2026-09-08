import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:indirimgo_mobile/core/routing/app_shell.dart';
import 'package:indirimgo_mobile/features/auth/presentation/auth_controller.dart';
import 'package:indirimgo_mobile/features/auth/presentation/login_screen.dart';
import 'package:indirimgo_mobile/features/auth/presentation/startup_screen.dart';
import 'package:indirimgo_mobile/features/auth/presentation/two_factor_screen.dart';
import 'package:indirimgo_mobile/features/catalog/presentation/account/account_screen.dart';
import 'package:indirimgo_mobile/features/catalog/presentation/home/catalog_home_screen.dart';
import 'package:indirimgo_mobile/features/catalog/presentation/package_detail/package_detail_screen.dart';
import 'package:indirimgo_mobile/features/catalog/presentation/packages/package_list_screen.dart';
import 'package:indirimgo_mobile/features/orders/presentation/order_controllers.dart';
import 'package:indirimgo_mobile/features/orders/presentation/order_detail_screen.dart';
import 'package:indirimgo_mobile/features/orders/presentation/orders_list_screen.dart';
import 'package:indirimgo_mobile/features/purchase/presentation/buy/purchase_form_screen.dart';
import 'package:indirimgo_mobile/features/purchase/presentation/purchase_controllers.dart';
import 'package:indirimgo_mobile/features/purchase/presentation/recovery/checkout_recovery_screen.dart';
import 'package:indirimgo_mobile/features/purchase/presentation/review/checkout_review_screen.dart';

abstract final class AppRoutes {
  static const startup = '/startup';
  static const login = '/login';
  static const twoFactor = '/two-factor';
  static const shell = '/app';
  static const packages = '/app/packages';
  static const account = '/app/account';
  static const orders = '/app/orders';
  static const checkoutReview = '/app/checkout/review';
  static const checkoutRecovery = '/app/checkout/recovery';

  static String packageDetail(int id) => '/app/packages/$id';

  static String packageBuy(int packageId, int productId) =>
      '/app/packages/$packageId/buy?productId=$productId';

  static String orderReceipt(String orderNumber) => '/app/orders/$orderNumber';

  static String packagesWithCategory(int categoryId, {String? name}) {
    final params = <String, String>{'category_id': '$categoryId'};
    final trimmed = name?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      params['category_name'] = trimmed;
    }
    return Uri(path: '/app/packages', queryParameters: params).toString();
  }
}

final _homeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'home-branch');
final _packagesNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'packages-branch',
);
final _ordersNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'orders-branch',
);
final _accountNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'account-branch',
);

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.onDispose(refresh.dispose);
  ref.listen<AuthState>(authControllerProvider, (_, _) => refresh.notify());
  ref.listen<CheckoutRecoveryState>(
    checkoutRecoveryControllerProvider,
    (_, _) => refresh.notify(),
  );
  ref.listen<int?>(orderCustomerIdProvider, (previous, next) {
    if (previous == next) {
      return;
    }
    for (final key in [
      _homeNavigatorKey,
      _packagesNavigatorKey,
      _ordersNavigatorKey,
      _accountNavigatorKey,
    ]) {
      key.currentState?.popUntil((route) => route.isFirst);
    }
  });

  final router = GoRouter(
    initialLocation: AppRoutes.startup,
    refreshListenable: refresh,
    redirect: (context, routeState) {
      final auth = ref.read(authControllerProvider);
      final location = routeState.matchedLocation;
      final isAppRoute =
          location == AppRoutes.shell ||
          location.startsWith('${AppRoutes.shell}/');

      final authRedirect = switch (auth.phase) {
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
      if (authRedirect != null) {
        return authRedirect;
      }

      if (auth.phase == AuthPhase.authenticated) {
        final recovery = ref.read(checkoutRecoveryControllerProvider);
        final onRecovery = location == AppRoutes.checkoutRecovery;
        final onReceipt = location.startsWith('${AppRoutes.orders}/');
        if (recovery.phase == CheckoutRecoveryPhase.completed &&
            recovery.receipt != null &&
            !onReceipt) {
          return AppRoutes.orderReceipt(recovery.receipt!.orderNumber);
        }
        if ((recovery.phase == CheckoutRecoveryPhase.checking ||
                recovery.phase == CheckoutRecoveryPhase.processing) &&
            !onRecovery &&
            !onReceipt) {
          return AppRoutes.checkoutRecovery;
        }
      }
      return null;
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
        path: AppRoutes.checkoutReview,
        builder: (context, state) => const CheckoutReviewScreen(),
      ),
      GoRoute(
        path: AppRoutes.checkoutRecovery,
        builder: (context, state) => const CheckoutRecoveryScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _homeNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.shell,
                builder: (context, state) => const CatalogHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _packagesNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.packages,
                builder: (context, state) {
                  final categoryRaw = state.uri.queryParameters['category_id'];
                  final categoryId = int.tryParse(categoryRaw ?? '');
                  final q = state.uri.queryParameters['q'];
                  final categoryName =
                      state.uri.queryParameters['category_name'];
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
                    routes: [
                      GoRoute(
                        path: 'buy',
                        builder: (context, state) {
                          final id = int.tryParse(
                            state.pathParameters['id'] ?? '',
                          );
                          final productId = int.tryParse(
                            state.uri.queryParameters['productId'] ?? '',
                          );
                          return PurchaseFormScreen(
                            packageId: id ?? 0,
                            productId: productId ?? 0,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _ordersNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.orders,
                builder: (context, state) => const OrdersListScreen(),
                routes: [
                  GoRoute(
                    path: ':orderNumber',
                    builder: (context, state) {
                      final orderNumber =
                          state.pathParameters['orderNumber'] ?? '';
                      return OrderDetailScreen(orderNumber: orderNumber);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _accountNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.account,
                builder: (context, state) => const AccountScreen(),
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
