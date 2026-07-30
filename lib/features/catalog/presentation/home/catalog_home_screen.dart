import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:indirimgo_mobile/core/localization/generated/app_localizations.dart';
import 'package:indirimgo_mobile/core/routing/app_router.dart';
import 'package:indirimgo_mobile/core/theme/app_theme.dart';
import 'package:indirimgo_mobile/core/widgets/api_error_message.dart';
import 'package:indirimgo_mobile/features/auth/presentation/auth_controller.dart';
import 'package:indirimgo_mobile/features/catalog/presentation/catalog_controllers.dart';
import 'package:indirimgo_mobile/features/catalog/presentation/widgets/catalog_widgets.dart';

class CatalogHomeScreen extends ConsumerWidget {
  const CatalogHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authControllerProvider);
    final homeState = ref.watch(catalogHomeControllerProvider);
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.brandLatin,
          textDirection: TextDirection.ltr,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: BrandColors.yellow,
        foregroundColor: BrandColors.ink,
        actions: [
          Semantics(
            button: true,
            label: l10n.accountTitle,
            child: IconButton(
              key: const Key('account-button'),
              tooltip: l10n.accountTitle,
              onPressed: () => context.push(AppRoutes.account),
              icon: const Icon(Icons.account_circle_outlined),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: user == null
            ? const Center(child: CircularProgressIndicator())
            : _HomeBody(userName: user.name, state: homeState),
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.userName, required this.state});

  final String userName;
  final CatalogHomeState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(catalogHomeControllerProvider.notifier);

    if (state.phase == CatalogLoadPhase.loading && !state.hasContent) {
      return Semantics(
        label: l10n.catalogLoading,
        child: const Center(
          child: CircularProgressIndicator(key: Key('catalog-home-loading')),
        ),
      );
    }

    if (state.phase == CatalogLoadPhase.error && !state.hasContent) {
      return CatalogStatusView(
        key: const Key('catalog-home-error'),
        title: l10n.catalogUnavailableTitle,
        body: localizedApiError(l10n, state.error),
        onRetry: controller.retry,
        icon: Icons.refresh,
      );
    }

    final home = state.home;
    if (home == null) {
      return CatalogStatusView(
        title: l10n.catalogUnavailableTitle,
        body: l10n.catalogUnavailableBody,
        onRetry: controller.retry,
      );
    }

    return RefreshIndicator(
      key: const Key('catalog-home-refresh'),
      onRefresh: controller.refresh,
      child: ListView(
        key: const Key('authenticated-shell'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            l10n.welcomeUser(userName),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.homeBrowseSubtitle,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            button: true,
            label: l10n.searchPackagesHint,
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadii.input),
              child: InkWell(
                key: const Key('home-search-entry'),
                borderRadius: BorderRadius.circular(AppRadii.input),
                onTap: () => context.push(AppRoutes.packages),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm + 4,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          l10n.searchPackagesHint,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            button: true,
            label: l10n.browseAllPackages,
            child: FilledButton.icon(
              key: const Key('browse-all-packages'),
              onPressed: () => context.push(AppRoutes.packages),
              icon: const Icon(Icons.grid_view_rounded),
              label: Text(l10n.browseAllPackages),
            ),
          ),
          if (home.frequentlyOrdered.isNotEmpty) ...[
            CatalogSectionHeader(l10n.frequentlyOrderedTitle),
            ...home.frequentlyOrdered.map(
              (package) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: PackageCard(
                  package: package,
                  pricesVisible: home.pricesVisible,
                  timesOrdered: package.timesOrdered,
                  onTap: () =>
                      context.push(AppRoutes.packageDetail(package.id)),
                ),
              ),
            ),
          ],
          CatalogSectionHeader(l10n.featuredPackagesTitle),
          if (home.featuredPackages.isEmpty)
            Text(l10n.featuredPackagesEmpty)
          else ...[
            for (final package in home.featuredPackages)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: PackageCard(
                  package: package,
                  pricesVisible: home.pricesVisible,
                  onTap: () =>
                      context.push(AppRoutes.packageDetail(package.id)),
                ),
              ),
          ],
          if (home.categories.isNotEmpty) ...[
            CatalogSectionHeader(l10n.categoriesTitle),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final category in home.categories)
                  Semantics(
                    button: true,
                    label: category.name,
                    child: ActionChip(
                      key: Key('category-chip-${category.id}'),
                      label: Text(category.name),
                      onPressed: () => context.push(
                        AppRoutes.packagesWithCategory(
                          category.id,
                          name: category.name,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (state.phase == CatalogLoadPhase.error && state.hasContent) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              localizedApiError(l10n, state.error),
              key: const Key('catalog-home-refresh-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
