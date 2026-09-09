import 'package:indirimgo_mobile/core/localization/generated/app_localizations.dart';
import 'package:indirimgo_mobile/features/wallet/domain/wallet_models.dart';

String localizedTopupStatus(AppLocalizations l10n, TopupListItem item) {
  return localizedTopupStatusValue(
    l10n,
    item.status,
    credited: item.credited,
    pending: item.pendingUntilAdminApproval,
  );
}

String localizedTopupStatusValue(
  AppLocalizations l10n,
  String status, {
  required bool credited,
  required bool pending,
}) {
  if (credited) {
    return l10n.topupStatusCredited;
  }
  if (pending) {
    return l10n.topupStatusPending;
  }
  return switch (status) {
    'pending' => l10n.topupStatusPending,
    'approved' => l10n.topupStatusApproved,
    'rejected' => l10n.topupStatusRejected,
    'cancelled' => l10n.topupStatusCancelled,
    _ => l10n.topupStatusPending,
  };
}

String localizedTransactionType(AppLocalizations l10n, String type) {
  return switch (type) {
    'purchase' => l10n.transactionTypePurchase,
    'topup' => l10n.transactionTypeTopup,
    'refund' => l10n.transactionTypeRefund,
    'adjustment' => l10n.transactionTypeAdjustment,
    'commission_credit' ||
    'commission_reversal' ||
    'commission_clawback_waiver' ||
    'commission_reversal_correction' => l10n.transactionTypeCommission,
    _ => l10n.transactionTypeAdjustment,
  };
}

String localizedTransactionDirection(AppLocalizations l10n, String direction) {
  return direction == 'debit'
      ? l10n.transactionDirectionDebit
      : l10n.transactionDirectionCredit;
}
