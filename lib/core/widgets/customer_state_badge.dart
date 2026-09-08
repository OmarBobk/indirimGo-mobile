import 'package:flutter/material.dart';
import 'package:indirimgo_mobile/core/localization/generated/app_localizations.dart';
import 'package:indirimgo_mobile/core/theme/app_theme.dart';
import 'package:indirimgo_mobile/features/orders/presentation/order_status_labels.dart';

class CustomerStateBadge extends StatelessWidget {
  const CustomerStateBadge({
    super.key,
    required this.state,
    this.compact = false,
  });

  final String state;
  final bool compact;

  static IconData iconFor(String state) {
    return switch (state) {
      'needs_attention' => Icons.error_outline,
      'in_progress' => Icons.hourglass_top,
      'delivered' => Icons.check_circle_outline,
      'refunded' => Icons.replay,
      _ => Icons.help_outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = localizedCustomerOrderState(l10n, state);
    final scheme = Theme.of(context).colorScheme;
    final palette = toneFor(state, scheme);

    return Semantics(
      label: l10n.customerStateBadgeSemantics(label),
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.background,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: palette.border),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 12,
              vertical: compact ? 6 : 8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  iconFor(state),
                  size: compact ? 16 : 18,
                  color: palette.foreground,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: palette.foreground,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static CustomerStateBadgeTone toneFor(String state, ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    return switch (state) {
      'needs_attention' => CustomerStateBadgeTone(
        background: isDark ? const Color(0xFF3B1511) : const Color(0xFFFDECEA),
        border: isDark ? const Color(0xFFFFB4AB) : BrandColors.error,
        foreground: isDark ? const Color(0xFFFFDAD6) : const Color(0xFF8C1D18),
      ),
      'in_progress' => CustomerStateBadgeTone(
        background: isDark ? const Color(0xFF2A2100) : const Color(0xFFFFF4D6),
        border: isDark ? BrandColors.yellowSoft : BrandColors.warning,
        foreground: isDark ? const Color(0xFFFFE08A) : const Color(0xFF6B4700),
      ),
      'delivered' => CustomerStateBadgeTone(
        background: isDark ? const Color(0xFF0F2B1C) : const Color(0xFFE3F6EA),
        border: isDark ? const Color(0xFF7AD0A1) : BrandColors.success,
        foreground: isDark ? const Color(0xFFB7F0CF) : const Color(0xFF0F5C32),
      ),
      'refunded' => CustomerStateBadgeTone(
        background: isDark ? const Color(0xFF1B2430) : const Color(0xFFEEF2F7),
        border: isDark ? const Color(0xFF9BB0C7) : const Color(0xFF5B6B7C),
        foreground: isDark ? const Color(0xFFD5E2F0) : const Color(0xFF2F3B47),
      ),
      _ => CustomerStateBadgeTone(
        background: scheme.surfaceContainerHighest,
        border: scheme.outline,
        foreground: scheme.onSurface,
      ),
    };
  }
}

class CustomerStateBadgeTone {
  const CustomerStateBadgeTone({
    required this.background,
    required this.border,
    required this.foreground,
  });

  final Color background;
  final Color border;
  final Color foreground;
}
