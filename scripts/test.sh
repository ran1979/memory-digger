#!/usr/bin/env bash
# Run headless tests. Exits non-zero unless the test script prints OK
# (Godot exits 0 on script errors; </dev/null stops a failed assert hanging in the debugger).
source "$(dirname "$0")/godot_path.sh"
"$GODOT" --headless --path "$ROOT" -s tests/test_level.gd </dev/null 2>&1 | tee /dev/stderr | grep -qx OK
