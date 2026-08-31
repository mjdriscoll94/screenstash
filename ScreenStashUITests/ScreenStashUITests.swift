import XCTest

@MainActor
final class ScreenStashUITests: XCTestCase {
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-skip-onboarding",
            "-seed-sample-data",
            "-reset-data"
        ]
        app.launch()
        return app
    }

    func testOpeningInbox() {
        let app = launchApp()
        XCTAssertTrue(app.navigationBars["Inbox"].waitForExistence(timeout: 5))
    }

    func testImportFlowEntryPoint() {
        let app = launchApp()
        XCTAssertTrue(app.buttons["Import screenshots"].waitForExistence(timeout: 5))
    }

    func testSearchingRecognizedText() {
        let app = launchApp()
        app.tabBars.buttons["Search"].tap()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("gate c12")

        XCTAssertTrue(app.staticTexts["Flight to Chicago"].waitForExistence(timeout: 5))
    }

    func testOpeningSystemCollections() {
        let app = launchApp()
        app.tabBars.buttons["Categories"].tap()

        XCTAssertTrue(app.staticTexts["category.row.Unsorted"].waitForExistence(timeout: 5))
        let resolvedCategory = app.staticTexts["category.row.Resolved"]
        XCTAssertTrue(resolvedCategory.waitForExistence(timeout: 5))
        resolvedCategory.tap()

        XCTAssertTrue(app.navigationBars["Resolved"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Essay to Read"].waitForExistence(timeout: 5))

        app.navigationBars.buttons.firstMatch.tap()
        let archivedCategory = app.staticTexts["category.row.Archived"]
        XCTAssertTrue(archivedCategory.waitForExistence(timeout: 5))
        archivedCategory.tap()

        XCTAssertTrue(app.navigationBars["Archived"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Hotel Confirmation"].waitForExistence(timeout: 5))
    }

    func testDeleteAllAppDataClearsScreenshotsAndRestoresDefaultCategories() {
        let app = launchApp()
        app.tabBars.buttons["Settings"].tap()

        let deleteAllButton = app.buttons["settings.deleteAllData"]
        for _ in 0..<5 where !deleteAllButton.exists {
            app.swipeUp()
        }
        XCTAssertTrue(deleteAllButton.waitForExistence(timeout: 5))
        deleteAllButton.tap()

        let confirmation = app.buttons["Delete All Data"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        confirmation.tap()

        // Unsigned simulator builds cannot always open the configured App Group.
        // The app reports that auxiliary cleanup warning after its local reset;
        // acknowledge it so the assertions still verify the persisted app data.
        let auxiliaryCleanupAlert = app.alerts["Couldn't Complete Action"]
        if auxiliaryCleanupAlert.waitForExistence(timeout: 2) {
            auxiliaryCleanupAlert.buttons["OK"].tap()
        }

        app.tabBars.buttons["Inbox"].tap()
        XCTAssertTrue(app.staticTexts["Your Inbox Is Clear"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Categories"].tap()
        XCTAssertTrue(app.staticTexts["Buy Later"].waitForExistence(timeout: 5))
    }

    func testAddingCustomCategory() {
        let app = launchApp()
        app.tabBars.buttons["Categories"].tap()

        let addButton = app.buttons["category.add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let nameField = app.textFields["category.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Work Ideas")

        let saveButton = app.buttons["category.save"]
        XCTAssertTrue(saveButton.isEnabled)
        saveButton.tap()

        XCTAssertTrue(app.navigationBars["Categories"].waitForExistence(timeout: 5))
    }

    func testDeletingCustomCategory() {
        let app = launchApp()
        app.tabBars.buttons["Categories"].tap()

        app.buttons["category.add"].tap()
        let nameField = app.textFields["category.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Temporary Category")
        app.buttons["category.save"].tap()

        let synchronizationAlert = app.alerts["Couldn't Update Categories"]
        if synchronizationAlert.waitForExistence(timeout: 2) {
            synchronizationAlert.buttons["OK"].tap()
        }

        let category = app.staticTexts["Temporary Category"]
        let categoryList = app.collectionViews.firstMatch
        for _ in 0..<4 where !category.exists {
            categoryList.swipeUp()
        }
        XCTAssertTrue(category.waitForExistence(timeout: 5))
        category.swipeLeft()

        let deleteAction = app.buttons["Delete"]
        XCTAssertTrue(deleteAction.waitForExistence(timeout: 5))
        deleteAction.tap()

        let confirmation = app.buttons["Delete Category"].firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        confirmation.tap()

        XCTAssertFalse(category.waitForExistence(timeout: 1))
    }

    func testDeletingDefaultCategoryUsesAnchoredPrompt() {
        let app = launchApp()
        app.tabBars.buttons["Categories"].tap()

        let category = app.staticTexts["Buy Later"]
        XCTAssertTrue(category.waitForExistence(timeout: 5))
        category.swipeLeft()

        let deleteAction = app.buttons["Delete"]
        XCTAssertTrue(deleteAction.waitForExistence(timeout: 5))
        deleteAction.tap()

        XCTAssertTrue(app.otherElements["category.delete.prompt"].waitForExistence(timeout: 5))
        let promptScreenshot = XCTAttachment(screenshot: app.screenshot())
        promptScreenshot.name = "Default category anchored deletion prompt"
        promptScreenshot.lifetime = .keepAlways
        add(promptScreenshot)
        let confirmation = app.buttons["Delete Category"]
        XCTAssertTrue(confirmation.exists)
        confirmation.tap()

        XCTAssertFalse(category.waitForExistence(timeout: 1))

        app.terminate()
        app.launchArguments = ["-ui-testing", "-skip-onboarding"]
        app.launch()
        app.tabBars.buttons["Categories"].tap()
        XCTAssertFalse(app.staticTexts["Buy Later"].waitForExistence(timeout: 1))
    }

    func testOpeningScreenshotDetail() {
        let app = launchApp()
        let title = app.staticTexts["Weekend Pancakes"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()

        XCTAssertTrue(app.buttons["detail.resolve"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Recognized Text"].exists)
        XCTAssertFalse(app.buttons["Copy Recognized Text"].exists)
    }

    func testSavedReminderIsVisibleAndCanBeRemoved() {
        let app = launchApp()
        app.tabBars.buttons["Search"].tap()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("Flight to Chicago")

        let result = app.staticTexts["Flight to Chicago"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()

        let savedReminder = app.staticTexts["Saved reminder"]
        for _ in 0..<5 where !savedReminder.exists {
            app.swipeUp()
        }
        XCTAssertTrue(savedReminder.waitForExistence(timeout: 5))

        let removeButton = app.buttons["detail.reminder.remove"]
        XCTAssertTrue(removeButton.exists)
        removeButton.tap()

        XCTAssertTrue(app.staticTexts["Reminder removed"].waitForExistence(timeout: 5))
        XCTAssertFalse(savedReminder.exists)
    }

    func testDeletingSelectedScreenshotFromCategory() {
        let app = launchApp()
        app.tabBars.buttons["Categories"].tap()

        let category = app.staticTexts["category.row.Buy Later"]
        XCTAssertTrue(category.waitForExistence(timeout: 5))
        category.tap()

        let selectButton = app.buttons["collection.select"]
        XCTAssertTrue(selectButton.waitForExistence(timeout: 5))
        selectButton.tap()

        let screenshot = app.buttons["Select Ergonomic Desk Lamp"]
        XCTAssertTrue(screenshot.waitForExistence(timeout: 5))
        screenshot.tap()

        let deleteButton = app.buttons["collection.delete.selected"]
        XCTAssertTrue(deleteButton.isEnabled)
        deleteButton.tap()

        let confirmation = app.sheets.buttons["Delete Screenshot"].firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        confirmation.tap()

        XCTAssertTrue(app.staticTexts["No Buy Later Screenshots"].waitForExistence(timeout: 5))
    }

    func testDeletingMultipleSelectedScreenshotsFromInbox() {
        let app = launchApp()

        let selectButton = app.buttons["inbox.select"]
        XCTAssertTrue(selectButton.waitForExistence(timeout: 5))
        selectButton.tap()
        app.buttons["Select All"].tap()

        let deleteButton = app.buttons["inbox.delete.selected"]
        XCTAssertTrue(deleteButton.isEnabled)
        deleteButton.tap()

        let confirmation = app.sheets.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Delete '")
        ).firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        confirmation.tap()

        XCTAssertTrue(app.staticTexts["Your Inbox Is Clear"].waitForExistence(timeout: 5))
    }

    func testMarkingScreenshotResolved() {
        let app = launchApp()
        let title = app.staticTexts["Weekend Pancakes"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()

        let resolveButton = app.buttons["detail.resolve"]
        XCTAssertTrue(resolveButton.waitForExistence(timeout: 5))
        resolveButton.tap()

        XCTAssertTrue(app.navigationBars["Inbox"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Weekend Pancakes"].exists)
    }
}
