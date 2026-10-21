#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

python3 tools/release.py
python3 tests/test_release.py

lua_bin=""
for candidate in lua5.1 lua luajit; do
    if command -v "$candidate" >/dev/null 2>&1; then
        lua_bin="$candidate"
        break
    fi
done

source_files=(Core.lua Rules.lua Detection.lua Inventory.lua UI.lua Skinning.lua EditMode.lua Settings.lua EditModeExpanded-1.0/EditModeExpanded-1.0.lua)
test_files=(tests/test_rules.lua tests/test_detection.lua tests/test_skinning.lua tests/test_load.lua tests/test_inventory.lua)

if [[ -n "$lua_bin" ]]; then
    for file in "${source_files[@]}" "${test_files[@]}"; do
        "$lua_bin" -e "assert(loadfile('$file'))"
    done

    for file in "${test_files[@]}"; do
        "$lua_bin" "$file"
    done
else
    python3 tools/run_lua.py --syntax "${source_files[@]}" "${test_files[@]}"
    for file in "${test_files[@]}"; do
        python3 tools/run_lua.py "$file"
    done
fi

if grep -R $'\r' --include='*.lua' --include='*.toc' . >/dev/null; then
    echo "CRLF characters detected." >&2
    exit 1
fi

echo "ItemFYI validation passed."
