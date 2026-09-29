# Sourced by the other scripts. Resolves the Godot binary and imports the project once.
# Override with: GODOT=/path/to/godot ./scripts/run.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -z "${GODOT:-}" ]]; then
  if command -v godot >/dev/null 2>&1; then GODOT="$(command -v godot)"
  elif [[ -x /Applications/Godot.app/Contents/MacOS/Godot ]]; then GODOT=/Applications/Godot.app/Contents/MacOS/Godot
  else echo "Godot 4 not found. Run ./scripts/setup.sh or set GODOT=/path/to/godot" >&2; exit 1
  fi
fi
# Refresh .godot/ (class_name cache) so new/renamed classes resolve. Incremental, fast.
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
