# AI Phone Controller

Offline-first Android assistant starter: Flutter chat UI + Kotlin Android bridge.

## Implemented in this repository

- Dark Flutter chat interface.
- Text commands for launching Chrome, YouTube, Android Settings, Maps, and Calculator.
- A confirmation dialog appears before every app launch.
- Kotlin MethodChannel validates each requested package against a fixed allow-list.
- Accessibility status check and shortcut to Android Accessibility settings.
- Optional Accessibility Service logs foreground app/package changes only.

## Not implemented yet

- A local language model / natural-language reasoning.
- Voice input.
- General-purpose UI-tree reading, tapping, scrolling, or multi-step automation.
- Background scheduling or unattended actions.

These are separate milestones and must be implemented and tested on the target Android device. The current command parser is a small offline rule-based parser, not an AI model.

## Build setup

This repository contains the Flutter source and custom Android integration files. A Flutter Android Gradle scaffold and wrapper are not yet included. Install Flutter and Android Studio, then generate a clean Android scaffold in a temporary Flutter project:

```bash
flutter create --platforms=android --org com.example phone_controller_build
```

Copy the generated `android/` build infrastructure into this repository, then merge (do not blindly overwrite) the custom files here:
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/kotlin/com/example/aiphonecontroller/MainActivity.kt`
- `android/app/src/main/kotlin/com/example/aiphonecontroller/AiAccessibilityService.kt`
- `android/app/src/main/res/xml/ai_accessibility_service_config.xml`
- `android/app/src/main/res/values/strings.xml`

Set Android `namespace` and `applicationId` to `com.example.aiphonecontroller`. Then run:

```bash
flutter pub get
flutter analyze
flutter run
```

## Try these commands

- `open Chrome`
- `open YouTube`
- `open Settings`
- `open Maps`
- `open Calculator`
- `help`

The target app must be installed. Android device vendors may use different package names for some apps.

## Accessibility and privacy

The service is optional and must be enabled by the device owner in Android Settings. It currently observes only window-state changes and logs the foreground package name. It does not take screenshots, read typed text, collect credentials, or click controls. App launches are initiated by the user in the chat and require an explicit confirmation.

Any future accessibility actions must remain visible, user-initiated, restricted to supported accessible controls, and must respect Android's secure-window and permission boundaries.

## Roadmap

1. Generate the Android build scaffold and run on a physical phone.
2. Verify app launch and accessibility status on the target device.
3. Add opt-in voice input with clear microphone disclosure.
4. Evaluate a compact on-device model and integrate only after checking Android 15 / 8 GB RAM compatibility.
5. Add limited accessibility interactions with per-action confirmation and tests.