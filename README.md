# İndirimGo Mobile

Customer-only Android application for İndirimGo. Milestone **M5** adds a
dedicated Wallet screen, posted transaction history, and manual top-up
requests against Laravel Mobile API **1.5.0**. Submission stays pending until
existing admin approval and never credits the wallet on the client.

## Requirements

- Flutter **3.44.8** / Dart **3.12.2** (pinned; CI enforces the same versions)
- Android Studio or an Android SDK and emulator
- The Laravel repository running locally with its `staging` configuration and
  migrations

The Android namespace and application ID are both `tr.indirimgo.app`. The Dart
package name is `indirimgo_mobile`.

## Run locally

Start Laravel so the emulator can reach it:

```powershell
php artisan serve --host=0.0.0.0 --port=8000
```

Set Laravel `APP_URL` correctly so package image URLs resolve. Android emulators
reach the host machine at `10.0.2.2`:

```powershell
flutter pub get --enforce-lockfile
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

For a physical Android device, prefer `adb reverse` with loopback rather than
broadening debug cleartext:

```powershell
adb reverse tcp:8000 tcp:8000
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

`API_BASE_URL` is required, validated at startup, and normalized to one
`/api/v1/` suffix. Debug builds may use HTTP only for `10.0.2.2`, `127.0.0.1`,
or `localhost`. Profile and release builds require HTTPS. Do not pass
credentials, tokens, 2FA values, or other secrets through `--dart-define`.
There is deliberately no `.env` file and no staging URL yet.

Android cleartext is denied by default. The debug network-security config
allows only those local hosts. Main/release keep cleartext disabled. App backup
is disabled so secure session storage cannot restore into an incompatible
Keystore state.

## Authentication behavior

- Username/password authentication against Laravel
- Fortify authenticator and recovery-code 2FA
- Sanctum bearer token stored atomically with `flutter_secure_storage`
- 30-day server-controlled token expiry and no refresh-token flow
- Startup restoration through `GET /me`
- Authoritative 401/403 session rejection clears only the matching session
- Connectivity, timeout, server, and storage failures preserve the token for
  retry where appropriate
- 2FA challenges and codes remain only in memory and are never logged
- Laravel remains authoritative for challenge expiry and attempt limits

## Commerce shell and purchase flow

Authenticated destinations:

- `/app` — Home
- `/app/packages` — Packages (search/category)
- `/app/packages/:id` — package detail (Packages remains selected)
- `/app/packages/:id/buy` — buy-now form (navigation chrome hidden)
- `/app/checkout/review` — server quote review and wallet confirm (outside the shell)
- `/app/checkout/recovery` — unknown-result recovery / polling (outside the shell)
- `/app/orders` — Orders (search + status filters)
- `/app/orders/:orderNumber` — owned order detail (Orders remains selected)
- `/app/account` — identity, language, wallet available-to-spend, logout
- `/app/account/wallet` — wallet summary, top-up history, posted activity
- `/app/account/wallet/topup` — submit a manual top-up (optional proof)
- `/app/account/wallet/topups/:publicRef` — owned top-up detail

A Material 3 `NavigationBar` (or `NavigationRail` from 840 logical pixels)
preserves each destination’s navigation stack. Re-tapping a selected
destination returns to that branch root. Android back pops the inner route,
then returns to Home from a non-Home root.

Consumed endpoints:

- `GET /api/v1/catalog/home`
- `GET /api/v1/packages`
- `GET /api/v1/packages/{id}`
- `GET /api/v1/wallet/summary`
- `GET /api/v1/wallet/transactions`
- `GET /api/v1/wallet/payment-methods`
- `GET /api/v1/wallet/topups`
- `POST /api/v1/wallet/topups` (multipart, requires `Idempotency-Key`)
- `GET /api/v1/wallet/topups/status` (requires `Idempotency-Key`)
- `GET /api/v1/wallet/topups/{public_ref}`
- `POST /api/v1/checkout/quote`
- `POST /api/v1/checkout` (requires `Idempotency-Key`)
- `GET /api/v1/checkout/status` (requires `Idempotency-Key`)
- `GET /api/v1/orders?page={page}&per_page=20&q={q}&customer_state={state}`
- `GET /api/v1/orders/{order_number}`

Prices and totals are displayed from Laravel `display.formatted` only. Flutter
never parses authoritative USD amounts into `double`, never multiplies
price × quantity, and never computes affordability. `meta.prices_visible=false`
hides purchase CTAs and maps quote/checkout to `purchasing_unavailable`
without ending the session.

The authoritative contract is Laravel `docs/api/v1/openapi.yaml` on the Mobile
M5 backend branch (API **1.5.0**). After that backend merges, `origin/staging`
is authoritative.

## Localization and accessibility

Arabic and English use Flutter ARB localization. A persisted
`locale.preference` (`system`, `ar`, or `en`) is restored at startup and kept
across logout. Device language uses the existing supported-locale resolver
(Arabic fallback) and follows OS locale changes; explicit Arabic or English
does not. Login, 2FA, and Account share the selector. Changing language updates
direction, dates, validation, dialogs, navigation labels, and subsequent
`Accept-Language` headers without reconstructing authentication, the router, or
an in-flight checkout. Catalog and historical item names remain exactly as
returned by Laravel. Money and `ORD-…` identifiers stay LTR. The UI supports
light/dark themes, semantic labels, keyboard traversal, large text, and
minimum 48×48 logical-pixel targets.

## Verify

```powershell
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug --dart-define=API_BASE_URL=https://example.invalid/api/v1
apkanalyzer manifest print build/app/outputs/flutter-apk/app-debug.apk |
  dart run tool/verify_android_security.dart --merged-manifest-stdin
```

Tests use fake repositories, fake secure storage, and an in-memory Dio adapter;
they do not need a live Laravel server.

## Release blocker

Release builds still use the debug signing configuration so local
`flutter run --release` works. Production signing must be configured before any
distribution or publishing workflow. No Play upload or deploy step exists in CI.

## M4.2 / M4.5.2 order and UX behavior

M4.2 order list/detail, recovery, and fulfillment polling remain in force.
M4.5.2 adds destination navigation, language preference, Orders search/filters
from API 1.4.0, status badges, and contained catalog artwork.

Omar accepted the earlier M4.3 walkthrough after backend `#48` and mobile `#7`
merged. This M4.5.2 UX slice is not claimed as accepted yet.

Refund/retry/cancel actions, cart, push, Reverb, persistent
order-body caching, client-side pricing, Laravel/CDN/image-contract changes,
and deployment are excluded.

See [`docs/architecture/m5-wallet-topup.md`](docs/architecture/m5-wallet-topup.md)
for wallet and manual top-up architecture,
[`docs/architecture/m4.5.2-ux-foundation.md`](docs/architecture/m4.5.2-ux-foundation.md)
for navigation, language, Orders 1.4.0, images, and a local walkthrough,
[`docs/architecture/m4.2-orders-status.md`](docs/architecture/m4.2-orders-status.md)
for order-history architecture,
[`docs/architecture/m3.2-purchase-flow.md`](docs/architecture/m3.2-purchase-flow.md)
for purchase architecture,
[`docs/architecture/m2.2-commerce-shell.md`](docs/architecture/m2.2-commerce-shell.md)
for catalog foundations, and
[`docs/architecture/m1.2-auth-foundation.md`](docs/architecture/m1.2-auth-foundation.md)
for authentication foundations.
