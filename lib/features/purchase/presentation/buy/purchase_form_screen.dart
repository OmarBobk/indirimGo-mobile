import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:indirimgo_mobile/core/localization/generated/app_localizations.dart';
import 'package:indirimgo_mobile/core/routing/app_router.dart';
import 'package:indirimgo_mobile/core/theme/app_theme.dart';
import 'package:indirimgo_mobile/core/widgets/api_error_message.dart';
import 'package:indirimgo_mobile/features/catalog/domain/catalog_models.dart';
import 'package:indirimgo_mobile/features/catalog/presentation/catalog_controllers.dart';
import 'package:indirimgo_mobile/features/catalog/presentation/widgets/catalog_widgets.dart';
import 'package:indirimgo_mobile/features/purchase/presentation/purchase_controllers.dart';
import 'package:indirimgo_mobile/features/purchase/presentation/widgets/purchase_widgets.dart';

class PurchaseFormScreen extends ConsumerStatefulWidget {
  const PurchaseFormScreen({
    super.key,
    required this.packageId,
    required this.productId,
  });

  final int packageId;
  final int productId;

  @override
  ConsumerState<PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class _PurchaseFormScreenState extends ConsumerState<PurchaseFormScreen> {
  final _quantityController = TextEditingController();
  final _amountController = TextEditingController();
  final _requirementControllers = <String, TextEditingController>{};
  var _seeded = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _amountController.dispose();
    for (final controller in _requirementControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _seedFromDraft() {
    final draft = ref.read(purchaseDraftControllerProvider).draft;
    if (draft == null || _seeded) {
      return;
    }
    _seeded = true;
    if (draft.quantity != null) {
      _quantityController.text = '${draft.quantity}';
    }
    if (draft.requestedAmount != null) {
      _amountController.text = '${draft.requestedAmount}';
    }
    for (final field in draft.requirementsSchema) {
      _requirementControllers.putIfAbsent(
        field.key,
        () => TextEditingController(
          text: draft.requirementValues[field.key] ?? '',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final detail = ref.watch(packageDetailControllerProvider(widget.packageId));
    final formState = ref.watch(purchaseFormControllerProvider);
    final draftState = ref.watch(purchaseDraftControllerProvider);

    ref.listen(purchaseFormControllerProvider, (previous, next) {
      if (next.navigatedToReview) {
        ref.read(purchaseFormControllerProvider.notifier).resetNavigationFlag();
        context.push(AppRoutes.checkoutReview);
      }
    });

    if (detail.phase == PackageDetailPhase.ready && detail.result != null) {
      final result = detail.result!;
      ProductOption? product;
      for (final item in result.package.products) {
        if (item.id == widget.productId) {
          product = item;
          break;
        }
      }
      if (product != null && draftState.draft?.product.id != product.id) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          ref
              .read(purchaseDraftControllerProvider.notifier)
              .start(
                packageId: result.package.id,
                packageName: result.package.name,
                product: product!,
                requirements: result.package.requirements,
                requirementsSupported: result.package.requirementsSupported,
                pricesVisible: result.pricesVisible,
              );
          _seedFromDraft();
        });
      } else {
        _seedFromDraft();
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.buyNowTitle),
        backgroundColor: BrandColors.yellow,
        foregroundColor: BrandColors.ink,
      ),
      body: SafeArea(child: _buildBody(context, l10n, detail, formState)),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    PackageDetailState detail,
    PurchaseFormState formState,
  ) {
    if (detail.phase == PackageDetailPhase.idle ||
        detail.phase == PackageDetailPhase.loading) {
      return Semantics(
        label: l10n.catalogLoading,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (detail.phase == PackageDetailPhase.notFound || detail.result == null) {
      return PurchaseStatusView(
        key: const Key('purchase-package-missing'),
        title: l10n.packageNotFoundTitle,
        body: l10n.packageNotFound,
        actionLabel: l10n.backToPackages,
        onAction: () => context.go(AppRoutes.packages),
      );
    }

    final result = detail.result!;
    ProductOption? product;
    for (final item in result.package.products) {
      if (item.id == widget.productId) {
        product = item;
        break;
      }
    }
    if (product == null) {
      return PurchaseStatusView(
        key: const Key('purchase-product-missing'),
        title: l10n.purchaseUnavailableTitle,
        body: l10n.purchaseUnavailableBody,
        actionLabel: l10n.backToPackages,
        onAction: () => context.go(AppRoutes.packageDetail(widget.packageId)),
      );
    }

    final draft = ref.watch(purchaseDraftControllerProvider).draft;
    if (draft == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!result.pricesVisible ||
        !result.package.requirementsSupported ||
        formState.phase == PurchaseFormPhase.unavailable) {
      return PurchaseStatusView(
        key: const Key('purchase-unavailable'),
        title: l10n.purchaseUnavailableTitle,
        body: l10n.purchaseUnavailableBody,
        actionLabel: l10n.backToPackages,
        onAction: () => context.go(AppRoutes.packageDetail(widget.packageId)),
      );
    }

    final quoting = formState.phase == PurchaseFormPhase.quoting;
    final errors = formState.localFieldErrors;

    return ListView(
      key: const Key('purchase-form'),
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(draft.packageName, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(product.name, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.sm),
        if (product.isFixed)
          CatalogPriceText(
            pricesVisible: true,
            money: product.unitPrice,
            prefix: '${l10n.unitPriceLabel} ',
          )
        else
          CatalogPriceText(
            pricesVisible: true,
            money: product.minimumPrice,
            prefix: product.minimumPrice == null
                ? null
                : '${l10n.minimumPriceLabel} ',
          ),
        PurchaseSectionLabel(l10n.purchaseDetailsTitle),
        if (product.isFixed) ...[
          TextFormField(
            key: const Key('quantity-field'),
            controller: _quantityController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l10n.quantityLabel,
              errorText: errors['quantity'] == null
                  ? null
                  : l10n.quantityInvalid,
            ),
            onChanged: (value) {
              final parsed = int.tryParse(value);
              ref
                  .read(purchaseDraftControllerProvider.notifier)
                  .updateQuantity(parsed);
            },
          ),
        ] else ...[
          TextFormField(
            key: const Key('requested-amount-field'),
            controller: _amountController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l10n.requestedAmountLabel(
                product.customAmount?.unitLabel ?? '',
              ),
              errorText: errors['requested_amount'] == null
                  ? null
                  : l10n.requestedAmountInvalid,
            ),
            onChanged: (value) {
              final parsed = int.tryParse(value);
              ref
                  .read(purchaseDraftControllerProvider.notifier)
                  .updateRequestedAmount(parsed);
            },
          ),
        ],
        if (draft.requirementsSchema.isNotEmpty) ...[
          PurchaseSectionLabel(l10n.requirementsTitle),
          ...draft.requirementsSchema.map((field) {
            final controller = _requirementControllers.putIfAbsent(
              field.key,
              () => TextEditingController(
                text: draft.requirementValues[field.key] ?? '',
              ),
            );
            final errorCode = errors['requirement:${field.key}'];
            if (field.inputType == RequirementInputType.select) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: DropdownButtonFormField<String>(
                  key: Key('requirement-${field.key}'),
                  initialValue: controller.text.isEmpty
                      ? null
                      : controller.text,
                  decoration: InputDecoration(
                    labelText: field.label,
                    errorText: errorCode == null
                        ? null
                        : localizedRequirementError(l10n, errorCode),
                  ),
                  items: [
                    for (final option in field.options ?? const <String>[])
                      DropdownMenuItem(value: option, child: Text(option)),
                  ],
                  onChanged: quoting
                      ? null
                      : (value) {
                          controller.text = value ?? '';
                          ref
                              .read(purchaseDraftControllerProvider.notifier)
                              .updateRequirementValue(field.key, value ?? '');
                        },
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: TextFormField(
                key: Key('requirement-${field.key}'),
                controller: controller,
                enabled: !quoting,
                keyboardType: field.inputType == RequirementInputType.number
                    ? TextInputType.number
                    : TextInputType.text,
                maxLength: field.maxLength,
                decoration: InputDecoration(
                  labelText: field.label,
                  errorText: errorCode == null
                      ? null
                      : localizedRequirementError(l10n, errorCode),
                ),
                onChanged: (value) {
                  ref
                      .read(purchaseDraftControllerProvider.notifier)
                      .updateRequirementValue(field.key, value);
                },
              ),
            );
          }),
        ],
        if (formState.error != null &&
            formState.phase == PurchaseFormPhase.error) ...[
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            liveRegion: true,
            child: Text(
              localizedApiError(l10n, formState.error),
              key: const Key('purchase-form-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            key: const Key('continue-to-quote'),
            onPressed: quoting
                ? null
                : () => ref
                      .read(purchaseFormControllerProvider.notifier)
                      .requestQuote(),
            child: quoting
                ? Semantics(
                    liveRegion: true,
                    label: l10n.quotingPurchase,
                    child: const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Text(l10n.continueToReviewAction),
          ),
        ),
      ],
    );
  }
}
