#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

lua_bin=""
for candidate in lua5.1 lua luajit; do
    if command -v "$candidate" >/dev/null 2>&1; then
        lua_bin="$candidate"
        break
    fi
done

if [[ -n "$lua_bin" ]]; then
    for file in Core.lua Rules.lua Detection.lua UI.lua Settings.lua tests/test_rules.lua tests/test_detection.lua tests/test_load.lua; do
        "$lua_bin" -e "assert(loadfile('$file'))"
    done

    "$lua_bin" tests/test_rules.lua
    "$lua_bin" tests/test_detection.lua
    "$lua_bin" tests/test_load.lua
else
    python3 tools/run_lua.py --syntax Core.lua Rules.lua Detection.lua UI.lua Settings.lua tests/test_rules.lua tests/test_detection.lua tests/test_load.lua
    python3 tools/run_lua.py tests/test_rules.lua
    python3 tools/run_lua.py tests/test_detection.lua
    python3 tools/run_lua.py tests/test_load.lua
fi

if grep -R $'\r' --include='*.lua' --include='*.toc' . >/dev/null; then
    echo "CRLF characters detected." >&2
    exit 1
fi

echo "ItemFYI validation passed."
