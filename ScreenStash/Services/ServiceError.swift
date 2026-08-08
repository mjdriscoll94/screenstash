import Foundation

enum ScreenStashServiceError: LocalizedError, Equatable {
    case unreadableImage
    case imageEncodingFailed
    case textRecognitionFailed(String)
    case notificationPermissionDenied
    case reminderDateInPast
    case notificationSchedulingFailed(String)

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            "ScreenStash couldn't read this image."
        case .imageEncodingFailed:
            "ScreenStash couldn't prepare this image for storage."
        case .textRecognitionFailed:
            "Text recognition couldn't be completed."
        case .notificationPermissionDenied:
            "Notifications are disabled for ScreenStash."
        case .reminderDateInPast:
            "Choose a reminder time in the future."
        case .notificationSchedulingFailed:
            "The reminder couldn't be scheduled."
        }
    }

    var failureReason: String? {
        switch self {
        case let .textRecognitionFailed(reason), let .notificationSchedulingFailed(reason):
            reason
        default:
            nil
        }
    }
}

