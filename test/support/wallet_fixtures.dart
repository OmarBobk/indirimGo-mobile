import 'package:indirimgo_mobile/features/catalog/domain/catalog_models.dart';
import 'package:indirimgo_mobile/features/wallet/domain/wallet_models.dart';

import 'purchase_fixtures.dart';

export 'purchase_fixtures.dart';

Map<String, Object?> paginationJson({
  int page = 1,
  int perPage = walletPageSize,
  int total = 0,
  int lastPage = 1,
}) {
  return {
    'page': page,
    'per_page': perPage,
    'total': total,
    'last_page': lastPage,
  };
}

Map<String, Object?> paymentMethodJson({
  int id = 11,
  String name = 'Bank transfer',
  String? instructions = 'Send to IBAN TR00 EXAMPLE 0000.',
  String? imageUrl,
}) {
  return {
    'id': id,
    'name': name,
    'instructions': instructions,
    'image_url': imageUrl,
  };
}

Map<String, Object?> walletTransactionItemJson({
  String publicRef = 'WTX-1',
  String type = 'topup',
  String direction = 'credit',
  String amount = '25.00',
  String occurredAt = '2026-09-01T12:00:00.000Z',
  String? relatedOrderNumber,
  String? relatedTopupPublicRef = 'TUP-ABC123',
  String? description = 'Approved top-up',
}) {
  return {
    'public_ref': publicRef,
    'type': type,
    'direction': direction,
    'amount': moneyJson(amount: amount, formatted: '\$$amount'),
    'occurred_at': occurredAt,
    'related_order_number': relatedOrderNumber,
    'related_topup_public_ref': relatedTopupPublicRef,
    'customer_safe_description': description,
  };
}

Map<String, Object?> walletTransactionPageJson({
  int page = 1,
  int lastPage = 1,
  List<Map<String, Object?>>? items,
}) {
  final data = items ?? [walletTransactionItemJson()];
  return {
    'data': data,
    'meta': {
      'pagination': paginationJson(
        page: page,
        total: data.length,
        lastPage: lastPage,
      ),
    },
  };
}

Map<String, Object?> enteredDisplayJson({
  String currency = 'USD',
  String formatted = r'$25.00',
}) {
  return {'currency': currency, 'formatted': formatted};
}

Map<String, Object?> topupListItemJson({
  String publicRef = 'TUP-ABC123',
  String status = 'pending',
  bool pendingUntilAdminApproval = true,
  bool credited = false,
  bool moneyMoved = false,
  bool canRetry = false,
  String walletAmount = '25.00',
  String? paymentMethodName = 'Bank transfer',
  bool hasProof = false,
  String submittedAt = '2026-09-01T12:00:00.000Z',
}) {
  return {
    'public_ref': publicRef,
    'status': status,
    'pending_until_admin_approval': pendingUntilAdminApproval,
    'credited': credited,
    'money_moved': moneyMoved,
    'can_retry': canRetry,
    'wallet_amount': moneyJson(
      amount: walletAmount,
      formatted: '\$$walletAmount',
    ),
    'payment_method_name': paymentMethodName,
    'has_proof': hasProof,
    'submitted_at': submittedAt,
  };
}

Map<String, Object?> topupListPageJson({
  int page = 1,
  int lastPage = 1,
  String? pendingTopupPublicRef,
  List<Map<String, Object?>>? items,
}) {
  final data = items ?? [topupListItemJson()];
  return {
    'data': data,
    'meta': {
      'pagination': paginationJson(
        page: page,
        total: data.length,
        lastPage: lastPage,
      ),
      'pending_topup_public_ref': pendingTopupPublicRef,
    },
  };
}

Map<String, Object?> topupDetailJson({
  String publicRef = 'TUP-ABC123',
  String status = 'pending',
  bool pendingUntilAdminApproval = true,
  bool credited = false,
  bool moneyMoved = false,
  bool canRetry = false,
  String enteredAmount = '25.00',
  String enteredCurrency = 'USD',
  String enteredFormatted = r'$25.00',
  String walletAmount = '25.00',
  Map<String, Object?>? paymentMethod,
  bool hasProof = false,
  String? customerSafeReason,
  String? submittedAt = '2026-09-01T12:00:00.000Z',
  String? reviewedAt,
  String? creditedAt,
}) {
  return {
    'public_ref': publicRef,
    'status': status,
    'pending_until_admin_approval': pendingUntilAdminApproval,
    'credited': credited,
    'money_moved': moneyMoved,
    'can_retry': canRetry,
    'entered_amount': enteredAmount,
    'entered_currency': enteredCurrency,
    'entered_display': enteredDisplayJson(
      currency: enteredCurrency,
      formatted: enteredFormatted,
    ),
    'wallet_amount': moneyJson(
      amount: walletAmount,
      formatted: '\$$walletAmount',
    ),
    'payment_method': paymentMethod ?? paymentMethodJson(),
    'has_proof': hasProof,
    'customer_safe_reason': customerSafeReason,
    'submitted_at': submittedAt,
    'reviewed_at': reviewedAt,
    'credited_at': creditedAt,
  };
}

Map<String, Object?> topupDetailSuccessJson({
  String publicRef = 'TUP-ABC123',
  String status = 'pending',
  bool pendingUntilAdminApproval = true,
  bool credited = false,
  String enteredAmount = '25.00',
  String enteredCurrency = 'USD',
  String enteredFormatted = r'$25.00',
  String walletAmount = '25.00',
}) {
  return {
    'data': topupDetailJson(
      publicRef: publicRef,
      status: status,
      pendingUntilAdminApproval: pendingUntilAdminApproval,
      credited: credited,
      enteredAmount: enteredAmount,
      enteredCurrency: enteredCurrency,
      enteredFormatted: enteredFormatted,
      walletAmount: walletAmount,
    ),
  };
}

Map<String, Object?> topupSubmitSuccessJson({
  bool replayed = false,
  bool pendingUntilAdminApproval = true,
  Map<String, Object?>? topup,
}) {
  return {
    'data': {
      'replayed': replayed,
      'pending_until_admin_approval': pendingUntilAdminApproval,
      'topup': topup ?? topupDetailJson(),
    },
  };
}

Map<String, Object?> topupStatusCompletedJson({
  bool replayed = false,
  Map<String, Object?>? topup,
}) {
  return {
    'data': {
      'state': 'completed',
      'replayed': replayed,
      'pending_until_admin_approval': true,
      'topup': topup ?? topupDetailJson(),
    },
  };
}

Map<String, Object?> topupStatusProcessingJson({int retryAfterSeconds = 2}) {
  return {
    'data': {'state': 'processing', 'retry_after_seconds': retryAfterSeconds},
  };
}

Map<String, Object?> paymentMethodListJson({
  List<Map<String, Object?>>? methods,
}) {
  return {
    'data': methods ?? [paymentMethodJson()],
  };
}

TopupDetail samplePendingTopup() => TopupDetail.fromJson(topupDetailJson());

WalletTransactionPage sampleTransactionPage({int lastPage = 1}) =>
    WalletTransactionPage.fromJson(
      walletTransactionPageJson(lastPage: lastPage),
    );

TopupListPage sampleTopupPage({
  int lastPage = 1,
  String? pendingTopupPublicRef,
}) => TopupListPage.fromJson(
  topupListPageJson(
    lastPage: lastPage,
    pendingTopupPublicRef: pendingTopupPublicRef,
  ),
);

OffsetPagination emptyPagination() =>
    OffsetPagination(page: 1, perPage: walletPageSize, total: 0, lastPage: 1);
