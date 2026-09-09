import 'package:flutter/material.dart';
import 'package:indirimgo_mobile/core/localization/generated/app_localizations.dart';
import 'package:indirimgo_mobile/core/theme/app_theme.dart';
import 'package:indirimgo_mobile/core/widgets/catalog_media_frame.dart';
import 'package:indirimgo_mobile/features/catalog/domain/catalog_models.dart';

/// Renders server-formatted prices only. Never formats [Money.amount] locally.
class CatalogPriceText extends StatelessWidget {
  const CatalogPriceText({
    super.key,
    required this.pricesVisible,
    required this.money,
    this.prefix,
    this.style,
  });

  final bool pricesVisible;
  final Money? money;
  final String? prefix;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textStyle =
        style ??
        Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.tertiary,
        );

    if (!pricesVisible) {
      return Text(
        l10n.priceHidden,
        style: textStyle,
        textDirection: Directionality.of(context),
      );
    }
    if (money == null) {
      return Text(
        l10n.priceUnavailable,
        style: textStyle,
        textDirection: Directionality.of(context),
      );
    }

    final formatted = money!.display.formatted;
    final label = prefix == null ? formatted : '$prefix$formatted';
    return Text(
      label,
      style: textStyle,
      // Keep currency numerals visually stable across RTL/LTR.
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.start,
    );
  }
}

class PackageCard extends StatelessWidget {
  const PackageCard({
    super.key,
    required this.package,
    required this.pricesVisible,
    required this.onTap,
    this.timesOrdered,
  });

  final PackageSummary package;
  final bool pricesVisible;
  final VoidCallback onTap;
  final int? timesOrdered;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final category = package.category?.name;
    final priceLabel = !pricesVisible
        ? l10n.priceHidden
        : package.fromPrice == null
        ? l10n.priceUnavailable
        : l10n.priceFrom(package.fromPrice!.display.formatted);
    final semantics = [
      package.name,
      ?category,
      priceLabel,
      if (timesOrdered != null) l10n.timesOrdered(timesOrdered!),
    ].join(', ');

    return Semantics(
      button: true,
      label: semantics,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('package-card-${package.id}'),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 88),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CatalogMediaFrame(
                    imageUrl: package.imageUrl,
                    size: 72,
                    semanticLabel: l10n.packageImageLabel,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          package.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.35,
                          ),
                        ),
                        if (category != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            category,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                              height: 1.4,
                            ),
                          ),
                        ],
                        if (timesOrdered != null) ...[
                          const SizedBox(height: 4),
                          ExcludeSemantics(
                            child: Text(
                              l10n.timesOrdered(timesOrdered!),
                              key: Key('times-ordered-${package.id}'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.75,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xs),
                        CatalogPriceText(
                          pricesVisible: pricesVisible,
                          money: package.fromPrice,
                          prefix: pricesVisible && package.fromPrice != null
                              ? '${l10n.fromPriceLabel} '
                              : null,
                        ),
                      ],
                    ),
                  ),
                  Transform.scale(
                    key: const Key('package-card-chevron-mirror'),
                    scaleX: Directionality.of(context) == TextDirection.rtl
                        ? -1.0
                        : 1.0,
                    child: const Icon(
                      Icons.chevron_right,
                      key: Key('package-card-chevron'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CategoryDiscoveryTile extends StatelessWidget {
  const CategoryDiscoveryTile({
    super.key,
    required this.category,
    required this.onTap,
  });

  final CategoryChip category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: category.name,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.input),
        child: InkWell(
          key: Key('category-chip-${category.id}'),
          borderRadius: BorderRadius.circular(AppRadii.input),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 88),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.xs),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CatalogMediaFrame(
                    imageUrl: category.imageUrl,
                    size: 56,
                    semanticLabel: l10n.categoryImageLabel,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 88,
                    child: Text(
                      category.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
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
      ),
    );
  }
}

class CatalogStatusView extends StatelessWidget {
  const CatalogStatusView({
    super.key,
    required this.title,
    required this.body,
    this.onRetry,
    this.actionLabel,
    this.icon = Icons.cloud_off_outlined,
  });

  final String title;
  final String body;
  final VoidCallback? onRetry;
  final String? actionLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      container: true,
      label: '$title. $body',
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.tertiary),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(body, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Semantics(
                button: true,
                label: actionLabel ?? l10n.retryAction,
                child: FilledButton(
                  key: const Key('catalog-retry'),
                  onPressed: onRetry,
                  child: Text(actionLabel ?? l10n.retryAction),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CatalogSectionHeader extends StatelessWidget {
  const CatalogSectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.only(
          top: AppSpacing.md,
          bottom: AppSpacing.sm,
        ),
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
    );
  }
}
