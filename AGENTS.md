# İndirimGo Mobile agent guide

## Ownership and PR control

- Only Omar may merge, close, mark ready, auto-merge, change the PR target, or
  delete the working branch for this repository's pull requests.
- Agents must keep PRs draft/open unless Omar explicitly instructs otherwise.
- Agents must not create a replacement PR for an existing reviewable PR unless
  Omar explicitly requests that.

## Boundaries

- This repository is the customer Android client.
- Laravel `OmarBobk/Indirim-GO` `origin/staging` and
  `docs/api/v1/openapi.yaml` are authoritative for API behavior.
- Never duplicate Laravel authorization, pricing, wallet, ledger, or other
  trusted domain decisions in Flutter.
- Never commit credentials, bearer tokens, 2FA values, `.env` files, or real
  environment URLs.

## Structure

- `lib/core`: configuration, errors, localization, networking, routing,
  storage, theme, and shared widgets.
- `lib/features/auth`: manual models, repository contract/remote
  implementation, Riverpod state, and auth screens.
- `lib/features/catalog`: commerce shell (home, package list/search, package
  detail, account access) with manual OpenAPI models and a focused repository.
- Prefer feature-first code and small manual immutable models. Avoid code
  generation and generic clean-architecture layers.
- Never recalculate Laravel prices, parse money amounts into `double`, or add
  purchase/checkout/wallet UI during M2.2.

## Implementation rules

- Use Riverpod without generators and `go_router`.
- Use the single configured Dio client; never add secret-bearing logging.
- Store only the Sanctum token and its expiry in secure storage as one atomic
  session value.
- Keep password, 2FA codes, recovery codes, and challenge tokens out of
  persistence and logs.
- A 401 is authoritative. Connectivity, timeout, and 5xx failures must retain
  the session for retry.
- Clear tokens only for the request session that observed unauthorized
  responses.
- Do not decide 2FA expiry on the client clock; let the API own challenge
  validity.
- Never surface raw API `message` or unknown `code` values in UI.
- User-facing copy belongs in Arabic and English ARB files.
- Preserve exact Android namespace/application ID `tr.indirimgo.app`.
- Cleartext HTTP may be enabled only in `android/app/src/debug` for local
  emulator/host targets. Release/profile builds must use HTTPS.
- Keep Android backup disabled while tokens live in app-private secure storage.

## Verification

Run formatting, analysis, all tests, and a debug APK build with a non-secret
local `API_BASE_URL`. Tests must remain independent of a running backend.
Keep CI on a pinned Flutter/Dart toolchain rather than floating `stable`.
