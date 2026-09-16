import 'package:flutter_test/flutter_test.dart';
import 'package:indirimgo_mobile/features/wallet/domain/wallet_models.dart';

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
}
