import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indirimgo_mobile/core/theme/app_theme.dart';

void main() {
  const aaNormalText = 4.5;
  const aaNonText = 3.0;

  for (final brightness in Brightness.values) {
    final theme = brightness == Brightness.light
        ? AppTheme.light
        : AppTheme.dark;
    final label = brightness.name;

    test('$label primary and onPrimary meet text contrast', () {
      expect(
        contrastRatio(theme.colorScheme.primary, theme.colorScheme.onPrimary),
        greaterThanOrEqualTo(aaNormalText),
      );
    });

    test('$label tertiary and onTertiary meet text contrast', () {
      expect(
        contrastRatio(theme.colorScheme.tertiary, theme.colorScheme.onTertiary),
        greaterThanOrEqualTo(aaNormalText),
      );
    });

    test('$label surface and onSurface meet text contrast', () {
      expect(
        contrastRatio(theme.colorScheme.surface, theme.colorScheme.onSurface),
        greaterThanOrEqualTo(aaNormalText),
      );
    });

    test('$label error and onError meet text contrast', () {
      expect(
        contrastRatio(theme.colorScheme.error, theme.colorScheme.onError),
        greaterThanOrEqualTo(aaNormalText),
      );
    });

    test('$label tertiary focus indicator meets non-text contrast', () {
      expect(
        contrastRatio(
          theme.scaffoldBackgroundColor,
          theme.colorScheme.tertiary,
        ),
        greaterThanOrEqualTo(aaNonText),
      );
    });
  }
}

double contrastRatio(Color a, Color b) {
  final lighter = math.max(relativeLuminance(a), relativeLuminance(b));
  final darker = math.min(relativeLuminance(a), relativeLuminance(b));
  return (lighter + 0.05) / (darker + 0.05);
}

double relativeLuminance(Color color) {
  double channel(double srgb) {
    return srgb <= 0.03928
        ? srgb / 12.92
        : math.pow((srgb + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}
