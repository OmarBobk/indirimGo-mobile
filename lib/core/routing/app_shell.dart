import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:indirimgo_mobile/core/localization/generated/app_localizations.dart';
import 'package:indirimgo_mobile/core/routing/shell_visibility.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportVisibility());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reportVisibility();
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reportVisibility();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref
        .read(shellVisibilityProvider.notifier)
        .setForeground(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ref.read(shellVisibilityProvider.notifier).clearShell();
    super.dispose();
  }

  void _reportVisibility() {
    final location = GoRouterState.of(context).matchedLocation;
    ref
        .read(shellVisibilityProvider.notifier)
        .reportShell(
          branchIndex: widget.navigationShell.currentIndex,
          location: location,
        );
  }

  void _selectBranch(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  Future<void> _onPop(bool didPop, Object? result) async {
    if (didPop) {
      return;
    }
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
      return;
    }
    if (widget.navigationShell.currentIndex != homeShellBranch) {
      widget.navigationShell.goBranch(homeShellBranch);
      return;
    }
    await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final location = GoRouterState.of(context).matchedLocation;
    final hideChrome = hideChromeForLocation(location);
    final destinations = [
      NavigationDestination(
        key: const Key('nav-home'),
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const Icon(Icons.home),
        label: l10n.navHome,
      ),
      NavigationDestination(
        key: const Key('nav-packages'),
        icon: const Icon(Icons.grid_view_outlined),
        selectedIcon: const Icon(Icons.grid_view),
        label: l10n.navPackages,
      ),
      NavigationDestination(
        key: const Key('nav-orders'),
        icon: const Icon(Icons.receipt_long_outlined),
        selectedIcon: const Icon(Icons.receipt_long),
        label: l10n.navOrders,
      ),
      NavigationDestination(
        key: const Key('nav-account'),
        icon: const Icon(Icons.person_outline),
        selectedIcon: const Icon(Icons.person),
        label: l10n.navAccount,
      ),
    ];
    final railDestinations = [
      NavigationRailDestination(
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const Icon(Icons.home),
        label: Text(l10n.navHome),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.grid_view_outlined),
        selectedIcon: const Icon(Icons.grid_view),
        label: Text(l10n.navPackages),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.receipt_long_outlined),
        selectedIcon: const Icon(Icons.receipt_long),
        label: Text(l10n.navOrders),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.person_outline),
        selectedIcon: const Icon(Icons.person),
        label: Text(l10n.navAccount),
      ),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPop,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useRail = !hideChrome && isWideNavigationLayout(constraints);
          return Scaffold(
            body: Row(
              children: [
                if (useRail)
                  SafeArea(
                    child: NavigationRail(
                      key: const Key('app-navigation-rail'),
                      selectedIndex: widget.navigationShell.currentIndex,
                      onDestinationSelected: _selectBranch,
                      labelType: NavigationRailLabelType.all,
                      destinations: railDestinations,
                    ),
                  ),
                Expanded(child: widget.navigationShell),
              ],
            ),
            bottomNavigationBar: hideChrome || useRail
                ? null
                : NavigationBar(
                    key: const Key('app-navigation-bar'),
                    selectedIndex: widget.navigationShell.currentIndex,
                    onDestinationSelected: _selectBranch,
                    destinations: destinations,
                  ),
          );
        },
      ),
    );
  }
}
