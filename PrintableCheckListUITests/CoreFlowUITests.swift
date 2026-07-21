import XCTest

final class CoreFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-resetForUITests",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
        ]
        app.launch()
    }

    func testAddItemsPreviewAndOpenSettings() {
        XCTAssertTrue(app.navigationBars["Lists"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Travel Checklist"].exists)

        app.staticTexts["Travel Checklist"].tap()
        XCTAssertTrue(app.navigationBars["Travel Checklist"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Passport"].exists)

        app.buttons["New Item"].tap()
        XCTAssertTrue(app.navigationBars["New Item"].waitForExistence(timeout: 3))
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 2))
        editor.typeText("Camera\nPhone charger")
        app.buttons["Save"].tap()

        let camera = app.staticTexts["Camera"]
        scrollToElement(camera)
        XCTAssertTrue(camera.isHittable)

        let phoneCharger = app.staticTexts["Phone charger"]
        scrollToElement(phoneCharger)
        XCTAssertTrue(phoneCharger.isHittable)

        app.buttons["Actions"].tap()
        let preview = app.buttons["Preview"].firstMatch
        XCTAssertTrue(preview.waitForExistence(timeout: 2))
        preview.tap()
        XCTAssertTrue(app.navigationBars["Preview"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Camera"].exists)

        app.navigationBars["Preview"].buttons.firstMatch.tap()
        app.navigationBars["Travel Checklist"].buttons.firstMatch.tap()
        app.buttons["Settings"].tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["iCloud Auto Sync"].exists)
        XCTAssertTrue(app.staticTexts["Open Source"].exists)
        let privacyPolicy = app.staticTexts["Privacy Policy"]
        scrollToElement(privacyPolicy)
        XCTAssertTrue(privacyPolicy.isHittable)
        XCTAssertTrue(app.staticTexts["Share Anonymous Usage Data"].exists)
        XCTAssertFalse(app.staticTexts["Supabase Backup"].exists)
        XCTAssertFalse(app.buttons["Back Up Now"].exists)
    }

    func testActionsMenuStaysAnchoredAfterReturningFromPreview() {
        XCTAssertTrue(app.navigationBars["Lists"].waitForExistence(timeout: 5))

        app.staticTexts["Travel Checklist"].tap()
        XCTAssertTrue(app.navigationBars["Travel Checklist"].waitForExistence(timeout: 3))

        let actions = app.buttons["Actions"]
        XCTAssertTrue(actions.waitForExistence(timeout: 2))
        actions.tap()

        let preview = app.buttons["Preview"].firstMatch
        XCTAssertTrue(preview.waitForExistence(timeout: 2))
        assertMenu(preview, isAnchoredTo: actions)
        preview.tap()

        XCTAssertTrue(app.navigationBars["Preview"].waitForExistence(timeout: 3))
        app.navigationBars["Preview"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Travel Checklist"].waitForExistence(timeout: 3))

        actions.tap()
        XCTAssertTrue(preview.waitForExistence(timeout: 2))
        assertMenu(preview, isAnchoredTo: actions)
    }

    private func assertMenu(
        _ menuItem: XCUIElement,
        isAnchoredTo source: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let verticalDistance = abs(source.frame.midY - menuItem.frame.midY)
        XCTAssertLessThan(
            verticalDistance,
            250,
            "The actions menu should remain anchored to the bottom toolbar button.",
            file: file,
            line: line
        )
    }

    private func scrollToElement(_ element: XCUIElement, maxSwipes: Int = 10) {
        for _ in 0..<maxSwipes {
            if element.exists && element.isHittable {
                return
            }
            app.swipeUp()
        }
    }
}
