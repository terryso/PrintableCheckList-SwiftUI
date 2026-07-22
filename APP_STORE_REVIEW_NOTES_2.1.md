# App Store Review Notes — 2.1.0

## AI checklist generation

Version 2.1.0 adds optional bring-your-own-key AI checklist generation. Reviewers can find it in either location:

1. Lists → New List → Generate with AI
2. Open a list → Add → Add with AI

Configuration is available at Settings → AI Checklist Generation. The user selects GLM, OpenAI, DeepSeek, or a custom OpenAI-compatible HTTPS endpoint and supplies their own API Key. No developer-provided AI quota or purchase is included in this version.

The user explicitly starts each request by tapping Generate after configuring their selected provider. A new-list request sends the topic and requirements. A supplement request can also send the current list title and up to the first 200 item texts. The request travels directly from the device to the provider and does not pass through the developer's Supabase service.

The API Key is stored with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` in Keychain. It is not synchronized or included in product analytics. AI output is editable and is not persisted until the user taps Create List or Add Items. Manual checklist creation, offline editing, preview, and printing remain available without AI configuration.

The public privacy policy and App Store Connect privacy answers should disclose Other User Content for App Functionality because content can be sent to the user-selected third-party AI provider.
