import 'package:flutter_test/flutter_test.dart';
import 'package:indirimgo_mobile/features/catalog/domain/catalog_models.dart';
import 'package:indirimgo_mobile/features/purchase/domain/purchase_models.dart';
import 'package:indirimgo_mobile/features/wallet/domain/wallet_models.dart';

import '../../support/purchase_fixtures.dart';

void main() {
  group('PackageRequirementField', () {
    test('parses text number and select fields', () {
      final text = PackageRequirementField.fromJson(requirementFieldJson());
      expect(text.inputType, RequirementInputType.text);
      expect(text.required, isTrue);

      final number = PackageRequirementField.fromJson(
        requirementFieldJson(key: 'level', label: 'Level', inputType: 'number'),
      );
      expect(number.inputType, RequirementInputType.number);

      final select = PackageRequirementField.fromJson(
        requirementFieldJson(
          key: 'server',
          label: 'Server',
          inputType: 'select',
          options: ['EU', 'NA'],
        ),
      );
      expect(select.options, ['EU', 'NA']);
    });

    test('rejects unsafe schema instead of inventing fields', () {
      expect(
        PackageRequirementField.tryParse(
          requirementFieldJson(inputType: 'regex'),
        ),
        isNull,
      );
      expect(
        PackageRequirementField.tryParse(
          requirementFieldJson(inputType: 'select', options: null),
        ),
        isNull,
      );
      expect(
        PackageRequirementField.tryParse(requirementFieldJson(key: '1bad')),
        isNull,
      );
    });

    test('toString never includes requirement values', () {
      final field = PackageRequirementField.fromJson(requirementFieldJson());
      expect(field.toString(), isNot(contains('secret-player')));
      expect(field.toString(), contains('key: id'));
    });
  });

  group('PackageDetail requirements', () {
    test('marks unsupported schema fail-closed', () {
      final detail = PackageDetailResult.fromJson(
        packageDetailJson(
          requirements: [
            requirementFieldJson(),
            requirementFieldJson(key: 'bad', inputType: 'file'),
          ],
        ),
      );
      expect(detail.package.requirementsSupported, isFalse);
      expect(detail.package.requirements, hasLength(1));
    });

    test('ignores unknown additive requirement fields', () {
      final json = requirementFieldJson();
      json['supplier_rule'] = 'secret';
      final field = PackageRequirementField.fromJson(json);
      expect(field.key, 'id');
    });
  });

  group('CheckoutQuote', () {
    test('parses quote with string money and wallet affordability', () {
      final quote = CheckoutQuote.fromSuccessJson(checkoutQuoteJson());
      expect(quote.total.amount, '20.00');
      expect(quote.wallet.canAfford, isTrue);
      expect(quote.item.quantity, 2);
      expect(quote.toString(), isNot(contains(quote.quoteFingerprint)));
    });

    test('keeps decimal money as string', () {
      final quote = CheckoutQuote.fromSuccessJson(
        checkoutQuoteJson(totalAmount: '12.50'),
      );
      expect(quote.total.amount, isA<String>());
      expect(quote.total.amount, '12.50');
    });

    test('custom amount quote keeps requested_amount', () {
      final quote = CheckoutQuote.fromSuccessJson(
        checkoutQuoteJson(
          amountMode: 'custom',
          quantity: 1,
          requestedAmount: 150,
          totalAmount: '1.50',
        ),
      );
      expect(quote.item.requestedAmount, 150);
      expect(quote.item.quantity, 1);
    });
  });

  group('WalletSummary and receipt', () {
    test('parses wallet summary', () {
      final summary = WalletSummary.fromJson(walletSummaryJson());
      expect(summary.availableToSpend.amount, '42.50');
      expect(summary.pricesVisible, isTrue);
      expect(summary.pendingTopupPublicRef, isNull);
    });

    test('parses receipt and status shapes', () {
      final result = CheckoutResult.fromJson(checkoutSuccessJson());
      expect(result.order.orderNumber, 'ORD-2026-000001');
      expect(result.replayed, isFalse);

      final completed = CheckoutStatus.fromResponse(
        statusCode: 200,
        json: checkoutStatusCompletedJson(),
      );
      expect(completed.state, CheckoutStatusState.completed);
      expect(completed.order?.orderNumber, 'ORD-2026-000001');

      final processing = CheckoutStatus.fromResponse(
        statusCode: 202,
        json: checkoutStatusProcessingJson(),
      );
      expect(processing.state, CheckoutStatusState.processing);
      expect(processing.retryAfterSeconds, 2);

      final failed = CheckoutStatus.fromResponse(
        statusCode: 200,
        json: checkoutStatusFailedJson(),
      );
      expect(failed.state, CheckoutStatusState.failed);
      expect(failed.code, 'checkout_failed');
    });
  });

  group('CheckoutLineItemRequest', () {
    test('serializes exactly one item payload without prices', () {
      const item = CheckoutLineItemRequest(
        productId: 901,
        packageId: 42,
        quantity: 2,
        requirements: {'id': 'player-secret'},
      );
      final json = item.toJson();
      expect(
        json.keys,
        containsAll(['product_id', 'package_id', 'quantity', 'requirements']),
      );
      expect(json.containsKey('unit_price'), isFalse);
      expect(json.containsKey('line_total'), isFalse);
      expect(item.toString(), isNot(contains('player-secret')));
    });
  });

  group('PurchaseDraft privacy', () {
    test('toString omits requirement values and fingerprints', () {
      final draft = PurchaseDraft(
        customerId: 7,
        packageId: 42,
        packageName: 'Example',
        product: ProductOption.fromJson(fixedProductJson()),
        requirementsSchema: [
          PackageRequirementField.fromJson(requirementFieldJson()),
        ],
        requirementsSupported: true,
        pricesVisible: true,
        quantity: 1,
        requirementValues: const {'id': 'secret-value'},
        quote: sampleCheckoutQuote,
      );
      expect(draft.toString(), isNot(contains('secret-value')));
      expect(
        draft.toString(),
        isNot(contains(sampleCheckoutQuote.quoteFingerprint)),
      );
    });
  });
}
