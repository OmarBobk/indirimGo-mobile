import 'dart:convert';

/// Captured from Laravel `origin/staging` `0b6282b` via GET
/// `/api/v1/wallet/{topups,transactions,payment-methods}` against synthetic
/// owned web-era records (SubmitCustomerTopupRequest + ApproveTopupRequest +
/// posted purchase). Values are customer-safe envelopes only.
const laravelWalletEnvelopeSource = r'''
{
    "topups": {
        "data": [
            {
                "public_ref": "TUP-63C22699F0",
                "status": "pending",
                "pending_until_admin_approval": true,
                "credited": false,
                "money_moved": false,
                "can_retry": false,
                "wallet_amount": {
                    "amount": "1.00",
                    "currency": "USD",
                    "display": {
                        "currency": "USD",
                        "formatted": "$1.00"
                    }
                },
                "payment_method_name": "Sham Cash",
                "has_proof": false,
                "submitted_at": "2026-09-16T21:12:05+03:00"
            },
            {
                "public_ref": "TUP-0A8B2AF3B9",
                "status": "approved",
                "pending_until_admin_approval": false,
                "credited": true,
                "money_moved": true,
                "can_retry": false,
                "wallet_amount": {
                    "amount": "25.00",
                    "currency": "USD",
                    "display": {
                        "currency": "USD",
                        "formatted": "$25.00"
                    }
                },
                "payment_method_name": "Sham Cash",
                "has_proof": false,
                "submitted_at": "2026-09-16T21:12:05+03:00"
            }
        ],
        "meta": {
            "pagination": {
                "page": 1,
                "per_page": 20,
                "total": 2,
                "last_page": 1
            },
            "pending_topup_public_ref": "TUP-63C22699F0"
        }
    },
    "transactions": {
        "data": [
            {
                "public_ref": "WTX-1A3DA54349",
                "type": "purchase",
                "direction": "debit",
                "amount": {
                    "amount": "10.00",
                    "currency": "USD",
                    "display": {
                        "currency": "USD",
                        "formatted": "$10.00"
                    }
                },
                "occurred_at": "2026-09-16T21:12:05+03:00",
                "related_order_number": null,
                "related_topup_public_ref": null,
                "customer_safe_description": null
            },
            {
                "public_ref": "Reference pending",
                "type": "topup",
                "direction": "credit",
                "amount": {
                    "amount": "25.00",
                    "currency": "USD",
                    "display": {
                        "currency": "USD",
                        "formatted": "$25.00"
                    }
                },
                "occurred_at": "2026-09-16T21:12:05+03:00",
                "related_order_number": null,
                "related_topup_public_ref": "TUP-0A8B2AF3B9",
                "customer_safe_description": null
            }
        ],
        "meta": {
            "pagination": {
                "page": 1,
                "per_page": 20,
                "total": 2,
                "last_page": 1
            }
        }
    },
    "payment_methods": {
        "data": [
            {
                "id": 1,
                "name": "Sham Cash",
                "instructions": "Sham Cash",
                "image_url": null
            },
            {
                "id": 2,
                "name": "EFT Transfer",
                "instructions": "EFT Transfer",
                "image_url": null
            }
        ]
    },
    "summary": {
        "data": {
            "available_to_spend": {
                "amount": "25.00",
                "currency": "USD",
                "display": {
                    "currency": "USD",
                    "formatted": "$25.00"
                }
            },
            "pending_topup_public_ref": "TUP-63C22699F0"
        },
        "meta": {
            "prices_visible": true
        }
    },
    "empty_topups": {
        "data": [],
        "meta": {
            "pagination": {
                "page": 1,
                "per_page": 20,
                "total": 0,
                "last_page": 1
            },
            "pending_topup_public_ref": null
        }
    },
    "empty_transactions": {
        "data": [],
        "meta": {
            "pagination": {
                "page": 1,
                "per_page": 20,
                "total": 0,
                "last_page": 1
            }
        }
    }
}
''';

Map<String, Object?> laravelWalletEnvelope(String key) {
  final root = jsonDecode(laravelWalletEnvelopeSource);
  if (root is! Map) {
    throw const FormatException('Laravel wallet dump must be an object.');
  }
  return _asObjectMap(root[key], key);
}

Map<String, Object?> _asObjectMap(Object? value, String label) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((mapKey, mapValue) => MapEntry('$mapKey', mapValue));
  }
  throw FormatException('$label must be an object.');
}
