import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:indirimgo_mobile/core/localization/generated/app_localizations.dart';
import 'package:indirimgo_mobile/core/routing/app_router.dart';
import 'package:indirimgo_mobile/core/theme/app_theme.dart';
import 'package:indirimgo_mobile/core/widgets/api_error_message.dart';
import 'package:indirimgo_mobile/features/wallet/presentation/topup_form_controller.dart';
import 'package:indirimgo_mobile/features/wallet/presentation/wallet_widgets.dart';

class TopupFormScreen extends ConsumerStatefulWidget {
  const TopupFormScreen({super.key});

  @override
  ConsumerState<TopupFormScreen> createState() => _TopupFormScreenState();
}

class _TopupFormScreenState extends ConsumerState<TopupFormScreen> {
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: ref.read(topupFormControllerProvider).amount,
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(topupFormControllerProvider);
    final controller = ref.read(topupFormControllerProvider.notifier);

    ref.listen<TopupFormState>(topupFormControllerProvider, (previous, next) {
      if (next.amount != _amountController.text) {
        _amountController.text = next.amount;
      }
      final submitted = next.submitted;
      if (next.phase == TopupFormPhase.submitted &&
          submitted != null &&
          previous?.submitted?.publicRef != submitted.publicRef) {
        context.go(AppRoutes.walletTopupDetail(submitted.publicRef));
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? null
          : BrandColors.paper,
      appBar: AppBar(
        title: Text(l10n.topupFormTitle),
        centerTitle: false,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: context.pop,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: ListView(
          key: const Key('topup-form-screen'),
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xl + 24,
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFFB45309),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.topupVerificationNotice,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF92400E),
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (state.phase == TopupFormPhase.loadingMethods ||
                state.phase == TopupFormPhase.recovering)
              Semantics(
                liveRegion: true,
                label: state.phase == TopupFormPhase.recovering
                    ? l10n.recoveringTopup
                    : l10n.walletLoading,
                child: const LinearProgressIndicator(
                  key: Key('topup-form-loading'),
                ),
              ),
            if (state.error != null && state.phase != TopupFormPhase.error) ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  localizedApiError(l10n, state.error),
                  key: const Key('topup-form-error'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.topupAmountLabel,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        SegmentedButton<String>(
                          showSelectedIcon: false,
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                          ),
                          segments: [
                            ButtonSegment(
                              value: 'USD',
                              label: Text(l10n.topupCurrencyUsd),
                            ),
                            ButtonSegment(
                              value: 'TRY',
                              label: Text(
                                l10n.topupCurrencyTry,
                                key: const Key('topup-currency-try'),
                              ),
                            ),
                          ],
                          selected: {state.currency},
                          onSelectionChanged: state.isBusy
                              ? null
                              : (values) =>
                                    controller.setCurrency(values.first),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      key: const Key('topup-amount-field'),
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      textDirection: TextDirection.ltr,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                      ),
                      decoration: InputDecoration(
                        prefixText: state.currency == 'TRY' ? '₺ ' : r'$ ',
                        hintText: l10n.topupAmountHint,
                        errorText: state.amountError
                            ? l10n.topupAmountRequired
                            : null,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                      ),
                      enabled: !state.isBusy,
                      onChanged: controller.setAmount,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.topupCurrencyHelp,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: BrandColors.mutedSlate,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ..._paymentMethodBlock(context, l10n, state, controller),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.attachProofLabel,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.sm),
            FileUploadDropzone(
              proof: state.proof,
              enabled: !state.isBusy,
              title: l10n.proofDropzoneTitle,
              body: l10n.proofDropzoneBody,
              takePhotoLabel: l10n.takePhotoAction,
              chooseLibraryLabel: l10n.chooseFromLibraryAction,
              removeTooltip: l10n.removeProofAction,
              onTakePhoto: controller.pickProofFromCamera,
              onChooseLibrary: controller.pickProof,
              onRemove: () => controller.setProof(null),
            ),
          ],
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120F172A),
              blurRadius: 18,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          minimum: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: FilledButton(
            key: const Key('topup-submit'),
            onPressed: state.canSubmit ? controller.submit : null,
            child: state.isBusy
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: BrandColors.ink,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(l10n.submittingTopup),
                    ],
                  )
                : Text(l10n.submitTopupAction),
          ),
        ),
      ),
    );
  }

  List<Widget> _paymentMethodBlock(
    BuildContext context,
    AppLocalizations l10n,
    TopupFormState state,
    TopupFormController controller,
  ) {
    if (state.phase == TopupFormPhase.loadingMethods &&
        state.paymentMethods.isEmpty) {
      return const [];
    }
    if (state.phase == TopupFormPhase.error && state.paymentMethods.isEmpty) {
      return [
        Text(
          l10n.paymentMethodsUnavailableTitle,
          key: const Key('topup-methods-error'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(localizedApiError(l10n, state.error)),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: const Key('topup-retry-methods'),
            onPressed: controller.retryMethods,
            child: Text(l10n.retryAction),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ];
    }
    if (state.phase == TopupFormPhase.noMethods ||
        (state.phase == TopupFormPhase.ready && state.paymentMethods.isEmpty)) {
      return [
        Text(
          l10n.paymentMethodsEmptyTitle,
          key: const Key('topup-methods-empty'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.paymentMethodsEmptyBody),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: const Key('topup-retry-methods'),
            onPressed: controller.retryMethods,
            child: Text(l10n.retryAction),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ];
    }
    if (state.paymentMethods.isEmpty) {
      return const [];
    }
    return [
      Text(
        l10n.paymentMethodLabel,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: AppSpacing.sm),
      for (final method in state.paymentMethods)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: BankOptionCard(
            key: Key('topup-method-${method.id}'),
            method: method,
            selected: state.selectedPaymentMethodId == method.id,
            enabled: !state.isBusy,
            onTap: () => controller.selectPaymentMethod(method.id),
            accountLabel: l10n.transferAccountLabel,
            instructionsLabel: l10n.paymentInstructionsTitle,
            copyTooltip: l10n.copyAction,
            copiedMessage: l10n.copiedToClipboard,
          ),
        ),
      if (state.methodError)
        Text(
          l10n.paymentMethodRequired,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      if (state.phase == TopupFormPhase.error) ...[
        const SizedBox(height: AppSpacing.sm),
        Text(localizedApiError(l10n, state.error)),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: const Key('topup-retry-methods'),
            onPressed: controller.retryMethods,
            child: Text(l10n.retryAction),
          ),
        ),
      ],
    ];
  }
}
