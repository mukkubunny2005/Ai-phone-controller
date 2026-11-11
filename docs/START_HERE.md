# AI Phone Controller

An offline-first Android assistant built with Flutter and a Kotlin Accessibility Service.

## Project direction

- Flutter chat interface with a dark, minimal assistant experience.
- Kotlin Android bridge through a MethodChannel.
- Accessibility-based interaction with UI elements that Android exposes to the service.
- Text commands first; voice input can be added as a separate feature.
- Local, pretrained text model integration is a later milestone.

## Safety and platform boundaries

The app must request Accessibility access explicitly and explain what it can do. It should only interact with supported, user-visible UI elements, respect Android permission prompts and secure-screen restrictions, and never attempt hidden surveillance, credential collection, or permission bypasses. Ask for confirmation before consequential actions.

## Development milestones

1. Build and run the Flutter chat UI.
2. Add the Kotlin MethodChannel bridge.
3. Add an opt-in Accessibility Service and verify that it can detect the foreground package.
4. Add a small allow-listed set of accessible UI actions with user confirmation.
5. Integrate a compact local text model after measuring memory and latency on the target phone.
6. Add voice input and reliability tests.

## Getting started

Install Flutter and Android Studio, then create the Android platform scaffold:

```bash
flutter create . --platforms=android --org com.example
flutter pub get
flutter run
```

Keep the Android package/application ID aligned with the Kotlin package used by the bridge. Review generated Android Gradle files for your installed Flutter version rather than copying version-specific build files from another project.

## Current status

This repository is being bootstrapped. Features should be marked complete only after they have been implemented and tested on a physical Android device.
