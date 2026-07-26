import PDFKit
import XCTest
@testable import PrintableCheckList

@MainActor
final class PrintReadyPDFTests: XCTestCase {
    func testPaperSizesUseTheirStandardPointDimensions() {
        XCTAssertEqual(PaperSize.a4.pointSize.width, 595.28, accuracy: 0.01)
        XCTAssertEqual(PaperSize.a4.pointSize.height, 841.89, accuracy: 0.01)
        XCTAssertEqual(PaperSize.usLetter.pointSize.width, 612)
        XCTAssertEqual(PaperSize.usLetter.pointSize.height, 792)
    }

    func testDefaultTravelChecklistsFitOnOnePageInEveryPaperSize() {
        let projects = [
            DefaultContent.englishTravelChecklist,
            DefaultContent.chineseTravelChecklist,
        ]

        for project in projects {
            for paperSize in PaperSize.allCases {
                let layout = PrintReadyLayout(project: project, paperSize: paperSize)

                XCTAssertEqual(layout.pageCount, 1, "\(project.title) on \(paperSize)")
                XCTAssertFalse(layout.exceedsPageLimit, "\(project.title) on \(paperSize)")
                XCTAssertEqual(
                    layout.placedItemTitles,
                    project.items.map(\.title),
                    "\(project.title) on \(paperSize)"
                )
            }
        }
    }

    func testTheRegionDefaultPaperMatchesLocalOfficePaper() {
        XCTAssertEqual(PaperSize.default(for: Locale(identifier: "en_US")), .usLetter)
        XCTAssertEqual(PaperSize.default(for: Locale(identifier: "es_MX")), .usLetter)
        XCTAssertEqual(PaperSize.default(for: Locale(identifier: "zh_CN")), .a4)
        XCTAssertEqual(PaperSize.default(for: Locale(identifier: "en_GB")), .a4)
    }

    func testRenderedPDFUsesTheLayoutPagesAndKeepsEveryItemInOrder() throws {
        let project = Self.project(itemCount: 30)
        let layout = PrintReadyLayout(project: project, paperSize: .a4)
        XCTAssertEqual(layout.pageCount, 2)
        XCTAssertFalse(layout.exceedsPageLimit)

        let document = try XCTUnwrap(
            PDFDocument(data: PrintReadyPDFRenderer.pdfData(for: layout))
        )
        XCTAssertEqual(document.pageCount, layout.pageCount)

        let mediaBox = try XCTUnwrap(document.page(at: 0)).bounds(for: .mediaBox)
        XCTAssertEqual(mediaBox.width, PaperSize.a4.pointSize.width, accuracy: 1)
        XCTAssertEqual(mediaBox.height, PaperSize.a4.pointSize.height, accuracy: 1)

        let text = try XCTUnwrap(document.string)
        var searchStart = text.startIndex
        for expected in [project.title] + project.items.map(\.title) {
            let found = try XCTUnwrap(
                text.range(of: expected, range: searchStart..<text.endIndex),
                "\(expected) is missing or out of order in the rendered PDF"
            )
            searchStart = found.upperBound
        }
    }

    func testLongWrappingItemsAreNeverTruncatedInTheRenderedPDF() throws {
        let wrapped = String(
            repeating: "Rain jacket for every child plus a spare set of clothes ",
            count: 3
        )
        let project = ChecklistProject(
            title: "Final Packing",
            items: [ChecklistItem(title: wrapped)]
        )
        let layout = PrintReadyLayout(project: project, paperSize: .usLetter)

        let document = try XCTUnwrap(
            PDFDocument(data: PrintReadyPDFRenderer.pdfData(for: layout))
        )
        let text = try XCTUnwrap(document.string)
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: " ", with: "")
        XCTAssertTrue(
            text.contains(wrapped.replacingOccurrences(of: " ", with: "")),
            "The rendered PDF dropped part of a wrapping item"
        )
    }

    /// The renderer draws each title/item at the exact frame the layout hands
    /// it (`draw(..., in: frame)`), so asserting every layout frame stays
    /// inside the content rect and never overlaps the row above also proves the
    /// rendered PDF respects the margins — the pixels cannot leave the frame.
    func testLongChecklistsStayInsideTheMarginsWithoutOverlap() {
        let projects = [
            Self.project(itemCount: 40),
            ChecklistProject(
                title: "旅行清单",
                items: (0..<24).map {
                    ChecklistItem(
                        title: "第 \($0) 项：给孩子准备的换洗衣物、药品和随身证件复印件"
                    )
                }
            ),
        ]

        for project in projects {
            for paperSize in PaperSize.allCases {
                let layout = PrintReadyLayout(project: project, paperSize: paperSize)
                let content = layout.contentRect
                XCTAssertLessThanOrEqual(
                    layout.pageCount,
                    PrintReadyLayout.maximumPageCount
                )

                for page in layout.pages {
                    var previousFrame = page.titleFrame
                    if let titleFrame = page.titleFrame {
                        XCTAssertTrue(content.contains(titleFrame), project.title)
                    }
                    for item in page.items {
                        XCTAssertTrue(
                            content.contains(item.frame),
                            "\(item.title) fell outside the \(paperSize) margins"
                        )
                        if let previousFrame {
                            XCTAssertFalse(
                                previousFrame.intersects(item.frame),
                                "\(item.title) overlaps the row above it"
                            )
                        }
                        previousFrame = item.frame
                    }
                }
            }
        }
    }

    func testChecklistsLongerThanTwoPagesReportEveryItemThatDoesNotFit() {
        let project = Self.project(itemCount: 90)
        let layout = PrintReadyLayout(project: project, paperSize: .a4)

        XCTAssertEqual(layout.pageCount, PrintReadyLayout.maximumPageCount)
        XCTAssertTrue(layout.exceedsPageLimit)
        XCTAssertEqual(
            layout.placedItemTitles + layout.unplacedItemTitles,
            project.items.map(\.title),
            "Items must be reported, never silently dropped"
        )
    }

    func testTheSameChecklistAndPaperAlwaysProduceTheSameLayout() {
        let project = Self.project(itemCount: 30)

        XCTAssertEqual(
            PrintReadyLayout(project: project, paperSize: .a4),
            PrintReadyLayout(project: project, paperSize: .a4)
        )
        XCTAssertNotEqual(
            PrintReadyLayout(project: project, paperSize: .a4),
            PrintReadyLayout(project: project, paperSize: .usLetter)
        )
    }

    func testExportAndSystemPrintShipTheIdenticalPDF() throws {
        let document = PrintReadyDocument(
            project: DefaultContent.englishTravelChecklist,
            paperSize: .usLetter
        )

        let url = try document.writeToTemporaryFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let job = try PrintService.printJob(for: document)

        XCTAssertEqual(url.pathExtension, "pdf")
        XCTAssertEqual(try Data(contentsOf: url), job.pdfData)
        XCTAssertEqual(job.pdfData, document.data)
        XCTAssertEqual(job.printInfo.jobName, document.project.title)
        XCTAssertEqual(job.printInfo.outputType, .general)
    }

    /// The preview, the exported file and the system print job all draw the
    /// same bytes. `PDFPreview` is fed `document.data`, so this asserts the
    /// preview's input equals the export and print bytes and renders the same
    /// page count — closing the three-output agreement the spec demands. Ordered
    /// content of the rendered bytes is covered by
    /// `testRenderedPDFUsesTheLayoutPagesAndKeepsEveryItemInOrder`.
    func testPreviewExportAndPrintAllRenderTheSameChecklist() throws {
        let document = PrintReadyDocument(
            project: DefaultContent.chineseTravelChecklist,
            paperSize: .a4
        )

        let exportURL = try document.writeToTemporaryFile()
        defer { try? FileManager.default.removeItem(at: exportURL) }
        let printJob = try PrintService.printJob(for: document)
        let previewData = document.data

        XCTAssertEqual(previewData, try Data(contentsOf: exportURL))
        XCTAssertEqual(previewData, printJob.pdfData)

        let rendered = try XCTUnwrap(PDFDocument(data: previewData))
        XCTAssertEqual(rendered.pageCount, document.pageCount)
        let text = try XCTUnwrap(rendered.string)
        XCTAssertTrue(text.contains(document.project.title))
        XCTAssertTrue(text.contains("现金"))
        XCTAssertTrue(text.contains("酒店确认函"))
    }

    func testAnOverlongChecklistCanBeNeitherExportedNorPrinted() {
        let document = PrintReadyDocument(
            project: Self.project(itemCount: 90),
            paperSize: .a4
        )
        XCTAssertTrue(document.exceedsPageLimit)

        let expected = PrintReadyDocumentError.exceedsPageLimit(
            unplacedItemCount: document.layout.unplacedItemTitles.count
        )
        XCTAssertThrowsError(try document.writeToTemporaryFile()) { error in
            XCTAssertEqual(error as? PrintReadyDocumentError, expected)
        }
        XCTAssertThrowsError(try PrintService.printJob(for: document)) { error in
            XCTAssertEqual(error as? PrintReadyDocumentError, expected)
        }
    }

    private static func project(itemCount: Int) -> ChecklistProject {
        ChecklistProject(
            title: "Family Trip",
            items: (0..<itemCount).map {
                ChecklistItem(title: String(format: "Packing item %03ld", $0))
            }
        )
    }
}
