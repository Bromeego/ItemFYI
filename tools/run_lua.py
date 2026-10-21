#!/usr/bin/env python3
"""Small test runner using the system Lua shared library when no Lua CLI exists."""

from __future__ import annotations

import ctypes
import ctypes.util
import sys
from pathlib import Path


# WoW runs Lua 5.1. Prefer it so local runs reject the same syntax CI does.
def load_lua() -> ctypes.CDLL:
    candidates = [
        ctypes.util.find_library("lua5.1"),
        "liblua5.1.so.0",
        ctypes.util.find_library("lua5.4"),
        ctypes.util.find_library("lua5.3"),
        "liblua5.4.so.0",
        "liblua5.3.so.0",
    ]
    for candidate in candidates:
        if not candidate:
            continue
        try:
            return ctypes.CDLL(candidate)
        except OSError:
            continue
    raise RuntimeError("No Lua shared library was found")


lua = load_lua()
# Lua 5.1 exports luaL_loadfile and lua_pcall; 5.2+ exports only the
# extended luaL_loadfilex and lua_pcallk, with the old names as macros.
IS_LUA51 = hasattr(lua, "lua_pcall") and not hasattr(lua, "lua_pcallk")
lua.luaL_newstate.restype = ctypes.c_void_p
lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
if IS_LUA51:
    lua.luaL_loadfile.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
    lua.luaL_loadfile.restype = ctypes.c_int
    lua.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
    lua.lua_pcall.restype = ctypes.c_int
else:
    lua.luaL_loadfilex.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p]
    lua.luaL_loadfilex.restype = ctypes.c_int
    lua.lua_pcallk.argtypes = [
        ctypes.c_void_p,
        ctypes.c_int,
        ctypes.c_int,
        ctypes.c_int,
        ctypes.c_longlong,
        ctypes.c_void_p,
    ]
    lua.lua_pcallk.restype = ctypes.c_int
lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
lua.lua_tolstring.restype = ctypes.c_char_p
lua.lua_close.argtypes = [ctypes.c_void_p]


def error_message(state: int) -> str:
    size = ctypes.c_size_t()
    value = lua.lua_tolstring(state, -1, ctypes.byref(size))
    if not value:
        return "unknown Lua error"
    return value[: size.value].decode("utf-8", errors="replace")


def run_file(path: Path, execute: bool) -> None:
    state = lua.luaL_newstate()
    if not state:
        raise RuntimeError("Could not create Lua state")
    try:
        lua.luaL_openlibs(state)
        encoded = str(path).encode()
        if IS_LUA51:
            status = lua.luaL_loadfile(state, encoded)
        else:
            status = lua.luaL_loadfilex(state, encoded, None)
        if status != 0:
            raise RuntimeError(f"{path}: {error_message(state)}")
        if execute:
            if IS_LUA51:
                status = lua.lua_pcall(state, 0, 0, 0)
            else:
                status = lua.lua_pcallk(state, 0, 0, 0, 0, None)
            if status != 0:
                raise RuntimeError(f"{path}: {error_message(state)}")
    finally:
        lua.lua_close(state)


def main() -> int:
    arguments = sys.argv[1:]
    execute = True
    if arguments and arguments[0] == "--syntax":
        execute = False
        arguments = arguments[1:]
    if not IS_LUA51:
        print(
            "warning: Lua 5.1 was not found; checking with a newer Lua, which "
            "accepts some syntax WoW rejects. CI uses Lua 5.1.",
            file=sys.stderr,
        )
    for argument in arguments:
        run_file(Path(argument), execute)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(exc, file=sys.stderr)
        raise SystemExit(1)
