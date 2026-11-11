# AI Phone Controller

An offline-first Android assistant starter using Flutter for the chat UI and Kotlin for Android integration.

## Included now

- Dark Flutter chat interface with text-only commands.
- Explicit confirmation before launching an app.
- Allow-listed app launching for Chrome, YouTube, Android Settings, Maps, and Calculator.
- Kotlin MethodChannel bridge with a second allow-list check on Android.
- Optional Accessibility Service that can inspect visible accessibility nodes and request confirmed taps on clickable elements.
- Back navigation through Android Accessibility.
- No screenshots, voice-command feature, or screen-text collection.
- Flutter widget smoke test.
- GitHub Actions workflow that generates the Android Gradle scaffold, runs analysis and tests, builds a debug APK, and uploads the APK as an artifact.

## Current command support

- `help`
- `open Chrome`
- `open YouTube`
- `open Settings`
- `open Maps`
- `open Calculator`
- `read screen` (after enabling the Accessibility Service)
- `back` (after enabling the Accessibility Service)

The parser is intentionally rule-based at this stage. A local language model and general-purpose multi-step automation are not yet included. Screen inspection only sees controls exposed by the current app through Android Accessibility; some apps may expose limited information.

## Generate Android build files locally

Requirements: Flutter stable SDK, Android Studio / Android SDK, Java 17.

From the repository root:

```bash
bash tool/prepare_android.sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

The script generates a clean Flutter Android Gradle project and overlays the repository's native Kotlin/manifest integration. It can be rerun if the generated Android build files are damaged.

Debug APK output:

```
build/app/outputs/flutter-apk/app-debug.apk
```

## GitHub Actions build

Every push to `main` and pull request targeting `main` triggers `.github/workflows/android-debug.yml`.

When the workflow succeeds, open the repository's **Actions** tab, select the latest **Android debug build** run, and download the `ai-phone-controller-debug-apk` artifact.

## Android package identity

- Application ID / namespace: `com.example.aiphonecontroller`
- Main activity: `com.example.aiphonecontroller.MainActivity`

## Accessibility and privacy

The optional service must be enabled manually by the device owner in Android Settings. It reads the current accessibility tree only when requested in the app. It does not capture screenshots. Taps are offered only for elements marked clickable and require a separate confirmation. Accessibility information varies by app; password and protected fields may not be exposed.

## Not complete yet

- On-device AI model / natural-language reasoning.
- Accessible UI-tree inspection and controlled actions.
- Multi-step app workflows.
- Physical-device validation on Android 15.

These are not represented as completed features. The first target is a reproducible debug build and passing automated checks.