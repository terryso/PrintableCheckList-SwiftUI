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
        app.buttons["Create Manually"].tap()
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
        XCTAssertTrue(app.descendants(matching: .any)["aiConfigurationLink"].exists)
        XCTAssertFalse(app.staticTexts["Share Anonymous Usage Data"].exists)
    }

    func testSettingsShowsShortVersionOnly() {
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))

        let settingsList = app.collectionViews["settingsList"]
        XCTAssertTrue(settingsList.exists)
        for _ in 0..<5 {
            settingsList.swipeUp()
        }
        let versionText = app.staticTexts["appVersionText"]
        XCTAssertTrue(versionText.waitForExistence(timeout: 2))
        XCTAssertEqual(versionText.label, "Version 2.1.0")
        XCTAssertFalse(versionText.label.contains("("))
    }

    func testEmptyListGuidesUserToAddItems() {
        app.buttons["newListButton"].tap()
        app.buttons["Create Manually"].tap()
        let nameField = app.textFields["newProjectNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.typeText("Ideas")
        app.buttons["createProjectButton"].tap()

        XCTAssertTrue(app.navigationBars["Ideas"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["No Items Yet"].exists)
        XCTAssertTrue(app.buttons["Add Manually"].exists)

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
        app.buttons["Add Manually"].tap()
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

    func testAICreateAndSupplementUsingFakeGenerator() {
        app.terminate()
        app = makeApp(additionalArguments: ["-useFakeAIGeneratorForUITests"])
        app.launch()

        app.buttons["newListButton"].tap()
        app.buttons["Generate with AI"].tap()
        let topicEditor = app.textViews["aiTopicEditor"]
        XCTAssertTrue(topicEditor.waitForExistence(timeout: 3))
        topicEditor.typeText("Winter trip")
        app.staticTexts["11 of 1,000 characters"].tap()
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        XCTAssertTrue((topicEditor.value as? String)?.contains("Winter trip") == true)

        topicEditor.tap()
        topicEditor.typeText(" with children")
        XCTAssertTrue((topicEditor.value as? String)?.contains("with children") == true)

        app.buttons["generateChecklistButton"].tap()
        XCTAssertFalse(app.alerts.firstMatch.exists)

        XCTAssertTrue(app.textViews["aiGeneratedItemsEditor"].waitForExistence(timeout: 5))
        let generatedTitle = app.textFields["aiGeneratedTitleField"]
        generatedTitle.tap()
        generatedTitle.press(forDuration: 1)
        app.menuItems["Select All"].tap()
        generatedTitle.typeText("Edited AI List")
        app.buttons["saveAIGeneratedChecklistButton"].tap()
        XCTAssertTrue(app.navigationBars["Edited AI List"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Power adapter"].exists)

        app.buttons["addItemsButton"].tap()
        app.buttons["Add with AI"].tap()
        XCTAssertTrue(app.textViews["aiTopicEditor"].waitForExistence(timeout: 3))
        app.buttons["generateChecklistButton"].tap()
        XCTAssertFalse(app.alerts.firstMatch.exists)
        XCTAssertTrue(app.textViews["aiGeneratedItemsEditor"].waitForExistence(timeout: 5))
        app.buttons["saveAIGeneratedChecklistButton"].tap()
        XCTAssertTrue(app.buttons["Portable charger"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Emergency contact"].exists)
    }

    func testAIMissingConfigurationOpensSettings() {
        app.buttons["newListButton"].tap()
        app.buttons["Generate with AI"].tap()

        XCTAssertTrue(app.staticTexts["AI Is Not Configured"].waitForExistence(timeout: 3))
        app.buttons["openAISettingsButton"].tap()
        XCTAssertTrue(app.navigationBars["AI Generation"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["aiBaseURLField"].exists)
    }

    func testAIGenerationKeepsInputAfterErrorAndRetries() {
        app.terminate()
        app = makeApp(additionalArguments: ["-useFlakyAIGeneratorForUITests"])
        app.launch()

        app.buttons["newListButton"].tap()
        app.buttons["Generate with AI"].tap()
        let topicEditor = app.textViews["aiTopicEditor"]
        XCTAssertTrue(topicEditor.waitForExistence(timeout: 3))
        topicEditor.typeText("Retry this topic")
        app.buttons["generateChecklistButton"].tap()

        XCTAssertTrue(
            app.staticTexts[
                "The AI service is temporarily unavailable. Please try again later."
            ].waitForExistence(timeout: 5)
        )
        XCTAssertTrue((topicEditor.value as? String)?.contains("Retry this topic") == true)

        app.buttons["Modify AI Configuration"].tap()
        XCTAssertTrue(app.navigationBars["AI Generation"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()
        XCTAssertTrue(topicEditor.waitForExistence(timeout: 3))
        XCTAssertTrue((topicEditor.value as? String)?.contains("Retry this topic") == true)

        let retryButton = app.buttons["generateChecklistButton"]
        let retryEnabled = expectation(
            for: NSPredicate(format: "enabled == true"),
            evaluatedWith: retryButton
        )
        wait(for: [retryEnabled], timeout: 2)
        retryButton.tap()
        XCTAssertTrue(app.textViews["aiGeneratedItemsEditor"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["aiGeneratedTitleField"].value as? String, "Retry List")
    }

    func testAIGenerationCanBeCancelledWithoutLosingInput() {
        app.terminate()
        app = makeApp(additionalArguments: ["-useSlowAIGeneratorForUITests"])
        app.launch()

        app.buttons["newListButton"].tap()
        app.buttons["Generate with AI"].tap()
        let topicEditor = app.textViews["aiTopicEditor"]
        XCTAssertTrue(topicEditor.waitForExistence(timeout: 3))
        topicEditor.typeText("Keep this topic")
        app.buttons["generateChecklistButton"].tap()

        let cancelButton = app.buttons["cancelAIGenerationButton"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 2))
        cancelButton.tap()
        XCTAssertTrue((topicEditor.value as? String)?.contains("Keep this topic") == true)
        XCTAssertFalse(app.textViews["aiGeneratedItemsEditor"].exists)
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
