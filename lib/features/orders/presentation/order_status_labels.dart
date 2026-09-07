import 'package:indirimgo_mobile/core/localization/generated/app_localizations.dart';

String localizedPaymentStatus(AppLocalizations l10n, String status) {
  return switch (status) {
    'paid' => l10n.paymentStatusPaid,
    'pending_payment' => l10n.paymentStatusPending,
    'processing' => l10n.paymentStatusProcessing,
    'fulfilled' => l10n.paymentStatusFulfilled,
    'failed' => l10n.paymentStatusFailed,
    'refunded' => l10n.paymentStatusRefunded,
    'cancelled' => l10n.paymentStatusCancelled,
    _ => l10n.statusOther,
  };
}

String localizedFulfillmentStatus(AppLocalizations l10n, String status) {
  return switch (status) {
    'pending' => l10n.fulfillmentStatusPending,
    'queued' => l10n.fulfillmentStatusQueued,
    'processing' => l10n.fulfillmentStatusProcessing,
    'completed' => l10n.fulfillmentStatusCompleted,
    'failed' => l10n.fulfillmentStatusFailed,
    'cancelled' => l10n.fulfillmentStatusCancelled,
    _ => l10n.statusOther,
  };
}

String localizedCustomerOrderState(AppLocalizations l10n, String state) {
  return switch (state) {
    'needs_attention' => l10n.customerStateNeedsAttention,
    'in_progress' => l10n.customerStateInProgress,
    'delivered' => l10n.customerStateDelivered,
    'refunded' => l10n.customerStateRefunded,
    'other' => l10n.statusOther,
    _ => l10n.statusOther,
  };
}
