import UIKit

/// The paper a print-ready PDF is laid out for. The choice is part of the
/// deterministic layout input, so preview, export and system print always
/// describe the same sheet.
enum PaperSize: String, CaseIterable, Identifiable, Sendable {
    case a4
    case usLetter

    var id: String { rawValue }

    /// Standard dimensions in PDF points (72 per inch).
    var pointSize: CGSize {
        switch self {
        case .a4:
            CGSize(width: 595.28, height: 841.89)
        case .usLetter:
            CGSize(width: 612, height: 792)
        }
    }

    var localizedName: String {
        switch self {
        case .a4:
            String(localized: "A4")
        case .usLetter:
            String(localized: "Letter")
        }
    }

    /// US Letter is the everyday office size in these regions; everywhere else
    /// defaults to A4.
    static func `default`(for locale: Locale = .current) -> PaperSize {
        let region = locale.region?.identifier ?? ""
        return usLetterRegions.contains(region) ? .usLetter : .a4
    }

    private static let usLetterRegions: Set<String> = [
        "US", "CA", "MX", "CL", "CO", "CR", "DO", "GT", "NI", "PA", "PH", "PR",
        "SV", "VE",
    ]
}

/// Fixed print metrics. They are deliberately independent of the device's
/// Dynamic Type setting: a print-ready PDF must paginate the same way on every
/// device.
enum PrintReadyMetrics {
    static let margin: CGFloat = 48
    static let titleBottomSpacing: CGFloat = 20
    static let itemSpacing: CGFloat = 12
    static let checkboxSize: CGFloat = 12
    static let checkboxLineWidth: CGFloat = 1
    static let checkboxTextSpacing: CGFloat = 12

    static let titleFont = UIFont.systemFont(ofSize: 22, weight: .bold)
    static let itemFont = UIFont.systemFont(ofSize: 12)

    static var titleAttributes: [NSAttributedString.Key: Any] {
        [.font: titleFont, .paragraphStyle: paragraphStyle, .foregroundColor: UIColor.black]
    }

    static var itemAttributes: [NSAttributedString.Key: Any] {
        [.font: itemFont, .paragraphStyle: paragraphStyle, .foregroundColor: UIColor.black]
    }

    private static var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        return style
    }
}

/// The deterministic layout shared by the preview, the exported PDF and the
/// system print job. Every frame is resolved up front so the three outputs
/// cannot drift apart.
struct PrintReadyLayout: Equatable, Sendable {
    struct PlacedItem: Equatable, Sendable {
        var title: String
        var checkboxFrame: CGRect
        var textFrame: CGRect

        var frame: CGRect { checkboxFrame.union(textFrame) }
    }

    struct Page: Equatable, Sendable {
        var titleFrame: CGRect?
        var items: [PlacedItem]
    }

    /// A print-ready checklist stays on one page by default and may use a
    /// second page when it has to. Anything longer has to be reduced or split
    /// by the user instead of being silently cut off.
    static let maximumPageCount = 2

    var title: String
    var paperSize: PaperSize
    var margins: UIEdgeInsets
    var pages: [Page]
    /// Items that do not fit inside `maximumPageCount` pages. They are never
    /// dropped quietly — the user is told about them before exporting.
    var unplacedItemTitles: [String]

    var pageSize: CGSize { paperSize.pointSize }
    var pageCount: Int { pages.count }
    var placedItemTitles: [String] { pages.flatMap { $0.items.map(\.title) } }
    var exceedsPageLimit: Bool { !unplacedItemTitles.isEmpty }

    var contentRect: CGRect {
        CGRect(
            x: margins.left,
            y: margins.top,
            width: pageSize.width - margins.left - margins.right,
            height: pageSize.height - margins.top - margins.bottom
        )
    }

    init(project: ChecklistProject, paperSize: PaperSize) {
        let margin = PrintReadyMetrics.margin
        self.title = project.title
        self.paperSize = paperSize
        self.margins = UIEdgeInsets(top: margin, left: margin, bottom: margin, right: margin)
        self.pages = []
        self.unplacedItemTitles = []

        let content = contentRect
        let textWidth = content.width
            - PrintReadyMetrics.checkboxSize
            - PrintReadyMetrics.checkboxTextSpacing

        var completedPages: [Page] = []
        var pendingTitleFrame: CGRect? = CGRect(
            x: content.minX,
            y: content.minY,
            width: content.width,
            height: Self.height(
                of: project.title,
                attributes: PrintReadyMetrics.titleAttributes,
                width: content.width
            )
        )
        var pendingItems: [PlacedItem] = []
        var cursorY = content.minY + (pendingTitleFrame?.height ?? 0)
            + PrintReadyMetrics.titleBottomSpacing

        for (index, item) in project.items.enumerated() {
            let textHeight = Self.height(
                of: item.title,
                attributes: PrintReadyMetrics.itemAttributes,
                width: textWidth
            )
            let rowHeight = max(textHeight, PrintReadyMetrics.checkboxSize)

            if cursorY + rowHeight > content.maxY {
                let currentPageNumber = completedPages.count + 1
                let fitsOnAFreshPage = rowHeight <= content.height
                guard currentPageNumber < Self.maximumPageCount, fitsOnAFreshPage else {
                    unplacedItemTitles = project.items[index...].map(\.title)
                    break
                }
                completedPages.append(
                    Page(titleFrame: pendingTitleFrame, items: pendingItems)
                )
                pendingTitleFrame = nil
                pendingItems = []
                cursorY = content.minY
            }

            let textFrame = CGRect(
                x: content.minX + PrintReadyMetrics.checkboxSize
                    + PrintReadyMetrics.checkboxTextSpacing,
                y: cursorY,
                width: textWidth,
                height: textHeight
            )
            let checkboxFrame = CGRect(
                x: content.minX,
                y: cursorY + (PrintReadyMetrics.itemFont.lineHeight
                    - PrintReadyMetrics.checkboxSize) / 2,
                width: PrintReadyMetrics.checkboxSize,
                height: PrintReadyMetrics.checkboxSize
            )
            pendingItems.append(
                PlacedItem(
                    title: item.title,
                    checkboxFrame: checkboxFrame,
                    textFrame: textFrame
                )
            )
            cursorY += rowHeight + PrintReadyMetrics.itemSpacing
        }

        if pendingTitleFrame != nil || !pendingItems.isEmpty {
            completedPages.append(Page(titleFrame: pendingTitleFrame, items: pendingItems))
        }
        pages = completedPages
    }

    private static func height(
        of text: String,
        attributes: [NSAttributedString.Key: Any],
        width: CGFloat
    ) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        let bounds = NSAttributedString(string: text, attributes: attributes)
            .boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
        return ceil(bounds.height)
    }
}

enum PrintReadyDocumentError: LocalizedError, Equatable {
    case exceedsPageLimit(unplacedItemCount: Int)

    var errorDescription: String? {
        switch self {
        case .exceedsPageLimit(let unplacedItemCount):
            String(
                format: String(
                    localized: unplacedItemCount == 1
                        ? "%ld item does not fit on two pages. Shorten or remove items, or split this list."
                        : "%ld items do not fit on two pages. Shorten or remove items, or split this list."
                ),
                unplacedItemCount
            )
        }
    }
}

/// A checklist that has been turned into a print-ready PDF. The preview, the
/// exported file and the system print job all read `data` from the same value,
/// so they cannot show different content.
struct PrintReadyDocument {
    let project: ChecklistProject
    let paperSize: PaperSize
    let layout: PrintReadyLayout
    let data: Data

    init(project: ChecklistProject, paperSize: PaperSize) {
        let layout = PrintReadyLayout(project: project, paperSize: paperSize)
        self.project = project
        self.paperSize = paperSize
        self.layout = layout
        self.data = PrintReadyPDFRenderer.pdfData(for: layout)
    }

    var pageCount: Int { layout.pageCount }
    var exceedsPageLimit: Bool { layout.exceedsPageLimit }
    var fileName: String { "\(sanitizedTitle).pdf" }

    /// A one-line description of the chosen paper and page count, shown beneath
    /// the preview so the user can confirm what will be exported or printed.
    var summary: String {
        let pages = String(
            format: String(
                localized: pageCount == 1 ? "%ld page" : "%ld pages"
            ),
            pageCount
        )
        return "\(paperSize.localizedName) · \(pages)"
    }

    /// The actionable notice shown when the checklist is too long to export.
    var overflowDescription: String {
        PrintReadyDocumentError
            .exceedsPageLimit(unplacedItemCount: layout.unplacedItemTitles.count)
            .localizedDescription
    }

    /// PDFKit does not expose the drawn checklist to VoiceOver, so the preview
    /// reads out the same content the sheet shows.
    var accessibilityLabel: String {
        ([project.title] + layout.placedItemTitles).joined(separator: ", ")
    }

    /// Throws when the checklist needs more pages than a print-ready PDF may
    /// use. Callers must surface the error instead of exporting a document that
    /// is missing items.
    func verifyFitsWithinThePageLimit() throws {
        guard layout.exceedsPageLimit else { return }
        throw PrintReadyDocumentError.exceedsPageLimit(
            unplacedItemCount: layout.unplacedItemTitles.count
        )
    }

    func writeToTemporaryFile() throws -> URL {
        try verifyFitsWithinThePageLimit()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return url
    }

    private var sanitizedTitle: String {
        let cleaned = project.title
            .components(separatedBy: CharacterSet(charactersIn: #"/\:*?"<>|"#))
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? String(localized: "Checklist") : cleaned
    }
}

/// Draws a `PrintReadyLayout` into a fixed-size PDF. This is the only place a
/// checklist is turned into pixels, so the preview, the exported file and the
/// system print job are the same document.
enum PrintReadyPDFRenderer {
    static func pdfData(for layout: PrintReadyLayout) -> Data {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [kCGPDFContextTitle as String: layout.title]
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(origin: .zero, size: layout.pageSize),
            format: format
        )

        return renderer.pdfData { context in
            for page in layout.pages {
                context.beginPage()

                if let titleFrame = page.titleFrame {
                    draw(layout.title, attributes: PrintReadyMetrics.titleAttributes, in: titleFrame)
                }

                for item in page.items {
                    let inset = PrintReadyMetrics.checkboxLineWidth / 2
                    context.cgContext.setStrokeColor(UIColor.black.cgColor)
                    context.cgContext.setLineWidth(PrintReadyMetrics.checkboxLineWidth)
                    context.cgContext.stroke(
                        item.checkboxFrame.insetBy(dx: inset, dy: inset)
                    )
                    draw(item.title, attributes: PrintReadyMetrics.itemAttributes, in: item.textFrame)
                }
            }
        }
    }

    private static func draw(
        _ text: String,
        attributes: [NSAttributedString.Key: Any],
        in frame: CGRect
    ) {
        NSAttributedString(string: text, attributes: attributes).draw(
            with: frame,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
    }
}
