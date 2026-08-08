import SwiftUI

struct ReminderIndicator: View {
    let date: Date

    var body: some View {
        Label {
            Text(date, format: .dateTime.month(.abbreviated).day().hour().minute())
        } icon: {
            Image(systemName: "bell.fill")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityLabel("Reminder set for \(date.formatted(date: .long, time: .shortened))")
    }
}

