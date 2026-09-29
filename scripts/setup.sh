#!/usr/bin/env bash
# One-time macOS toolchain install (Homebrew). Desktop play/tests only need Godot;
# JDK 17 + Android SDK + export templates are for Android builds (./scripts/android.sh).
set -euo pipefail
brew install --cask godot android-commandlinetools
brew install openjdk@17
yes | sdkmanager --sdk_root=/opt/homebrew/share/android-commandlinetools \
  "platform-tools" "platforms;android-34" "build-tools;34.0.0" >/dev/null

# Godot export templates (~1.3 GB), matched to the installed Godot version.
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
VER="$("$GODOT_BIN" --version | cut -d. -f1-3)"          # e.g. 4.7.2
DIR="$HOME/Library/Application Support/Godot/export_templates/$VER.stable"
if [[ ! -f "$DIR/android_debug.apk" ]]; then
  TMP="$(mktemp -d)"
  curl -fL -o "$TMP/t.tpz" "https://github.com/godotengine/godot/releases/download/$VER-stable/Godot_v$VER-stable_export_templates.tpz"
  unzip -q "$TMP/t.tpz" -d "$TMP" && mkdir -p "$DIR" && mv "$TMP"/templates/* "$DIR"/ && rm -rf "$TMP"
fi
echo "Done. Play: ./scripts/run.sh   Test: ./scripts/test.sh   Phone: ./scripts/android.sh"
