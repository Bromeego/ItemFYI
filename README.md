# ItemFYI: Openables & Learnables

ItemFYI is a lightweight World of Warcraft Retail addon that points out useful,
actionable items already sitting in your bags. It shows one secure button and
never opens or learns anything automatically.

## MVP behaviour

- Scans all equipped bags at login and after bag changes.
- Shows one item at a time, with a small `+N` count when more are waiting.
- Prioritises uncollected mounts, pets, toys, housing decor, transmog tokens,
  and recipes before ordinary containers.
- Uses Blizzard collection APIs where available, tooltip signals for explicit
  learnable tokens, and a small exception list for known crest packs.
- Uses Blizzard's native secure item action with the exact bag and slot; it does
  not depend on generated macro text.
- Defers every protected-frame update until combat ends.
- Right-click skips an item for the session.
- Ctrl-right-click permanently ignores an item.
- Alt-drag moves the button.
- Registers the button with Blizzard Edit Mode, including per-layout positions.
- Adopts EllesmereUI or ElvUI button styling when either UI suite is installed.
- Provides a native Blizzard AddOns settings panel for category and button controls.

## Installation

1. Extract the `ItemFYI` folder into:
   `World of Warcraft/_retail_/Interface/AddOns/`
2. Restart WoW or type `/reload`.

## Commands

- `/ifyi` — open the ItemFYI settings panel.
- `/ifyi help` — show command help.
- `/ifyi scan` — clear session skips and scan again.
- `/ifyi list` — list all currently detected actions.
- `/ifyi skip` — skip the current item for this session.
- `/ifyi ignore` — permanently ignore the current item.
- `/ifyi unignore <key>` — restore an ignored item.
- `/ifyi clearignored` — clear the permanent ignore list.
- `/ifyi clearskips` — clear session skips.
- `/ifyi reset` — reset the button position.

## Settings

Open **Options → AddOns → ItemFYI** or type `/ifyi`. The panel can enable or
disable ItemFYI, toggle individual item categories, change the button size,
reset its position, clear skipped or ignored items, and rescan the bags.

Settings changed during combat are saved immediately. Any protected button
layout or item update is applied after combat ends.

The ItemFYI button also appears as a movable element in Blizzard Edit Mode,
even when there is no actionable item waiting. Edit Mode positions are stored
per Blizzard UI layout. Alt-drag remains available as a quick fallback.

## Version 0.1 limitations

- Retail only; English tooltip fallbacks are used where Blizzard provides no
  direct collection API.
- Equippable armour and weapons are deliberately excluded. Version 0.1 only
  surfaces transmog items with an explicit learn/use instruction.
- Housing items require an explicit tooltip action; non-usable housing dyes are
  excluded.
- Locked lockboxes are excluded until their tooltip no longer reports them as
  locked or requiring lockpicking.
- No bank scanning, lockpicking, disenchanting, quest automation, auto-opening,
  analytics, or external dependencies.
- The secure button requires in-game testing. Static tests cannot reproduce
  Blizzard's combat-lockdown and taint behaviour.

## Initial in-game checks

1. Confirm an ordinary loot container appears and opens with one click.
2. Confirm Warbound Pack of Hero Mistcrests (`280732`) appears.
3. Confirm an unlearned transmog token appears even on another armour class.
4. Confirm known collectibles do not appear.
5. Confirm housing dye and locked lockboxes do not appear.
6. Confirm right-click skips without consuming the item.
7. Enter and leave combat with the button visible; verify no blocked-action or
   Lua errors and that the button refreshes afterward.

## Design boundary

ItemFYI is a quiet heads-up, not an inventory manager. Features should earn
their place by improving detection, confidence, or click safety without turning
the addon into a permanent dashboard.

## Development note

The initial MVP was created with assistance from OpenAI Codex. AI assistance
covered architecture, implementation, static tests, and documentation. In-game
validation remains the responsibility of the maintainer.

ItemFYI embeds LibStub and EditModeExpanded-1.0. EditModeExpanded is maintained
by teelolws and provides the compatibility layer for registering addon frames
with Blizzard Edit Mode.

## UI skinning

ItemFYI declares ElvUI and EllesmereUI as optional dependencies. EllesmereUI's
published third-party skin callback is preferred and follows live theme
changes. When EllesmereUI is absent, ItemFYI uses ElvUI's item-button skin
handler. The built-in dark padded style remains the fallback.
