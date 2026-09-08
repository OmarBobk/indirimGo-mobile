import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const int homeShellBranch = 0;
const int packagesShellBranch = 1;
const int ordersShellBranch = 2;
const int accountShellBranch = 3;

class ShellVisibility {
  const ShellVisibility({
    this.appForeground = true,
    this.shellReported = false,
    this.selectedBranchIndex = 0,
    this.matchedLocation = '',
  });

  final bool appForeground;
  final bool shellReported;
  final int selectedBranchIndex;
  final String matchedLocation;

  bool get ordersBranchSelected => selectedBranchIndex == ordersShellBranch;

  bool allowsOrderPolling(String orderNumber) {
    if (!appForeground) {
      return false;
    }
    if (!shellReported) {
      return true;
    }
    return ordersBranchSelected &&
        matchedLocation == '/app/orders/$orderNumber';
  }

  ShellVisibility copyWith({
    bool? appForeground,
    bool? shellReported,
    int? selectedBranchIndex,
    String? matchedLocation,
  }) {
    return ShellVisibility(
      appForeground: appForeground ?? this.appForeground,
      shellReported: shellReported ?? this.shellReported,
      selectedBranchIndex: selectedBranchIndex ?? this.selectedBranchIndex,
      matchedLocation: matchedLocation ?? this.matchedLocation,
    );
  }
}

class ShellVisibilityController extends Notifier<ShellVisibility> {
  @override
  ShellVisibility build() => const ShellVisibility();

  void setForeground(bool foreground) {
    if (state.appForeground == foreground) {
      return;
    }
    state = state.copyWith(appForeground: foreground);
  }

  void reportShell({required int branchIndex, required String location}) {
    if (state.shellReported &&
        state.selectedBranchIndex == branchIndex &&
        state.matchedLocation == location) {
      return;
    }
    state = state.copyWith(
      shellReported: true,
      selectedBranchIndex: branchIndex,
      matchedLocation: location,
    );
  }

  void clearShell() {
    state = state.copyWith(shellReported: false);
  }
}

final shellVisibilityProvider =
    NotifierProvider<ShellVisibilityController, ShellVisibility>(
      ShellVisibilityController.new,
    );

bool hideChromeForLocation(String location) {
  return location.contains('/buy') ||
      location.contains('/checkout/review') ||
      location.contains('/checkout/recovery');
}

bool isWideNavigationLayout(BoxConstraints constraints) =>
    constraints.maxWidth >= 840;
