import XCTest

final class AppStoreScreenshotUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait

        app = XCUIApplication()
        app.launchArguments = [
            "-resetForUITests",
            "-useFakeAIGeneratorForUITests",
            "-AppleLanguages", "(zh-Hans)",
            "-AppleLocale", "zh_CN",
        ]
        app.launch()
    }

    func testCaptureAIGenerationFlow() {
        XCTAssertTrue(app.navigationBars["清单"].waitForExistence(timeout: 5))

        app.buttons["newListButton"].tap()
        app.buttons["AI 生成清单"].tap()

        let topicEditor = app.textViews["aiTopicEditor"]
        XCTAssertTrue(topicEditor.waitForExistence(timeout: 3))
        topicEditor.typeText("冬天带孩子去日本旅行 7 天，需要滑雪和温泉用品")
        app.staticTexts
            .matching(NSPredicate(format: "label BEGINSWITH %@", "已输入 "))
            .firstMatch
            .tap()
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        capture("01-AI输入需求")

        app.buttons["generateChecklistButton"].tap()
        XCTAssertTrue(app.textViews["aiGeneratedItemsEditor"].waitForExistence(timeout: 5))
        capture("02-AI生成结果")

        app.buttons["saveAIGeneratedChecklistButton"].tap()
        XCTAssertTrue(app.navigationBars["亲子日本冬季旅行清单"].waitForExistence(timeout: 3))
        capture("03-生成后的可打印清单")

        app.navigationBars["亲子日本冬季旅行清单"].buttons.element(boundBy: 0).tap()
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 3))
        app.descendants(matching: .any)["aiConfigurationLink"].tap()
        XCTAssertTrue(app.navigationBars["AI 生成"].waitForExistence(timeout: 3))
        capture("04-GLM与自有APIKey")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
