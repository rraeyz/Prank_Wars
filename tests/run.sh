#!/usr/bin/env bash
# Runs all headless tests. Fails on test failures or any script error in the log.
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
LOG=$(mktemp)
timeout 600 "$GODOT" --headless --path . --fixed-fps 60 -s res://tests/run_tests.gd -- "$@" 2>&1 | tee "$LOG"
code=${PIPESTATUS[0]}
if grep -E "SCRIPT ERROR|Parse Error|Invalid call|Invalid access|Invalid assignment|Nonexistent function" "$LOG" >/dev/null; then
  echo "!! script errors found in log"; code=1
fi
rm -f "$LOG"
exit $code
