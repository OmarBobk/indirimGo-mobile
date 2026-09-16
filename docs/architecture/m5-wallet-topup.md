# M5 Flutter Wallet and Manual Top-ups

Customer Android wallet screen against Laravel Mobile API **1.5.0**.

## Contract source

- Repository: `OmarBobk/Indirim-GO`
- Feature branch: `cursor/mobile-m5-wallet-topups-bac0`
- OpenAPI: `docs/api/v1/openapi.yaml` version **1.5.0**

## Scope

- Account CTA → dedicated Wallet (`/app/account/wallet`)
- Available-to-spend from `GET /wallet/summary` (Money envelope)
- Posted transaction history and owned top-up history
- Active payment methods with customer-facing instructions
- Submit `POST /wallet/topups` with explicit `amount` + `currency` + optional proof
- Lost-response recovery via the same `Idempotency-Key` and `GET /wallet/topups/status`
- Pending-until-admin-approval copy; submission never credits locally

## Non-goals

Flutter does not convert TRY→USD, parse Money amounts as `double`, or treat a
pending request as spendable. Admin approval remains a Laravel-only ledger write.

Checkout recovery stays on `PendingCheckoutStore`. Top-up recovery uses a
separate per-customer `PendingTopupStore`.

## Local walkthrough

1. Run Laravel from the M5 backend branch (`php artisan serve --host=0.0.0.0 --port=8000`).
2. `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1`
3. Account → Open wallet → Add funds → enter amount and currency → submit.
4. Confirm available-to-spend is unchanged and the request shows waiting for approval.
5. Staff approval in the existing admin UI then credits the posted ledger.
