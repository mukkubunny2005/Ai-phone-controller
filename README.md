# AI Phone Controller

Flutter + Kotlin Android assistant for user-confirmed, offline-first phone automation.

## Current features

- Futuristic dark Flutter chat interface with typed commands and an optional microphone button.
- On-device speech recognition only when the user taps the microphone. It requires Android 12+ and an installed on-device speech recognition service/language pack; otherwise typed commands remain available.
- Offline natural-language planning using LiteRT-LM and a local Qwen2.5 1.5B Instruct model. No model API key is required because inference runs locally.
- Opens installed Android apps by their displayed app name.
- Reads the foreground app's accessible UI tree, never screenshots.
- Excludes password fields and common identifiable PIN, OTP and payment-detail fields.
- Can tap visible controls, enter text into eligible editable fields, scroll accessible containers, perform Back and Home actions, and open selected Android settings pages.
- Settings navigation opens the selected system page; it does not silently toggle device settings.
- Multi-step deterministic workflows with a maximum of 8 steps, plus AI-planned workflows with a maximum of 8 actions.
- Every app launch, tap, text entry, scroll, Back, Home or settings navigation action requires user confirmation. The user can cancel a workflow.
- YouTube content-protection monitor: while YouTube is foregrounded and Accessibility is enabled, it checks accessible text/labels for a limited set of potentially inappropriate-content text signals. On a match, it displays a warning and attempts to return Home.
- Screen text and AI prompts are processed on-device; the service does not capture screenshots or send screen text to a server.

## Important limits

- The YouTube protection feature cannot inspect video frames or images because screenshots are not used. It can miss inappropriate material when titles/captions/labels are not exposed by YouTube, and text matching can produce false positives.
- Android does not let an ordinary third-party app reliably force-stop another app or guarantee removal of that app from Recents. The protection feature returns Home; it does not promise to remove YouTube from Recents or stop every background playback mode.
- Accessibility can only act on controls exposed by the foreground app. Some apps expose limited UI information or block programmatic text entry.
- Some secure screens and sensitive fields are intentionally excluded. The app does not enter passwords, OTPs or payment credentials.
- Voice input depends on Android's on-device speech recognition service. If the phone has no offline speech service/language pack, use text input.
- The model is about 1.6 GB and uses additional RAM when loaded. Device performance and memory use must be tested on the target phone.
- This is not a security certification. Real-device dynamic testing remains necessary.

## Commands

```text
help
open Chrome
open WhatsApp
read screen
scroll down
scroll up
back
home
settings wifi
settings bluetooth
settings display
settings sound
settings location
settings battery
tap 4
enter 4 hello there
```

Join up to 8 steps with `then` or semicolons, for example:

```text
open Chrome then read screen
open Settings then settings wifi
open Chrome; read screen; scroll down
```

For natural-language tasks, download and load the offline model using the brain icon. The planner proposes one action at a time, validates it against the current accessible UI and installed-app list, and asks for confirmation before the action.

## Offline model

- Runtime: LiteRT-LM Android Kotlin API (version 0.18.0).
- Model: Qwen2.5-1.5B-Instruct, quantized LiteRT-LM build (about 1.6 GB).
- Model license: Apache-2.0.
- Model source: https://huggingface.co/litert-community/Qwen2.5-1.5B-Instruct
- Download is restricted to Wi-Fi by Android DownloadManager and starts only after user confirmation.
- Model weights are stored outside the APK in app-private storage. The downloaded file is checked against its published SHA-256 before the runtime loads it.
- After download, inference runs on-device. No API key or cloud inference endpoint is used.

## Build locally

Requirements: Flutter stable SDK, Android SDK / Android Studio, Java 17.

```bash
bash tool/prepare_android.sh
flutter pub get
flutter analyze --fatal-infos --fatal-warnings
flutter test
flutter build apk --debug
```

APK output:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

The preparation script generates the Android Gradle scaffold and copies the reviewed Kotlin service, bridge, model runtime, manifest, disclosure strings and Accessibility configuration from `tool/android_overlay`. Edit the overlay sources for durable Android changes.

## First launch

1. Install the debug APK.
2. Open Accessibility settings and explicitly enable AI Phone Controller after reviewing the disclosure.
3. Open the offline AI model panel.
4. Confirm the Wi-Fi-only model download (about 1.6 GB).
5. After download completes, load the model.
6. Enter a typed command or tap the microphone for on-device speech input if supported.
7. Review and confirm every proposed phone action.

The app's Accessibility service must remain enabled for automation and YouTube text-signal protection. Microphone permission is requested only when the microphone button is tapped.
