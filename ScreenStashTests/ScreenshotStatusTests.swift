import Foundation
import SwiftData
import UserNotifications
import XCTest
@testable import ScreenStash

@MainActor
final class ScreenshotStatusTests: XCTestCase {
    func testResolvingClearsReminderAndSetsResolvedDate() {
        let item = ScreenshotItem(
            imageData: Data([1]),
            status: .active,
            reminderDate: .now.addingTimeInterval(86_400)
        )
        let resolutionDate = Date(timeIntervalSince1970: 1_000)

        item.markResolved(at: resolutionDate)

        XCTAssertEqual(item.status, .resolved)
        XCTAssertEqual(item.resolvedAt, resolutionDate)
        XCTAssertNil(item.reminderDate)
    }

    func testReopeningClearsResolutionDate() {
        let item = ScreenshotItem(
            imageData: Data([1]),
            status: .resolved,
            resolvedAt: Date(timeIntervalSince1970: 1_000)
        )

        item.markActive(at: Date(timeIntervalSince1970: 2_000))

        XCTAssertEqual(item.status, .active)
        XCTAssertNil(item.resolvedAt)
    }

    func testArchivingClearsReminder() {
        let item = ScreenshotItem(
            imageData: Data([1]),
            reminderDate: .now.addingTimeInterval(86_400)
        )

        item.archive()

        XCTAssertEqual(item.status, .archived)
        XCTAssertNil(item.reminderDate)
    }

    func testSavingReminderPersistsDateAndProvidesConfirmation() async throws {
        let container = try ScreenStashContainer.make(inMemory: true)
        let context = ModelContext(container)
        let item = ScreenshotItem(imageData: Data([1]), title: "Call the venue")
        context.insert(item)
        try context.save()

        let scheduler = ReminderSchedulerSpy()
        let viewModel = ScreenshotDetailViewModel(item: item)
        let reminderDate = Date.now.addingTimeInterval(3_600)
        viewModel.reminderDraft = reminderDate

        await viewModel.saveReminder(
            for: item,
            context: context,
            notifications: scheduler
        )

        XCTAssertEqual(item.reminderDate, reminderDate)
        XCTAssertEqual(viewModel.reminderConfirmationMessage, "Reminder saved")
        let scheduled = await scheduler.scheduledReminder()
        XCTAssertEqual(scheduled?.itemID, item.id)
        XCTAssertEqual(scheduled?.date, reminderDate)
    }

    func testRemovingReminderClearsDateAndCancelsNotification() async throws {
        let reminderDate = Date.now.addingTimeInterval(3_600)
        let container = try ScreenStashContainer.make(inMemory: true)
        let context = ModelContext(container)
        let item = ScreenshotItem(
            imageData: Data([1]),
            reminderDate: reminderDate
        )
        context.insert(item)
        try context.save()

        let scheduler = ReminderSchedulerSpy()
        let viewModel = ScreenshotDetailViewModel(item: item)

        await viewModel.removeReminder(
            for: item,
            context: context,
            notifications: scheduler
        )

        XCTAssertNil(item.reminderDate)
        XCTAssertEqual(viewModel.reminderConfirmationMessage, "Reminder removed")
        let cancelledID = await scheduler.cancelledItemID()
        XCTAssertEqual(cancelledID, item.id)
    }

    func testInboxDeletesEverySelectedScreenshotAndCancelsReminders() async throws {
        let container = try ScreenStashContainer.make(inMemory: true)
        let context = ModelContext(container)
        let first = ScreenshotItem(
            imageData: Data([1]),
            reminderDate: .now.addingTimeInterval(3_600)
        )
        let second = ScreenshotItem(
            imageData: Data([2]),
            reminderDate: .now.addingTimeInterval(7_200)
        )
        let unselected = ScreenshotItem(imageData: Data([3]))
        [first, second, unselected].forEach(context.insert)
        try context.save()

        let scheduler = ReminderSchedulerSpy()
        let viewModel = InboxViewModel()
        viewModel.beginSelecting()
        viewModel.toggleSelection(for: first)
        viewModel.toggleSelection(for: second)

        await viewModel.deleteSelected(
            in: [first, second, unselected],
            context: context,
            notifications: scheduler
        )

        let remaining = try context.fetch(FetchDescriptor<ScreenshotItem>())
        XCTAssertEqual(remaining.map(\.id), [unselected.id])
        let cancelledIDs = await scheduler.cancelledItemIDs()
        XCTAssertEqual(cancelledIDs, Set([first.id, second.id]))
        XCTAssertFalse(viewModel.isSelecting)
        XCTAssertTrue(viewModel.selectedIDs.isEmpty)
    }

    func testQuickInboxReminderSchedulesAndPersistsDate() async throws {
        let container = try ScreenStashContainer.make(inMemory: true)
        let context = ModelContext(container)
        let item = ScreenshotItem(imageData: Data([1]), title: "Book flights")
        context.insert(item)
        try context.save()

        let scheduler = ReminderSchedulerSpy()
        let viewModel = InboxViewModel()
        let reminderDate = Date.now.addingTimeInterval(86_400)

        let didSave = await viewModel.setReminder(
            for: item,
            at: reminderDate,
            context: context,
            notifications: scheduler
        )

        XCTAssertTrue(didSave)
        XCTAssertEqual(item.reminderDate, reminderDate)
        let scheduled = await scheduler.scheduledReminder()
        XCTAssertEqual(scheduled?.itemID, item.id)
        XCTAssertEqual(scheduled?.title, "Book flights")
    }

    func testQuickInboxResolveClearsReminderAndCancelsNotification() async throws {
        let container = try ScreenStashContainer.make(inMemory: true)
        let context = ModelContext(container)
        let item = ScreenshotItem(
            imageData: Data([1]),
            reminderDate: Date.now.addingTimeInterval(86_400)
        )
        context.insert(item)
        try context.save()

        let scheduler = ReminderSchedulerSpy()
        let viewModel = InboxViewModel()
        await viewModel.resolve(item, context: context, notifications: scheduler)

        XCTAssertEqual(item.status, .resolved)
        XCTAssertNil(item.reminderDate)
        let cancelledID = await scheduler.cancelledItemID()
        XCTAssertEqual(cancelledID, item.id)
    }

    func testQuickInboxDeleteRemovesItemAndCancelsNotification() async throws {
        let container = try ScreenStashContainer.make(inMemory: true)
        let context = ModelContext(container)
        let item = ScreenshotItem(
            imageData: Data([1]),
            reminderDate: Date.now.addingTimeInterval(86_400)
        )
        context.insert(item)
        try context.save()

        let scheduler = ReminderSchedulerSpy()
        let viewModel = InboxViewModel()
        await viewModel.delete(item, context: context, notifications: scheduler)

        let remainingItems = try context.fetch(FetchDescriptor<ScreenshotItem>())
        XCTAssertTrue(remainingItems.isEmpty)
        let cancelledID = await scheduler.cancelledItemID()
        XCTAssertEqual(cancelledID, item.id)
    }
}

private actor ReminderSchedulerSpy: NotificationScheduling {
    struct ScheduledReminder: Sendable {
        let itemID: UUID
        let title: String
        let date: Date
    }

    private var scheduled: ScheduledReminder?
    private var cancelledIDs: Set<UUID> = []

    func authorizationStatus() async -> UNAuthorizationStatus { .authorized }

    func scheduleReminder(for itemID: UUID, title: String, at date: Date) async throws {
        scheduled = ScheduledReminder(itemID: itemID, title: title, date: date)
    }

    func cancelReminder(for itemID: UUID) async {
        cancelledIDs.insert(itemID)
    }

    func cancelAllReminders() async {
        scheduled = nil
        cancelledIDs.removeAll()
    }

    func scheduledReminder() -> ScheduledReminder? { scheduled }
    func cancelledItemID() -> UUID? { cancelledIDs.first }
    func cancelledItemIDs() -> Set<UUID> { cancelledIDs }
}
