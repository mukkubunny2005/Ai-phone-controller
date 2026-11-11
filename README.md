# AI Phone Controller

Flutter + Kotlin Android app for user-confirmed, accessibility-based phone control.

## Implemented

- Dark Flutter chat interface with text-only commands (no voice feature).
- Launches Chrome, YouTube, Android Settings, Maps and Calculator through a package allow-list.
- Optional Android Accessibility Service reads the active window's accessibility tree on request.
- Password nodes are excluded from returned screen elements.
- User can select a visible clickable control to tap, or an editable non-password field to enter text.
- Back navigation.
- Multi-step command workflows with a maximum of 8 steps.
- Each app launch, tap, text entry and Back action requires its own confirmation.
- Workflow stops if a step is cancelled or fails; a Stop button requests cancellation.
- No screenshots, root access, hidden background tapping, voice commands, or automatic form submission.
- Android 15 target can be built from the generated Flutter Android scaffold.

## Commands

Single steps:

- `help`
- `open Chrome`, `open YouTube`, `open Settings`, `open Maps`, `open Calculator`
- `read screen`
- `back`
- `tap 4` (use an index shown by the latest Read Screen result)
- `enter 4 hello there` (use an editable field index shown by Read Screen)

Multi-step workflows use `then` or semicolons:

```text
open Chrome then read screen
open Settings then read screen then back
open Chrome; read screen; tap 4
open Chrome then read screen then enter 7 example search
```

The app validates every step before starting. Maximum 8 steps. Every action that changes the phone requires a separate confirmation. Screen element indices can become stale if the app changes; run Read Screen again before using them. The automation is deterministic and rule-based; a local AI model / general natural-language reasoning is not integrated yet.

## Build locally

Requirements: Flutter stable SDK, Android SDK / Android Studio, Java 17.

```bash
bash tool/prepare_android.sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

APK output:

```
build/app/outputs/flutter-apk/app-debug.apk
```

The preparation script generates Android Gradle files and overlays the Kotlin service, manifest and accessibility configuration from `tool/android_overlay`.

## Enable Accessibility

Install the APK, open AI Phone Controller, tap the Accessibility icon and enable the service in Android Settings. The service only inspects the active accessibility tree when the app requests it. Some apps do not expose all UI elements through Accessibility.

## Limitations

- No offline LLM yet; commands are a fixed supported grammar.
- UI automation is limited to the foreground accessibility tree and supported actions.
- Some apps expose limited accessibility nodes or block programmatic text entry.
- Physical-device validation remains necessary. Android behavior and vendor restrictions vary.
