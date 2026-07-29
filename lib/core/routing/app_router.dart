import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:indirimgo_mobile/features/auth/presentation/auth_controller.dart';
import 'package:indirimgo_mobile/features/auth/presentation/login_screen.dart';
import 'package:indirimgo_mobile/features/auth/presentation/startup_screen.dart';
import 'package:indirimgo_mobile/features/auth/presentation/two_factor_screen.dart';
import 'package:indirimgo_mobile/features/shell/presentation/shell_screen.dart';

abstract final class AppRoutes {
  static const startup = '/startup';
  static const login = '/login';
  static const twoFactor = '/two-factor';
  static const shell = '/app';
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.onDispose(refresh.dispose);
  ref.listen<AuthState>(
    authControllerProvider,
    (_, __) => refresh.notify(),
  );

  return GoRouter(
    initialLocation: AppRoutes.startup,
    refreshListenable: refresh,
    redirect: (context, routeState) {
      final auth = ref.read(authControllerProvider);
      final location = routeState.matchedLocation;

      final target = switch (auth.phase) {
        AuthPhase.initializing || AuthPhase.verificationFailed =>
          AppRoutes.startup,
        AuthPhase.unauthenticated => AppRoutes.login,
        AuthPhase.submittingLogin when auth.challenge != null =>
          AppRoutes.twoFactor,
        AuthPhase.submittingLogin => AppRoutes.login,
        AuthPhase.twoFactorRequired => AppRoutes.twoFactor,
        AuthPhase.authenticated || AuthPhase.loggingOut => AppRoutes.shell,
      };

      return location == target ? null : target;
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
        builder: (context, state) => const ShellScreen(),
      ),
    ],
  );
});

class _RouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}
