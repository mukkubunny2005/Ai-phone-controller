# AI Phone Controller

Flutter + Kotlin Android assistant for on-device, user-confirmed phone automation.

## Implemented

- Dark Flutter chat interface with text-only interaction (no voice commands).
- Opens installed Android apps by their displayed app name.
- Android Accessibility Service reads the active window's accessible UI tree only when requested.
- Password fields are excluded from the accessible element list.
- Can tap visible clickable controls, enter text into editable non-password fields, and perform Back navigation.
- Multi-step deterministic workflows with a maximum of 8 steps.
- Offline natural-language planning using LiteRT-LM and a local Qwen2.5 1.5B Instruct model.
- Model download is started only after the user confirms; it is Wi-Fi-only and about 1.6 GB.
- Model weights are stored in app-private device storage, not bundled into the APK. After download, inference runs on-device without sending prompts or screen text to a server.
- The AI planner reads the current accessibility tree, proposes one action at a time, validates app names and element indices, and requires confirmation before each app launch, tap, text entry, or Back action.
- Confirmations appear in a small Accessibility overlay above the active app, so multi-step tasks can continue while another app is open. The overlay blocks background touches until Confirm or Cancel is chosen.
- User can cancel an AI task or multi-step workflow.
- No screenshots, root access, voice commands, hidden tapping, or automatic form submission.
- Android minimum SDK 24; Android 15 target is supported by the generated Flutter scaffold.

## Commands

Examples:

```text
help
open Chrome
open WhatsApp
read screen
back
tap 4
enter 4 hello there
```

Multi-step workflows:

```text
open Chrome then read screen
open Settings then read screen then back
open Chrome; read screen; tap 4
```

For ordinary-language requests, download and load the offline model using the brain icon in the app bar. The planner can only act on controls exposed by the foreground app's Accessibility tree. It validates each proposed action and asks for confirmation before changing the phone.

## Offline model

- Runtime: LiteRT-LM Android Kotlin API (version 0.18.0).
- Model: Qwen2.5-1.5B-Instruct, quantized LiteRT-LM build (about 1.6 GB).
- Model license: Apache-2.0.
- Model source: https://huggingface.co/litert-community/Qwen2.5-1.5B-Instruct
- Download is restricted to Wi-Fi by Android DownloadManager. The model is downloaded after the user taps Download model and confirms the size.
- Model is stored outside the APK. The first load can take several seconds and uses device RAM.

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

```text
build/app/outputs/flutter-apk/app-debug.apk
```

The preparation script generates Android Gradle files and overlays the Kotlin Accessibility service, LiteRT-LM runtime, manifest, and configuration from `tool/android_overlay`.

## First launch

1. Install the APK.
2. Open the Accessibility settings button and enable AI Phone Controller.
3. Open the Offline AI model button.
4. Confirm the Wi-Fi-only model download (about 1.6 GB).
5. After the download completes, tap Load model.
6. Enter a natural-language phone task. Review and confirm every proposed action.

## Limitations

- The AI can only inspect elements exposed through Android Accessibility. Some apps expose limited UI information or block programmatic text entry.
- Screen indices are refreshed before each AI-planned action; manually entered numeric indices should be refreshed with Read Screen after the app changes.
- AI planning is limited to 8 actions per task and is not guaranteed to understand every app workflow.
- Some Android vendors may restrict background execution or Accessibility behavior.
- Physical-device validation remains necessary; app installation, model download, model loading, and device-specific performance must be checked on the target phone.
