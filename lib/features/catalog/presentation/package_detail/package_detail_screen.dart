import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:indirimgo_mobile/core/localization/generated/app_localizations.dart';
import 'package:indirimgo_mobile/core/routing/app_router.dart';
import 'package:indirimgo_mobile/core/theme/app_theme.dart';
import 'package:indirimgo_mobile/core/widgets/api_error_message.dart';
import 'package:indirimgo_mobile/features/catalog/domain/catalog_models.dart';
import 'package:indirimgo_mobile/features/catalog/presentation/catalog_controllers.dart';
import 'package:indirimgo_mobile/features/catalog/presentation/widgets/catalog_widgets.dart';

class PackageDetailScreen extends ConsumerWidget {
  const PackageDetailScreen({super.key, required this.packageId});

  final int packageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(packageDetailControllerProvider(packageId));
    final controller = ref.read(
      packageDetailControllerProvider(packageId).notifier,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.packageDetailTitle),
        backgroundColor: BrandColors.yellow,
        foregroundColor: BrandColors.ink,
      ),
      body: SafeArea(child: _buildBody(context, l10n, state, controller)),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    PackageDetailState state,
    PackageDetailController controller,
  ) {
    switch (state.phase) {
      case PackageDetailPhase.idle:
      case PackageDetailPhase.loading:
        return Semantics(
          label: l10n.catalogLoading,
          child: const Center(
            child: CircularProgressIndicator(key: Key('package-detail-loading')),
          ),
        );
      case PackageDetailPhase.notFound:
        return CatalogStatusView(
          key: const Key('package-not-found'),
          title: l10n.packageNotFoundTitle,
          body: l10n.packageNotFound,
          icon: Icons.search_off_outlined,
          actionLabel: l10n.backToPackages,
          onRetry: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.packages);
            }
          },
        );
      case PackageDetailPhase.error:
        return CatalogStatusView(
          key: const Key('package-detail-error'),
          title: l10n.catalogUnavailableTitle,
          body: localizedApiError(l10n, state.error),
          onRetry: controller.retry,
        );
      case PackageDetailPhase.ready:
        final result = state.result;
        if (result == null) {
          return CatalogStatusView(
            title: l10n.catalogUnavailableTitle,
            body: l10n.catalogUnavailableBody,
            onRetry: controller.retry,
          );
        }
        return _PackageDetailBody(result: result);
    }
  }
}

class _PackageDetailBody extends StatelessWidget {
  const _PackageDetailBody({required this.result});

  final PackageDetailResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final package = result.package;
    final theme = Theme.of(context);

    return ListView(
      key: const Key('package-detail'),
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        PackageImage(
          imageUrl: package.imageUrl,
          height: 180,
          width: double.infinity,
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          package.name,
          style: theme.textTheme.headlineMedium,
        ),
        if (package.category != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            package.category!.name,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        CatalogPriceText(
          pricesVisible: result.pricesVisible,
          money: package.fromPrice,
          prefix: result.pricesVisible && package.fromPrice != null
              ? '${l10n.fromPriceLabel} '
              : null,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.tertiary,
          ),
        ),
        if (package.description != null && package.description!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(package.description!, style: theme.textTheme.bodyLarge),
        ],
        CatalogSectionHeader(l10n.productOptionsTitle),
        if (package.products.isEmpty)
          Text(l10n.productOptionsEmpty)
        else
          ...package.products.map(
            (product) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ProductOptionCard(
                product: product,
                pricesVisible: result.pricesVisible,
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _ProductOptionCard extends StatelessWidget {
  const _ProductOptionCard({
    required this.product,
    required this.pricesVisible,
  });

  final ProductOption product;
  final bool pricesVisible;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      key: Key('product-option-${product.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              product.isFixed ? l10n.fixedAmountMode : l10n.customAmountMode,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.tertiary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (product.isFixed)
              CatalogPriceText(
                pricesVisible: pricesVisible,
                money: product.unitPrice,
              )
            else ...[
              if (product.customAmount != null &&
                  product.customAmount!.hasAnyBound)
                _CustomAmountMeta(config: product.customAmount!)
              else
                Text(
                  l10n.customAmountConfigUnavailable,
                  style: theme.textTheme.bodyMedium,
                ),
              const SizedBox(height: AppSpacing.sm),
              CatalogPriceText(
                pricesVisible: pricesVisible,
                money: product.minimumPrice,
                prefix: pricesVisible && product.minimumPrice != null
                    ? '${l10n.minimumPriceLabel} '
                    : null,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.customPriceCalculatedLater,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CustomAmountMeta extends StatelessWidget {
  const _CustomAmountMeta({required this.config});

  final CustomAmountConfig config;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final parts = <String>[
      if (config.min != null) l10n.customAmountMin(config.min!),
      if (config.max != null) l10n.customAmountMax(config.max!),
      if (config.step != null) l10n.customAmountStep(config.step!),
      if (config.unitLabel != null && config.unitLabel!.isNotEmpty)
        l10n.customAmountUnit(config.unitLabel!),
    ];
    if (parts.isEmpty) {
      return Text(l10n.customAmountConfigUnavailable);
    }
    return Text(parts.join(' · '));
  }
}
