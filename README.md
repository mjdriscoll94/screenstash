# ScreenStash

ScreenStash is a private, local-first iPhone inbox for screenshots. It imports only images the user selects, recognizes English text on-device, and helps turn screenshots into searchable, actionable items.

## Requirements

- A stable Xcode 26 release or later (required for current App Store uploads)
- iOS 17 or later
- XcodeGen when regenerating the project from `project.yml`

The checked-in `ScreenStash.xcodeproj` can be opened directly, so XcodeGen is not required for ordinary development.

## Running the app

1. Open `ScreenStash.xcodeproj`.
2. Select the ScreenStash scheme and an iPhone simulator or device.
3. Choose a development team and update the bundle identifier when installing on a physical device.
4. Build and run.

No account, backend, API key, subscription, or third-party dependency is required.

## Share extension

ScreenStash includes a Share Extension for the screenshot share sheet. A user can choose ScreenStash, assign a built-in category, and save without first opening the app. The extension places the selected image in an App Group staging queue; the main app then performs compression and Vision OCR when it next becomes active.

Both targets use the App Group `group.com.screenstash.shared`. Before running on a physical device or distributing the app:

1. Register this App Group—or replace it with your own identifier—in the Apple Developer portal.
2. Enable the same App Group for the ScreenStash app and ScreenStashShareExtension identifiers.
3. Keep the identifier synchronized in both entitlement files and `ScreenStashAppGroup.identifier`.

Staging avoids performing memory-intensive OCR inside the system extension process and makes imports retryable and idempotent.

## Architecture

- SwiftUI views are organized by feature.
- Observable view models own presentation and workflow state.
- SwiftData stores screenshot metadata and processed image data locally.
- Image processing, Vision OCR, notification scheduling, category suggestion, and export are isolated behind reusable services.
- Dependencies enter the SwiftUI environment through `AppDependencies`.

## Privacy

- Import uses `PhotosPicker`; the app does not scan the photo library.
- Screenshots and metadata remain in the app's local SwiftData store.
- Vision OCR runs on-device.
- No analytics, advertising, tracking, accounts, or uploads are included.
- The privacy manifest declares no collected data or tracking. It declares the app-scoped UserDefaults reason used for preferences.

The `docs` directory contains a support page and a ScreenStash-specific privacy policy ready for free hosting with GitHub Pages. After publishing, use the site root as the App Store Connect Support URL and `/privacy.html` as the Privacy Policy URL.

## Export format

The first release exports a `.screenstash` folder package instead of a ZIP archive. It contains:

- `metadata.json`
- `images/<screenshot-id>.jpg`
- `ocr/<screenshot-id>.txt`

This keeps export dependency-free while retaining images, OCR, titles, notes, categories, dates, statuses, favorites, reminders, and cleanup-review metadata.

## Development sample data

Fake sample screenshots are compiled only in Debug builds. Launch with:

- `-seed-sample-data` to seed records when the store is empty
- `-reset-data` to clear screenshot records before seeding
- `-skip-onboarding` to bypass onboarding

The UI-test target supplies these arguments automatically.

## Tests

The unit suite covers category suggestions, OCR failures, search filtering, aging calculations, reminder identifiers, status transitions, image processing, export contents, SwiftData persistence, and shared-import queue ingestion.

The UI suite covers opening Inbox, entering import, searching OCR text, opening detail, and resolving a screenshot.

Run all tests with the ScreenStash scheme in Xcode.

## Release checklist

- Set the final bundle identifier and Apple Developer team.
- Confirm version and build numbers.
- Test importing and notification authorization on a physical iPhone.
- Test large screenshot batches under realistic memory pressure.
- Publish the pages in `docs` and enter their Support and Privacy Policy URLs in App Store Connect.
- Archive and validate the signed Release build in Xcode Organizer.
