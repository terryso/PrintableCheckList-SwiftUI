import XCTest

final class PrintReadyPDFUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testPreviewShowsTheRegionPaperAndTheWholeChecklist() {
        launch()
        openPreviewForDefaultChecklist()

        let summary = app.staticTexts["printablePDFSummary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertEqual(summary.label, "Letter · 1 page")

        let pdf = app.descendants(matching: .any)["printablePDFView"]
        XCTAssertTrue(pdf.exists)
        XCTAssertTrue(pdf.label.contains("Travel Checklist"))
        XCTAssertTrue(pdf.label.contains("Passport"))
        XCTAssertTrue(
            pdf.label.contains("Get a Credit card, debit card or ATM card"),
            "The preview must show the last item, not a truncated list"
        )

        XCTAssertTrue(app.buttons["previewExportPDFButton"].isEnabled)
        XCTAssertTrue(app.buttons["previewPrintButton"].isEnabled)
        XCTAssertFalse(app.staticTexts["printableOverflowNotice"].exists)
    }

    func testSwitchingPaperSizeUpdatesTheSamePreview() {
        launch()
        openPreviewForDefaultChecklist()

        let summary = app.staticTexts["printablePDFSummary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))

        app.segmentedControls["paperSizePicker"].buttons["A4"].tap()
        XCTAssertTrue(
            summary.waitForLabel("A4 · 1 page"),
            "Actual: \(summary.label)"
        )

        app.segmentedControls["paperSizePicker"].buttons["Letter"].tap()
        XCTAssertTrue(
            summary.waitForLabel("Letter · 1 page"),
            "Actual: \(summary.label)"
        )
    }

    func testExportingHandsThePDFToTheSystemShareSheet() {
        launch()
        openPreviewForDefaultChecklist()

        let exportButton = app.buttons["previewExportPDFButton"]
        XCTAssertTrue(exportButton.waitForExistence(timeout: 5))
        exportButton.tap()

        XCTAssertTrue(
            app.otherElements["ActivityListView"].waitForExistence(timeout: 10)
        )
    }

    func testPrintingOpensTheSystemPrintPanelForTheSameDocument() {
        launch()
        openPreviewForDefaultChecklist()

        let printButton = app.buttons["previewPrintButton"]
        XCTAssertTrue(printButton.waitForExistence(timeout: 5))
        printButton.tap()

        XCTAssertTrue(
            app.staticTexts["No Printer Selected"].waitForExistence(timeout: 15)
        )
    }

    func testAChecklistLongerThanTwoPagesBlocksExportAndPrint() {
        launch(additionalArguments: ["-seedOverlongChecklistForUITests"])

        app.staticTexts["Overlong List"].tap()
        app.buttons["previewButton"].tap()

        let notice = app.staticTexts["printableOverflowNotice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        XCTAssertTrue(
            notice.label.contains("split this list"),
            "The notice must tell the user what to do. Actual: \(notice.label)"
        )
        XCTAssertEqual(app.staticTexts["printablePDFSummary"].label, "Letter · 2 pages")
        XCTAssertFalse(app.buttons["previewExportPDFButton"].isEnabled)
        XCTAssertFalse(app.buttons["previewPrintButton"].isEnabled)
    }

    func testChinesePreviewUsesA4AndLocalizedPageCount() {
        launch(language: "zh-Hans", locale: "zh_CN")
        openPreviewForDefaultChecklist(previewTitle: "预览")

        let summary = app.staticTexts["printablePDFSummary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertEqual(summary.label, "A4 · 1 页")
        XCTAssertTrue(app.buttons["previewExportPDFButton"].isEnabled)
    }

    private func openPreviewForDefaultChecklist(previewTitle: String = "Preview") {
        XCTAssertTrue(app.staticTexts["Travel Checklist"].waitForExistence(timeout: 5))
        app.staticTexts["Travel Checklist"].tap()
        app.buttons["previewButton"].tap()
        XCTAssertTrue(app.navigationBars[previewTitle].waitForExistence(timeout: 5))
    }

    private func launch(
        additionalArguments: [String] = [],
        language: String = "en",
        locale: String = "en_US"
    ) {
        app = XCUIApplication()
        app.launchArguments = [
            "-resetForUITests",
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", locale,
        ] + additionalArguments
        app.launch()
    }
}

private extension XCUIElement {
    func waitForLabel(_ expected: String) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", expected),
            object: self
        )
        return XCTWaiter.wait(for: [expectation], timeout: 5) == .completed
    }
}
