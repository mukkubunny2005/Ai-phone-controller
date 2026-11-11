#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

command -v flutter >/dev/null 2>&1 || {
  echo "Flutter SDK was not found on PATH." >&2
  exit 1
}

flutter create --platforms=android --org com.example --project-name aiphonecontroller "$TEMP_DIR/scaffold"

rm -rf "$ROOT/android"
mkdir -p "$ROOT/android"
cp -R "$TEMP_DIR/scaffold/android/." "$ROOT/android/"

OVERLAY="$ROOT/tool/android_overlay/app/src/main"
DEST="$ROOT/android/app/src/main"
mkdir -p "$DEST"
cp "$OVERLAY/AndroidManifest.xml" "$DEST/AndroidManifest.xml"
mkdir -p "$DEST/kotlin/com/example/aiphonecontroller"
cp "$OVERLAY/kotlin/com/example/aiphonecontroller/"*.kt "$DEST/kotlin/com/example/aiphonecontroller/"
mkdir -p "$DEST/res/xml" "$DEST/res/values"
cp "$OVERLAY/res/xml/ai_accessibility_service_config.xml" "$DEST/res/xml/"
cp "$OVERLAY/res/values/strings.xml" "$DEST/res/values/"

APP_GRADLE="$ROOT/android/app/build.gradle.kts"
if ! grep -q 'litertlm-android' "$APP_GRADLE"; then
  cat >> "$APP_GRADLE" <<'GRADLE'

dependencies {
    implementation("com.google.ai.edge.litertlm:litertlm-android:0.18.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
}
GRADLE
fi
sed -i 's/minSdk = flutter.minSdkVersion/minSdk = 24/' "$APP_GRADLE"

echo "Android Gradle scaffold generated with Accessibility and offline LiteRT-LM integration."
