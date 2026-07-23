# Apple Transaction Verifier

This private Node.js Vercel Function verifies StoreKit transaction JWS values
with Apple's official App Store Server Library. It is called only by the
Supabase managed-AI function using `VERIFIER_SHARED_SECRET`; the iOS app must
never call this endpoint or receive this secret.

Configure the following Vercel environment variables for both Preview and
Production before deploying:

- `VERIFIER_SHARED_SECRET`: a high-entropy shared value also configured as the
  `VERIFICATION_SERVICE_SHARED_SECRET` Supabase Edge Function secret.
- `APPLE_ENVIRONMENT`: `Sandbox` while testing; `Production` at release.
- `APPLE_ROOT_CA_DER_BASE64_LIST`: comma-separated Base64 DER Apple root
  certificates.
- `APPLE_ENABLE_ONLINE_CHECKS`: `true` for deployed environments.
- `APPLE_SERVER_API_ISSUER_ID`, `APPLE_SERVER_API_KEY_ID`, and
  `APPLE_SERVER_API_PRIVATE_KEY_BASE64`: App Store Server API credentials. The
  private key value is the Base64 encoding of the downloaded PEM file.
- `APPLE_APP_ID`: required only for `Production`.

The endpoint first verifies the submitted JWS and then asks the App Store
Server API for current transaction information. A refunded or revoked purchase
is rejected even when a previously valid JWS is replayed. The endpoint returns
only a verified original transaction ID and environment. It neither stores
transaction JWS values nor exposes diagnostic details.
