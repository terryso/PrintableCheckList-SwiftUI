# Flash Privacy Notice

Last updated: July 22, 2026

## Local Checklists and iCloud

Flash stores checklists locally first. If iCloud Sync is enabled, list names and item text are synchronized between the user's devices through their own Apple iCloud account. Local editing, preview, and printing continue to work when iCloud Sync is off.

## AI Checklist Generation

AI generation is optional and does not include developer-provided model quota. The user chooses a provider and supplies a Base URL, model, and API Key.

- The API Key is stored only in Apple Keychain on the current device. It is not written to checklist files, UserDefaults, iCloud, Supabase, or app logs, and it is not sent to the Flash developer.
- When generating a new checklist, the topic and additional requirements are sent directly from the device to the selected third-party AI provider.
- When supplementing an existing checklist, the topic, current list title, and up to the first 200 items may be sent directly to the selected third-party AI provider.
- The app sends a request only after the user taps Generate or Generate Again. The destination is determined by the provider and Base URL selected by the user in AI Settings.
- Generated content is shown for review and editing and is not saved to a local checklist until the user confirms.
- Flash and its Supabase service do not proxy AI requests or store the original prompt or response. The selected provider may process content under its own terms and privacy policy.
- AI configuration is stored separately on each device and can be deleted at any time in Settings.

## Optional Product Analytics

AI generation is separate from the developer's optional Supabase product analytics. List names, item text, and a random installation identifier are sent to the developer's Supabase project only after the user separately and explicitly enables checklist analytics sharing. This data is used for product analytics, not advertising or cross-device sync. The user can turn sharing off and delete the data associated with the installation at any time.

## Contact

For questions about this privacy notice, email `oxtiger@gmail.com`.
