#!/usr/bin/env bash
# Build a debug APK and (unless --build-only) install + launch it on a USB-connected device.
#   ./scripts/android.sh              build, install, launch
#   ./scripts/android.sh --build-only just build build/diamond-dash-debug.apk
# Needs: ./scripts/setup.sh done, Godot Android export templates installed, phone with USB debugging.
source "$(dirname "$0")/godot_path.sh"
PACKAGE=com.ran1979.memorydigger
APK="$ROOT/build/diamond-dash-debug.apk"

export ANDROID_HOME="${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}"
# Godot's Android export needs JDK 17 (newer JDKs are not supported).
export JAVA_HOME="${MD_JAVA_HOME:-/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home}"
ADB="$ANDROID_HOME/platform-tools/adb"

# Godot reads SDK/JDK paths only from its editor settings; point them at our toolchain.
# (Godot creates and uses its own debug keystore automatically.)
SETTINGS="$HOME/Library/Application Support/Godot/editor_settings-4.${GODOT_MINOR:-7}.tres"
if [[ -f "$SETTINGS" ]]; then
  sed -i '' -E \
    -e "s|^export/android/android_sdk_path = .*|export/android/android_sdk_path = \"$ANDROID_HOME\"|" \
    -e "s|^export/android/java_sdk_path = .*|export/android/java_sdk_path = \"$JAVA_HOME\"|" \
    "$SETTINGS"
fi

mkdir -p "$ROOT/build"
rm -f "$APK"
"$GODOT" --headless --path "$ROOT" --export-debug Android "$APK"
[[ -f "$APK" ]] || { echo "Export failed (see output above)." >&2; exit 1; }
echo "Built $APK"

[[ "${1:-}" == "--build-only" ]] && exit 0
if ! "$ADB" devices | grep -qw device$; then
  echo "No device found. Connect phone with USB debugging on, then check: $ADB devices" >&2
  exit 1
fi
"$ADB" install -r "$APK"
"$ADB" shell monkey -p "$PACKAGE" -c android.intent.category.LAUNCHER 1 >/dev/null
echo "Launched Diamond Dash on device."
