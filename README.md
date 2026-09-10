# ItemFYI: Openables & Learnables

A lightweight World of Warcraft Retail addon that points out useful, actionable
items already sitting in your bags. It shows one secure button and never opens
or learns anything automatically.

It looks for uncollected mounts, pets, companion curios, toys, housing decor,
transmog tokens, recipes, profession knowledge, garrison items, reputation
tokens, and ordinary containers — one item at a time, with a `+N` count when
more are waiting.

## Usage

- Click the button to use the current item.
- Right-click skips it for this session.
- Ctrl-right-click permanently ignores it.
- Alt-drag moves the button, or place it in Blizzard Edit Mode.

Open **Options → AddOns → ItemFYI**, type `/ifyi`, or use the minimap Addon
Compartment to toggle categories, the attention glow, and button size.

## Installation

1. Extract the `ItemFYI` folder into `World of Warcraft/_retail_/Interface/AddOns/`
2. Restart WoW or type `/reload`.

## Commands

- `/ifyi` — open settings
- `/ifyi help` — show command help
- `/ifyi scan` — clear session skips and scan again
- `/ifyi list` — list currently detected actions
- `/ifyi skip` / `/ifyi ignore` — skip or permanently ignore the current item
- `/ifyi ignored` / `/ifyi unignore <key>` / `/ifyi clearignored` — manage the ignore list
- `/ifyi clearskips` — clear session skips
- `/ifyi reset` — reset the button position

## Notes

Retail only. ItemFYI does not scan the bank, auto-open items, or pick locks.
ElvUI and EllesmereUI skins are used when those addons are installed.

See [CHANGELOG.md](CHANGELOG.md) for release notes.
