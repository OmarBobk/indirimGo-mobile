import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:indirimgo_mobile/core/localization/generated/app_localizations.dart';
import 'package:indirimgo_mobile/core/routing/app_router.dart';
import 'package:indirimgo_mobile/core/theme/app_theme.dart';
import 'package:indirimgo_mobile/core/widgets/api_error_message.dart';
import 'package:indirimgo_mobile/features/wallet/presentation/topup_form_controller.dart';

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
      appBar: AppBar(
        title: Text(l10n.topupFormTitle),
        backgroundColor: BrandColors.yellow,
        foregroundColor: BrandColors.ink,
      ),
      body: SafeArea(
        child: ListView(
          key: const Key('topup-form-screen'),
          padding: const EdgeInsetsDirectional.all(AppSpacing.md),
          children: [
            Text(l10n.topupPendingNotice),
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
            if (state.error != null) ...[
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
            TextField(
              key: const Key('topup-amount-field'),
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                labelText: l10n.topupAmountLabel,
                hintText: l10n.topupAmountHint,
                errorText: state.amountError ? l10n.topupAmountRequired : null,
              ),
              enabled: !state.isBusy,
              onChanged: controller.setAmount,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.topupCurrencyLabel),
            const SizedBox(height: AppSpacing.xs),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'USD', label: Text(l10n.topupCurrencyUsd)),
                ButtonSegment(value: 'TRY', label: Text(l10n.topupCurrencyTry)),
              ],
              selected: {state.currency},
              onSelectionChanged: state.isBusy
                  ? null
                  : (values) => controller.setCurrency(values.first),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.topupCurrencyHelp),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.paymentMethodLabel),
            const SizedBox(height: AppSpacing.sm),
            for (final method in state.paymentMethods)
              RadioListTile<int>(
                key: Key('topup-method-${method.id}'),
                value: method.id,
                groupValue: state.selectedPaymentMethodId,
                onChanged: state.isBusy
                    ? null
                    : (value) {
                        if (value != null) {
                          controller.selectPaymentMethod(value);
                        }
                      },
                title: Text(method.name),
                subtitle: method.instructions == null
                    ? null
                    : Text(method.instructions!),
              ),
            if (state.methodError)
              Text(
                l10n.paymentMethodRequired,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.attachProofLabel),
            const SizedBox(height: AppSpacing.sm),
            if (state.proof != null)
              Text(l10n.proofSelectedLabel(state.proof!.filename)),
            Row(
              children: [
                OutlinedButton(
                  key: const Key('topup-choose-proof'),
                  onPressed: state.isBusy ? null : controller.pickProof,
                  child: Text(l10n.chooseProofAction),
                ),
                if (state.proof != null)
                  TextButton(
                    key: const Key('topup-remove-proof'),
                    onPressed: state.isBusy
                        ? null
                        : () => controller.setProof(null),
                    child: Text(l10n.removeProofAction),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              key: const Key('topup-submit'),
              onPressed: state.isBusy ? null : controller.submit,
              child: Text(
                state.isBusy ? l10n.submittingTopup : l10n.submitTopupAction,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
