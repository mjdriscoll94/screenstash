import Foundation

enum AgingBucket: Int, CaseIterable, Identifiable {
    case thirtyDays = 30
    case sixtyDays = 60
    case ninetyDays = 90

    var id: Int { rawValue }
    var title: String { "\(rawValue)+ days" }
}

enum AgingCalculator {
    static func daysOld(
        createdAt: Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        max(calendar.dateComponents([.day], from: createdAt, to: now).day ?? 0, 0)
    }

    static func bucket(
        for createdAt: Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> AgingBucket? {
        let days = daysOld(createdAt: createdAt, now: now, calendar: calendar)
        if days >= 90 { return .ninetyDays }
        if days >= 60 { return .sixtyDays }
        if days >= 30 { return .thirtyDays }
        return nil
    }

    static func needsReview(
        item: ScreenshotItem,
        thresholdDays: Int,
        now: Date = .now
    ) -> Bool {
        guard item.isUnresolved else { return false }
        let referenceDate = max(item.createdAt, item.lastReviewedAt ?? item.createdAt)
        return daysOld(createdAt: referenceDate, now: now) >= thresholdDays
    }
}

