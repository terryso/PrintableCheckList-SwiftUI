import Foundation

/// Deferred Siri AI phase. Classic App Intents in this folder are the iOS 17
/// Shortcuts implementation and stay available on the iOS 17.0 deployment target.
///
/// When an iOS 27.3 SDK is adopted, assistant-tool metadata
/// (`@AppIntent(.tool)` / skills) can be added behind `@available(iOS 27.3, *)`
/// on the existing packing intents. Do not invent a second checklist model.
/// Do not expose reminders, notifications, generic to-dos, AI generation, or
/// in-app purchase through that later surface.
enum SiriAIIntentExtensionPoint {
    /// System version required before the assistant-tool phase is in scope.
    static let deferredSystemVersion = "27.3"

    /// The intents a future 27.3 conformance should reuse.
    static let classicIntentNames = [
        "ListPackingChecklistsIntent",
        "ListPackingItemsIntent",
        "ShowPackingChecklistIntent",
        "ShowPackingPrintPreviewIntent",
        "CreatePackingChecklistIntent",
        "AddPackingItemsIntent",
        "ExportPrintReadyPDFIntent",
    ]

    /// Placeholder for the later phase. It does not call any 27.3 API, so the
    /// iOS 17 deployment target can keep compiling against the current SDK.
    @available(iOS 27.3, *)
    static func adoptAssistantTools() {
        // Attach assistant-tool metadata to the classic intents listed above.
        // Leave AI checklist generation and Pro purchase on the in-app path.
    }
}
