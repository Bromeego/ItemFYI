# Changelog

## Unreleased

- Stopped housing plans with unmet profession or skill requirements from being
  offered to characters that cannot add them.
- Prevented slot-targeted appearance actions from selling or moving their item
  inside merchant and other inventory-routing windows.
- Slot-targeted appearances now explain that their merchant window will close
  before use. WoW does not reliably reopen a fully closed vendor interaction,
  so ItemFYI leaves it closed rather than promising an unsafe or inconsistent
  handoff. Clients unable to close it safely hide the action instead.
- Other risky inventory-routing interactions still suppress slot-targeted
  actions until their window closes; safe item-ID actions remain available.
- Added generic support for directly usable legacy tier tokens that create a
  class-set item for the current loot specialization.
- Added class-restriction filtering so tier tokens for an ineligible character
  are not offered even when Blizzard's generic usability result is incomplete.
- Added threshold-aware gutting and cleaning for Draenor fish, shown only when
  the tooltip-required batch of five is available across equipped bags.
- Added Rotten Rimefin Tuna salvage while deliberately excluding Frosted
  Rimefin Tuna because defrosting starts a one-hour expiry timer.
- Added Shimmersiren as an explicit profession action for gutting from the
  ItemFYI button.
- Added profession knowledge consumables across Midnight, The War Within, and
  Dragonflight, including one-time treasures and patron-order rewards detected
  from their explicit study action.
- Added weekly completion gates for all Thalassian, Algari, Undermine, and
  Draconic Treatises so used treatises do not remain queued until reset.
- Renamed the profession setting to cover both permanent skill and knowledge
  items; temporary profession buffs remain excluded.
- Added a toggleable profession skill category for permanent increases such as
  Muck-Covered Writings, including stated-cap and unmet-requirement checks.
- Added a toggleable Companion Curios category for items with an explicit action
  to add the Curio to the companion collection.
- Fixed recipe filtering when Blizzard's generic item-usability result remains
  true despite a red unmet profession or skill requirement in the tooltip.
- Fixed equippable appearance items such as unsupported weapon types trying to
  equip instead of invoking their Warband collection action.
- Uses exact bag-slot actions only for equippable appearance tokens, while
  retaining item-ID actions for vendor containers and other items.
- Invalidates slot-targeted actions as soon as their bag changes and blocks
  those actions in combat to prevent stale slots from using another item.
- Stopped recipes with unmet profession, specialization, or skill requirements
  from appearing on characters that cannot learn them.
- Added threshold-aware support for Ascendant Voidshards at five and Void
  Vestiges at four.
- Counts threshold items across all equipped bags, including split stacks.
- Added threshold-aware support for Venom-Cursed Fragments, shown only when at
  least two are available to combine.
- Fixed Pet Journal species lookup and added detection for non-battle companion
  items such as Emberlyn.
- Stopped background bag scans from hiding tooltips owned by bags, vendors, or
  other UI elements.
- Stopped completed appearance caches, including Cache of Void-Touched
  Legwear, from appearing when their tooltip says every contained look is
  already collected.
- Fixed left-click actions for both click-on-press and click-on-release settings.
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
