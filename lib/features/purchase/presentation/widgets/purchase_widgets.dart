import 'package:flutter/material.dart';
import 'package:indirimgo_mobile/core/localization/generated/app_localizations.dart';
import 'package:indirimgo_mobile/core/theme/app_theme.dart';
import 'package:indirimgo_mobile/features/catalog/domain/catalog_models.dart';
import 'package:indirimgo_mobile/features/catalog/presentation/widgets/catalog_widgets.dart';

/// Server-formatted money text, always LTR.
class PurchaseMoneyText extends StatelessWidget {
  const PurchaseMoneyText({
    super.key,
    required this.money,
    this.label,
    this.style,
  });

  final Money money;
  final String? label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return CatalogPriceText(
      pricesVisible: true,
      money: money,
      prefix: label == null ? null : '$label ',
      style: style,
    );
  }
}

class PurchaseStatusView extends StatelessWidget {
  const PurchaseStatusView({
    super.key,
    required this.title,
    required this.body,
    this.icon = Icons.info_outline,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String body;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: theme.colorScheme.tertiary),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PurchaseSectionLabel extends StatelessWidget {
  const PurchaseSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

String localizedRequirementError(AppLocalizations l10n, String? code) {
  return switch (code) {
    'required' => l10n.requirementRequired,
    _ => l10n.invalidFieldValue,
  };
}
