import AppIntents

/// Phrases Siri and the Shortcuts app should offer for Flash.
///
/// Every phrase is about a printable checklist. Negative phrases keep
/// reminder, to-do, and notification wording from resolving to this app.
/// Localized phrase text lives in `AppShortcuts.strings`.
struct FlashAppShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .orange

    static var negativePhrases: NegativeAppShortcutPhrases {
        NegativeAppShortcutPhrases(phrases: [
            "Remind me in \(.applicationName)",
            "Add a reminder in \(.applicationName)",
            "Add a todo in \(.applicationName)",
            "Set a notification in \(.applicationName)",
        ])
    }

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreatePackingChecklistIntent(),
            phrases: [
                "Create a checklist in \(.applicationName)",
                "Make a printable checklist in \(.applicationName)",
            ],
            shortTitle: "New Checklist",
            systemImageName: "list.bullet.clipboard"
        )
        AppShortcut(
            intent: AddPackingItemsIntent(),
            phrases: [
                "Add checklist items in \(.applicationName)",
                "Add items to a printable checklist in \(.applicationName)",
            ],
            shortTitle: "Add Checklist Items",
            systemImageName: "plus"
        )
        AppShortcut(
            intent: ShowPackingChecklistIntent(),
            phrases: [
                "Show a checklist in \(.applicationName)",
                "Open \(\.$target) in \(.applicationName)",
            ],
            shortTitle: "Open Checklist",
            systemImageName: "list.bullet"
        )
        AppShortcut(
            intent: ExportPrintReadyPDFIntent(),
            phrases: [
                "Export a printable checklist from \(.applicationName)",
                "Export a print-ready PDF of \(\.$packingList) from \(.applicationName)",
            ],
            shortTitle: "Export Checklist PDF",
            systemImageName: "square.and.arrow.up"
        )
        AppShortcut(
            intent: ShowPackingPrintPreviewIntent(),
            phrases: [
                "Open the print preview in \(.applicationName)",
                "Preview \(\.$packingList) in \(.applicationName)",
            ],
            shortTitle: "Print Preview",
            systemImageName: "doc.text.magnifyingglass"
        )
        AppShortcut(
            intent: ListPackingChecklistsIntent(),
            phrases: [
                "List my checklists in \(.applicationName)",
                "Show my printable checklists in \(.applicationName)",
            ],
            shortTitle: "Checklists",
            systemImageName: "list.bullet.rectangle"
        )
    }
}
