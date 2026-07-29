# İndirimGo Mobile agent guide

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
- `lib/features/shell`: minimal post-login shell only.
- Prefer feature-first code and small manual immutable models. Avoid code
  generation and generic clean-architecture layers.

## Implementation rules

- Use Riverpod without generators and `go_router`.
- Use the single configured Dio client; never add secret-bearing logging.
- Store only the Sanctum token and its expiry in secure storage.
- Keep password, 2FA codes, recovery codes, and challenge tokens out of
  persistence and logs.
- A 401 is authoritative. Connectivity, timeout, and 5xx failures must retain
  the session for retry.
- User-facing copy belongs in Arabic and English ARB files.
- Preserve exact Android namespace/application ID `tr.indirimgo.app`.
- Cleartext HTTP may be enabled only in `android/app/src/debug`.

## Verification

Run formatting, analysis, all tests, and a debug APK build with a non-secret
local `API_BASE_URL`. Tests must remain independent of a running backend.
