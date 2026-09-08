import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indirimgo_mobile/core/routing/shell_visibility.dart';

void main() {
  test('polling requires foreground, orders branch, and visible detail', () {
    const hidden = ShellVisibility(
      appForeground: true,
      shellReported: true,
      selectedBranchIndex: 2,
      matchedLocation: '/app/orders',
    );
    expect(hidden.allowsOrderPolling('ORD-1'), isFalse);

    const otherTab = ShellVisibility(
      appForeground: true,
      shellReported: true,
      selectedBranchIndex: 0,
      matchedLocation: '/app/orders/ORD-1',
    );
    expect(otherTab.allowsOrderPolling('ORD-1'), isFalse);

    const background = ShellVisibility(
      appForeground: false,
      shellReported: true,
      selectedBranchIndex: 2,
      matchedLocation: '/app/orders/ORD-1',
    );
    expect(background.allowsOrderPolling('ORD-1'), isFalse);

    const visible = ShellVisibility(
      appForeground: true,
      shellReported: true,
      selectedBranchIndex: 2,
      matchedLocation: '/app/orders/ORD-1',
    );
    expect(visible.allowsOrderPolling('ORD-1'), isTrue);
    expect(visible.allowsOrderPolling('ORD-2'), isFalse);
  });

  test('unit tests without a shell still allow polling', () {
    expect(const ShellVisibility().allowsOrderPolling('ORD-1'), isTrue);
  });

  test('chrome is hidden on buy and checkout routes', () {
    expect(hideChromeForLocation('/app/packages/12/buy'), isTrue);
    expect(hideChromeForLocation('/app/checkout/review'), isTrue);
    expect(hideChromeForLocation('/app/checkout/recovery'), isTrue);
    expect(hideChromeForLocation('/app'), isFalse);
    expect(hideChromeForLocation('/app/orders/ORD-1'), isFalse);
  });

  test('wide navigation starts at 840 logical pixels', () {
    expect(
      isWideNavigationLayout(const BoxConstraints(maxWidth: 839)),
      isFalse,
    );
    expect(isWideNavigationLayout(const BoxConstraints(maxWidth: 840)), isTrue);
  });
}
