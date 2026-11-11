# AI Phone Controller

An offline-first Android assistant project using Flutter for the chat interface and Kotlin for Android integration.

## Current starter implementation

- Dark Flutter chat interface with text input.
- Flutter MethodChannel connected to a Kotlin Android activity.
- Accessibility-service status check.
- Optional Accessibility Service that only logs foreground app/package changes.
- No screenshots, screen-text extraction, taps, or model inference are implemented yet.

## Requirements

- Flutter SDK (stable)
- Android Studio / Android SDK
- Android device or emulator (Android 15 is the intended target)

## Create the Flutter Android scaffold

From the repository root, run:

```bash
flutter create . --platforms=android --org com.example
```

Then make sure the Android module's `namespace` and `applicationId` in `android/app/build.gradle` (or `build.gradle.kts`) are both:

```gradle
com.example.aiphonecontroller
```

Place the Kotlin files from this repository under:
`android/app/src/main/kotlin/com/example/aiphonecontroller/`

Keep the AndroidManifest.xml and accessibility XML/string resources from this repository when merging with the generated Flutter scaffold. Do not remove Flutter's generated embedding metadata or required activity configuration.

Install dependencies and run:

```bash
flutter pub get
flutter analyze
flutter run
```

## Enable the optional service

After installing the app, open Android Settings → Accessibility → Installed apps/services → AI Phone Controller, and enable it only if you want foreground-app detection. Android wording varies by device.

The service is deliberately limited to foreground package-change events. It does not inspect screen content or perform actions. Any future interaction feature must be transparent, user-initiated, limited to supported accessible controls, and respect Android security restrictions.

## Development roadmap

1. Run the Flutter UI on a physical device.
2. Verify the MethodChannel status check.
3. Verify opt-in foreground package detection.
4. Design a small, allow-listed interaction system with explicit confirmation.
5. Evaluate compact local text models on the target device before selecting one.
6. Add voice input and reliability tests.

## Important

This is a starter foundation, not a finished phone-control assistant. The repository does not yet include an on-device language model or automatic app-control actions. Mark milestones complete only after testing them on a real device.
