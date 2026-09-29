#!/usr/bin/env bash
# Run headless tests. Exits non-zero unless the test script prints OK
# (Godot exits 0 on script errors; --quit-after exits if a failed assert skips quit()).
source "$(dirname "$0")/godot_path.sh"
"$GODOT" --headless --path "$ROOT" -s tests/test_level.gd --quit-after 3000 </dev/null 2>&1 | tee /dev/stderr | grep -x OK >/dev/null  # not -q: early exit would SIGPIPE tee under pipefail
