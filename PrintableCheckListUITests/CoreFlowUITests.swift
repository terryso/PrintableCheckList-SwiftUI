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
        XCTAssertTrue(app.buttons["Preview"].waitForExistence(timeout: 2))
        app.buttons["Preview"].tap()
        XCTAssertTrue(app.navigationBars["Preview"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Camera"].exists)

        app.navigationBars["Preview"].buttons.firstMatch.tap()
        app.navigationBars["Travel Checklist"].buttons.firstMatch.tap()
        app.buttons["Settings"].tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["iCloud Auto Sync"].exists)
        XCTAssertTrue(app.staticTexts["Open Source"].exists)
        XCTAssertFalse(app.staticTexts["Supabase Backup"].exists)
        XCTAssertFalse(app.buttons["Back Up Now"].exists)
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
