import XCTest

final class CoreFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = makeApp()
        app.launch()
    }

    func testCreateCompleteListEditPreviewAndOpenSettings() {
        XCTAssertTrue(app.navigationBars["Lists"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.alerts["Share Checklist Data?"].exists)

        app.buttons["newListButton"].tap()
        XCTAssertTrue(app.navigationBars["New List"].waitForExistence(timeout: 3))

        let nameField = app.textFields["newProjectNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.typeText("Weekend Shopping")

        let initialItemsEditor = app.textViews["newProjectItemsEditor"]
        XCTAssertTrue(initialItemsEditor.waitForExistence(timeout: 2))
        initialItemsEditor.tap()
        initialItemsEditor.typeText("Milk\nEggs")
        app.buttons["createProjectButton"].tap()

        XCTAssertTrue(app.navigationBars["Weekend Shopping"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Milk"].exists)
        XCTAssertTrue(app.buttons["Eggs"].exists)
        XCTAssertTrue(app.buttons["addItemsButton"].exists)
        XCTAssertTrue(app.buttons["previewButton"].exists)
        XCTAssertTrue(app.buttons["printButton"].exists)
        XCTAssertFalse(app.images["square"].exists)

        app.buttons["Milk"].tap()
        let editField = app.textFields["singleLineEditorField"]
        XCTAssertTrue(editField.waitForExistence(timeout: 2))
        editField.tap()
        editField.press(forDuration: 1)
        app.menuItems["Select All"].tap()
        editField.typeText("Oat Milk")
        app.buttons["singleLineEditorSaveButton"].tap()
        XCTAssertTrue(app.buttons["Oat Milk"].waitForExistence(timeout: 2))

        app.buttons["previewButton"].tap()
        XCTAssertTrue(app.navigationBars["Preview"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Oat Milk"].exists)
        XCTAssertTrue(app.buttons["previewPrintButton"].exists)

        app.navigationBars["Preview"].buttons.firstMatch.tap()
        app.navigationBars["Weekend Shopping"].buttons.firstMatch.tap()
        app.buttons["settingsButton"].tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Sync"].exists)
        XCTAssertTrue(app.staticTexts["Privacy"].exists)
        XCTAssertTrue(app.staticTexts["Support & About"].exists)
        XCTAssertTrue(app.staticTexts["Share Checklist Content for Product Analytics"].exists)
        XCTAssertFalse(app.staticTexts["Share Anonymous Usage Data"].exists)
    }

    func testEmptyListGuidesUserToAddItems() {
        app.buttons["newListButton"].tap()
        let nameField = app.textFields["newProjectNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.typeText("Ideas")
        app.buttons["createProjectButton"].tap()

        XCTAssertTrue(app.navigationBars["Ideas"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["No Items Yet"].exists)
        XCTAssertTrue(app.buttons["Add Items"].exists)

        app.buttons["emptyAddItemsButton"].tap()
        let editor = app.textViews["addItemsEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 2))
        editor.typeText("First idea\n\nSecond idea")
        app.buttons["addItemsSaveButton"].tap()

        XCTAssertTrue(app.buttons["First idea"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Second idea"].exists)
    }

    func testSwipeActionsExposeEditAndDelete() {
        app.staticTexts["Travel Checklist"].tap()
        XCTAssertTrue(app.navigationBars["Travel Checklist"].waitForExistence(timeout: 3))

        let passport = app.buttons["Passport"]
        XCTAssertTrue(passport.waitForExistence(timeout: 2))
        passport.swipeLeft()
        XCTAssertTrue(app.buttons["Edit"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Delete"].exists)
        app.buttons["Edit"].tap()
        XCTAssertTrue(app.textFields["singleLineEditorField"].waitForExistence(timeout: 2))
    }

    func testAnalyticsConsentAppearsOnlyAfterAddingItems() {
        app.terminate()
        app = makeApp(additionalArguments: ["-enableAnalyticsConsentForUITests"])
        app.launch()

        XCTAssertTrue(app.navigationBars["Lists"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.alerts["Share Checklist Data?"].exists)

        app.staticTexts["Travel Checklist"].tap()
        app.buttons["addItemsButton"].tap()
        let editor = app.textViews["addItemsEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 2))
        editor.typeText("Camera")
        app.buttons["addItemsSaveButton"].tap()

        let consentAlert = app.alerts["Share Checklist Data?"]
        XCTAssertTrue(consentAlert.waitForExistence(timeout: 3))
        XCTAssertTrue(consentAlert.buttons["Agree and Turn On"].exists)
        consentAlert.buttons["Not Now"].tap()
        XCTAssertFalse(consentAlert.exists)
    }

    private func makeApp(additionalArguments: [String] = []) -> XCUIApplication {
        let application = XCUIApplication()
        application.launchArguments = [
            "-resetForUITests",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
        ] + additionalArguments
        return application
    }
}
