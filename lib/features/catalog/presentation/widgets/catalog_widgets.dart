import 'package:flutter/material.dart';
import 'package:indirimgo_mobile/core/localization/generated/app_localizations.dart';
import 'package:indirimgo_mobile/core/theme/app_theme.dart';
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

class PackageImage extends StatelessWidget {
  const PackageImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height = 96,
    this.borderRadius,
    this.semanticLabel,
  });

  final Uri? imageUrl;
  final double? width;
  final double height;
  final BorderRadius? borderRadius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppRadii.input);
    final placeholder = _PackageImagePlaceholder(height: height, width: width);

    Widget child;
    if (imageUrl == null) {
      child = placeholder;
    } else {
      child = Image.network(
        imageUrl.toString(),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            return child;
          }
          return SizedBox(
            width: width,
            height: height,
            child: const Center(
              child: SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      );
    }

    return Semantics(
      label: semanticLabel,
      image: semanticLabel != null,
      excludeSemantics: semanticLabel == null,
      child: ClipRRect(borderRadius: radius, child: child),
    );
  }
}

class _PackageImagePlaceholder extends StatelessWidget {
  const _PackageImagePlaceholder({required this.height, this.width});

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      color: scheme.onSurface.withValues(alpha: 0.06),
      alignment: Alignment.center,
      child: Icon(
        Icons.inventory_2_outlined,
        color: scheme.onSurface.withValues(alpha: 0.35),
        size: height * 0.35,
      ),
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
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PackageImage(imageUrl: package.imageUrl, width: 72, height: 72),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        package.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (category != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          category,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                const Icon(Icons.chevron_right),
              ],
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
