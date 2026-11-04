import AppIntents

/// Phrases Siri and the Shortcuts app should offer for Flash.
///
/// Every phrase is about a printable packing checklist. Negative phrases keep
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
                "Create a packing checklist in \(.applicationName)",
                "Make a printable packing list in \(.applicationName)",
            ],
            shortTitle: "New Packing List",
            systemImageName: "list.bullet.clipboard"
        )
        AppShortcut(
            intent: AddPackingItemsIntent(),
            phrases: [
                "Add packing items in \(.applicationName)",
                "Add items to a printable checklist in \(.applicationName)",
            ],
            shortTitle: "Add Packing Items",
            systemImageName: "plus"
        )
        AppShortcut(
            intent: ShowPackingChecklistIntent(),
            phrases: [
                "Show a packing checklist in \(.applicationName)",
                "Open \(\.$target) in \(.applicationName)",
            ],
            shortTitle: "Show Packing List",
            systemImageName: "list.bullet"
        )
        AppShortcut(
            intent: ExportPrintReadyPDFIntent(),
            phrases: [
                "Export a printable packing list from \(.applicationName)",
                "Export a print-ready PDF of \(\.$packingList) from \(.applicationName)",
            ],
            shortTitle: "Export Packing PDF",
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
                "List my packing checklists in \(.applicationName)",
                "Show my printable packing lists in \(.applicationName)",
            ],
            shortTitle: "Packing Lists",
            systemImageName: "list.bullet.rectangle"
        )
    }
}
