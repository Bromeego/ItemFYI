# Changelog

## Unreleased

- Stopped completed appearance caches, including Cache of Void-Touched
  Legwear, from appearing when their tooltip says every contained look is
  already collected.
- Fixed left-click actions for both click-on-press and click-on-release settings.
- Uses a secure bag-slot `/use` action so equippable appearance tokens are used
  rather than routed through the secure item's equip behaviour.
- Added optional EllesmereUI and ElvUI skin adapters while preserving ItemFYI's
  built-in dark style as the fallback.
- Stopped non-usable housing dyes and tooltip-marked locked lockboxes from
  appearing as actionable items.
- Removed the button title and Blizzard quick-slot border while retaining the
  dark padded background around the item icon.
- Added Blizzard Edit Mode support with per-layout button positions.
- Added an Edit Mode placeholder so the button remains selectable when no
  actionable item is waiting.
- Preserved Alt-drag positioning and migrated the existing saved position.
- Added a native Blizzard AddOns settings panel.
- Changed bare `/ifyi` to open settings while keeping `/ifyi help` and all
  existing commands.
- Added category toggles, button sizing, position reset, dismissed-item cleanup,
  and manual bag rescanning.
- Deferred button layout changes made during combat until combat ends.

## 0.1.0 — MVP

- Added event-driven scanning of all equipped bags.
- Added a single secure action button with exact bag-slot targeting.
- Added mount, toy, battle-pet, housing-decor, transmog-token, recipe, and
  container detection.
- Added explicit Midnight Dawncrest and 12.1 Mistcrest container rules.
- Added session skip and persistent ignore controls.
- Added combat-safe deferred refreshes, candidate reasons, `+N` count, movable
  position, slash commands, and local validation tests.
