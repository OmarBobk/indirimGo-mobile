import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indirimgo_mobile/core/localization/generated/app_localizations.dart';
import 'package:indirimgo_mobile/core/theme/app_theme.dart';
import 'package:indirimgo_mobile/core/widgets/customer_state_badge.dart';

void main() {
  const states = [
    'needs_attention',
    'in_progress',
    'delivered',
    'refunded',
    'other',
  ];

  test('icons distinguish delivered from refunded', () {
    expect(CustomerStateBadge.iconFor('delivered'), Icons.check_circle_outline);
    expect(CustomerStateBadge.iconFor('refunded'), Icons.replay);
    expect(
      CustomerStateBadge.iconFor('delivered'),
      isNot(CustomerStateBadge.iconFor('refunded')),
    );
    expect(CustomerStateBadge.iconFor('needs_attention'), Icons.error_outline);
    expect(CustomerStateBadge.iconFor('in_progress'), Icons.hourglass_top);
    expect(CustomerStateBadge.iconFor('mystery'), Icons.help_outline);
  });

  for (final brightness in Brightness.values) {
    final theme = brightness == Brightness.light
        ? AppTheme.light
        : AppTheme.dark;
    test('$brightness badge text contrast is at least 4.5:1', () {
      for (final state in states) {
        final tone = CustomerStateBadge.toneFor(state, theme.colorScheme);
        expect(
          _contrastRatio(tone.background, tone.foreground),
          greaterThanOrEqualTo(4.5),
          reason: '$state ${brightness.name}',
        );
      }
    });
  }

  testWidgets('badge exposes a single status semantic label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: CustomerStateBadge(state: 'delivered')),
      ),
    );
    expect(find.text('Delivered'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    expect(find.bySemanticsLabel('Order status: Delivered'), findsOneWidget);
  });
}

double _contrastRatio(Color a, Color b) {
  final lighter = math.max(_relativeLuminance(a), _relativeLuminance(b));
  final darker = math.min(_relativeLuminance(a), _relativeLuminance(b));
  return (lighter + 0.05) / (darker + 0.05);
}

double _relativeLuminance(Color color) {
  double channel(double srgb) {
    return srgb <= 0.03928
        ? srgb / 12.92
        : math.pow((srgb + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}
