# Flash Privacy Notice

Last updated: July 24, 2026

## Local Checklists and iCloud

Flash stores checklists locally first. If iCloud Sync is enabled, list names and item text are synchronized between the user's devices through their own Apple iCloud account. Local editing, preview, and printing continue to work when iCloud Sync is off.

## AI Checklist Generation

AI generation is an optional Pro feature. Pro is a one-time purchase that includes up to 20 managed-AI operations per calendar month and also permits use of the user's own API key. BYOK operations do not consume the managed monthly allowance.

### Managed AI

- The app calls the product-operated service only after the user enters requirements and taps Generate or Generate Again.
- The request may include the topic and requirements, the current checklist title, up to the first 200 checklist items, the interface language, and the device's IANA time zone. The managed service sends content needed for generation to the model provider configured by the developer.
- The app submits an Apple-signed StoreKit transaction JWS. The product's transaction-verification service uses Apple's verification library and the App Store Server API to check the product, environment, and current refund or revocation state. That service does not persist the JWS.
- To enforce the monthly allowance and request idempotency, Supabase stores the App Store original transaction identifier, Sandbox or Production environment, first-operation time zone, operation identifier, calendar month, processing state, and completed generated response. The original request body and StoreKit JWS are not written to these allowance tables. A generated response may contain checklist content related to the user's input.
- Unexpected service-error logs contain only the operation identifier and error category, not the request body, JWS, topic, or model credentials.
- Managed-AI data is processed by the developer-configured Supabase service, transaction verifier, and model provider, each under its applicable terms and privacy policy. The user may request deletion of managed-AI-associated data using the contact information below. Later use may recreate allowance records after deletion.

### Bring Your Own Key (BYOK)

- The API key is stored only in Apple Keychain on the current device. It is not written to checklist files, UserDefaults, iCloud, Supabase, or app logs, and it is not sent to the Flash developer.
- The topic, additional requirements, current list title, and up to the first 200 items are sent directly from the device to the selected third-party AI provider. That provider also handles any requested web search.
- AI configuration is stored separately on each device and can be deleted at any time in Settings.

With either route, generated content is shown for review and editing and is not saved to a local checklist until the user confirms.

## Optional Product Analytics

Data processing required for managed AI is separate from optional product analytics. List names, item text, and a random installation identifier are sent to the developer's Supabase project for analytics only after the user separately and explicitly enables checklist analytics sharing. This analytics data is not used for advertising or cross-device sync. The user can turn sharing off and delete the analytics data associated with the installation at any time.

## Contact

For questions about this privacy notice, email `oxtiger@gmail.com`.
