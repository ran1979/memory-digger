#!/usr/bin/env bash
# Play Memory Digger locally in a desktop window.
source "$(dirname "$0")/godot_path.sh"
exec "$GODOT" --path "$ROOT" "$@"
