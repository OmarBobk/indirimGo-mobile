import 'package:flutter_test/flutter_test.dart';
import 'package:indirimgo_mobile/features/wallet/domain/wallet_models.dart';

import '../../support/laravel_wallet_envelopes.dart';
import '../../support/wallet_fixtures.dart';

void main() {
  test('wallet summary keeps pending ref and money strings', () {
    final summary = WalletSummary.fromJson(
      walletSummaryJson(pendingTopupPublicRef: 'TUP-ABC123'),
    );
    expect(summary.availableToSpend.amount, '42.50');
    expect(summary.pendingTopupPublicRef, 'TUP-ABC123');
  });

  test('entered TRY amount stays a string and is not wallet USD', () {
    final detail = TopupDetail.fromJson(
      topupDetailJson(
        enteredAmount: '100.00',
        enteredCurrency: 'TRY',
        enteredFormatted: '₺100.00',
        walletAmount: '3.00',
      ),
    );
    expect(detail.enteredAmount, '100.00');
    expect(detail.enteredCurrency, 'TRY');
    expect(detail.walletAmount.amount, '3.00');
    expect(detail.walletAmount.currency, 'USD');
    expect(detail.pendingUntilAdminApproval, isTrue);
    expect(detail.credited, isFalse);
    expect(detail.moneyMoved, isFalse);
  });

  test('submit result stays pending until admin approval', () {
    final result = TopupSubmitResult.fromJson(topupSubmitSuccessJson());
    expect(result.pendingUntilAdminApproval, isTrue);
    expect(result.topup.credited, isFalse);
    expect(result.topup.publicRef, 'TUP-ABC123');
  });

  test('rejects unsupported transaction types and invalid public refs', () {
    expect(
      () => WalletTransactionItem.fromJson(
        walletTransactionItemJson(type: 'internal_note'),
      ),
      throwsFormatException,
    );
    expect(
      () => TopupListItem.fromJson(topupListItemJson(publicRef: 'ORD-1')),
      throwsFormatException,
    );
  });

  test('parses captured Laravel web-era top-ups and posted activity', () {
    final topups = TopupListPage.fromJson(laravelWalletEnvelope('topups'));
    expect(topups.items, hasLength(2));
    expect(topups.items.first.publicRef, 'TUP-63C22699F0');
    expect(topups.items.first.pendingUntilAdminApproval, isTrue);
    expect(topups.items.first.credited, isFalse);
    expect(topups.items.last.status, 'approved');
    expect(topups.items.last.credited, isTrue);
    expect(topups.items.last.walletAmount.amount, '25.00');

    final transactions = WalletTransactionPage.fromJson(
      laravelWalletEnvelope('transactions'),
    );
    expect(transactions.items.map((item) => item.type).toList(), [
      'purchase',
      'topup',
    ]);
    expect(transactions.items.first.direction, 'debit');
    expect(transactions.items.last.relatedTopupPublicRef, 'TUP-0A8B2AF3B9');
    expect(transactions.items.last.publicRef, 'Reference pending');

    final methods = [
      for (final item
          in laravelWalletEnvelope('payment_methods')['data']! as List)
        PaymentMethod.fromJson(
          (item as Map).map((key, value) => MapEntry('$key', value)),
        ),
    ];
    expect(methods.map((method) => method.id).toList(), [1, 2]);
  });

  test('malformed Laravel-shaped lists throw instead of looking empty', () {
    expect(
      () => TopupListPage.fromJson(const {'data': 'nope', 'meta': {}}),
      throwsFormatException,
    );
    expect(
      () => WalletTransactionPage.fromJson(const {
        'data': [
          {'public_ref': 'WTX-1'},
        ],
        'meta': {
          'pagination': {'page': 1, 'per_page': 20, 'total': 1, 'last_page': 1},
        },
      }),
      throwsFormatException,
    );
  });
}
