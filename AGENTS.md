# PrintableCheckList SwiftUI rewrite

The Objective-C reference app is read-only and lives at
`/Users/nick/CascadeProjects/PrintableCheckList`.

## Build workflow

Do not require the Xcode GUI. Regenerate the project whenever `project.yml` or
the source tree changes:

```bash
./Scripts/generate.sh
./Scripts/build.sh
./Scripts/test.sh
./Scripts/run-simulator.sh
```

The generated `PrintableCheckList.xcodeproj` is not committed. Treat
`project.yml` as the source of truth.

## Product contract

- Preserve the old app's features and information architecture: list/item
  editing and ordering, printing, preview, settings actions, English and
  Simplified Chinese strings, and the default travel checklist.
- Use current native SwiftUI and iOS system components. Do not pixel-copy the
  2015 navigation bar, image buttons, table styling, or action sheets.
- Preserve the production bundle identifier so an eventual App Store update can
  migrate the legacy `NSKeyedArchiver` data under `keyProjects`.
- Keep local editing functional without a network connection.
- Do not claim cloud synchronization works until a real Supabase project, Auth,
  RLS policies, and end-to-end sync tests exist.
- Never put a Supabase `service_role` key in the app or repository.
