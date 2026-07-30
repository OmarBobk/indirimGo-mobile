import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:indirimgo_mobile/core/localization/generated/app_localizations.dart';
import 'package:indirimgo_mobile/core/routing/app_router.dart';
import 'package:indirimgo_mobile/core/theme/app_theme.dart';
import 'package:indirimgo_mobile/core/widgets/api_error_message.dart';
import 'package:indirimgo_mobile/features/catalog/presentation/catalog_controllers.dart';
import 'package:indirimgo_mobile/features/catalog/presentation/widgets/catalog_widgets.dart';

class PackageListScreen extends ConsumerStatefulWidget {
  const PackageListScreen({
    super.key,
    this.categoryId,
    this.categoryName,
    this.initialQuery,
  });

  final int? categoryId;
  final String? categoryName;
  final String? initialQuery;

  @override
  ConsumerState<PackageListScreen> createState() => _PackageListScreenState();
}

class _PackageListScreenState extends ConsumerState<PackageListScreen> {
  late final TextEditingController _searchController;
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(packageListControllerProvider.notifier)
          .bootstrap(
            categoryId: widget.categoryId,
            categoryName: widget.categoryName,
            q: widget.initialQuery,
          );
    });
  }

  @override
  void didUpdateWidget(covariant PackageListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryId != widget.categoryId ||
        oldWidget.categoryName != widget.categoryName ||
        oldWidget.initialQuery != widget.initialQuery) {
      ref
          .read(packageListControllerProvider.notifier)
          .bootstrap(
            categoryId: widget.categoryId,
            categoryName: widget.categoryName,
            q: widget.initialQuery,
          );
      if (widget.initialQuery != null &&
          widget.initialQuery != _searchController.text) {
        _searchController.text = widget.initialQuery!;
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(packageListControllerProvider);
    final controller = ref.read(packageListControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.packagesTitle),
        backgroundColor: BrandColors.yellow,
        foregroundColor: BrandColors.ink,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: TextField(
                key: const Key('package-search-field'),
                controller: _searchController,
                focusNode: _searchFocus,
                textInputAction: TextInputAction.search,
                maxLength: catalogSearchQueryMaxLength,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                buildCounter:
                    (
                      context, {
                      required currentLength,
                      required isFocused,
                      required maxLength,
                    }) => null,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(catalogSearchQueryMaxLength),
                ],
                decoration: InputDecoration(
                  labelText: l10n.searchPackagesLabel,
                  hintText: l10n.searchPackagesHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: state.searchInput.isEmpty
                      ? null
                      : IconButton(
                          key: const Key('clear-search'),
                          tooltip: l10n.clearSearch,
                          onPressed: () {
                            _searchController.clear();
                            controller.submitSearch('');
                          },
                          icon: const Icon(Icons.clear),
                        ),
                ),
                onChanged: controller.onSearchChanged,
                onSubmitted: controller.submitSearch,
              ),
            ),
            if (state.query.categoryId != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: InputChip(
                    key: const Key('active-category-chip'),
                    label: Text(
                      state.categoryName?.trim().isNotEmpty == true
                          ? state.categoryName!.trim()
                          : l10n.categoryFilterActive,
                    ),
                    onDeleted: controller.clearCategory,
                    deleteButtonTooltipMessage: l10n.clearCategoryFilter,
                  ),
                ),
              ),
            Expanded(child: _buildBody(context, state, controller, l10n)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    PackageListState state,
    PackageListController controller,
    AppLocalizations l10n,
  ) {
    if (state.phase == PackageListPhase.loading && !state.hasContent) {
      return Semantics(
        label: l10n.catalogLoading,
        child: const Center(
          child: CircularProgressIndicator(key: Key('package-list-loading')),
        ),
      );
    }

    if (state.phase == PackageListPhase.error && !state.hasContent) {
      return CatalogStatusView(
        key: const Key('package-list-error'),
        title: l10n.catalogUnavailableTitle,
        body: localizedApiError(l10n, state.error),
        onRetry: controller.retry,
      );
    }

    if (state.phase == PackageListPhase.empty ||
        (state.phase == PackageListPhase.ready && !state.hasContent)) {
      return CatalogStatusView(
        key: const Key('package-list-empty'),
        title: l10n.packagesEmptyTitle,
        body: l10n.packagesEmptyBody,
        icon: Icons.inventory_2_outlined,
        onRetry: null,
      );
    }

    return RefreshIndicator(
      key: const Key('package-list-refresh'),
      onRefresh: controller.refresh,
      child: ListView.builder(
        key: const Key('package-list'),
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount:
            state.packages.length +
            (state.canLoadMore || state.loadMoreError != null ? 1 : 0) +
            (state.phase == PackageListPhase.error && state.hasContent ? 1 : 0),
        itemBuilder: (context, index) {
          if (state.phase == PackageListPhase.error &&
              state.hasContent &&
              index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                localizedApiError(l10n, state.error),
                key: const Key('package-list-refresh-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            );
          }
          final offset =
              state.phase == PackageListPhase.error && state.hasContent ? 1 : 0;
          final packageIndex = index - offset;
          if (packageIndex < state.packages.length) {
            final package = state.packages[packageIndex];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: PackageCard(
                package: package,
                pricesVisible: state.pricesVisible,
                onTap: () => context.push(AppRoutes.packageDetail(package.id)),
              ),
            );
          }

          if (state.loadMoreError != null) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Column(
                children: [
                  Text(
                    localizedApiError(l10n, state.loadMoreError),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton(
                    key: const Key('load-more-retry'),
                    onPressed: controller.retryLoadMore,
                    child: Text(l10n.retryAction),
                  ),
                ],
              ),
            );
          }

          final loadingMore = state.phase == PackageListPhase.loadingMore;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(
              child: loadingMore
                  ? Semantics(
                      label: l10n.catalogLoading,
                      child: const CircularProgressIndicator(
                        key: Key('load-more-loading'),
                      ),
                    )
                  : Semantics(
                      button: true,
                      label: l10n.loadMorePackages,
                      child: OutlinedButton(
                        key: const Key('load-more-button'),
                        onPressed: controller.loadMore,
                        child: Text(l10n.loadMorePackages),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}
