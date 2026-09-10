# Changelog

## 0.2.14

- Stopped currency-only world quest turn-ins from reclassifying every bag
  slot. Quest-log scans now run only when a weekly treatise completion flag
  actually changes; bag rewards still refresh through normal bag events.

## 0.2.13

- Stopped treating every bag scan as a full tooltip refetch. Unchanged slots
  reuse cached snapshots, but each scan still runs live collection and
  usability checks. Using an item only refreshes other copies of that item.
  Login and a manual scan still fetch fresh tooltips.

## 0.2.12

- Stopped opening a vendor from immediately reclassifying every bag slot. That
  hitch stacked with auto-sell addons as junk left the bags. Merchant and other
  inventory-routing window scans now wait for bag events to settle and reuse
  unchanged tooltip snapshots.

## 0.2.11

- Stopped leaving combat from immediately reclassifying every bag slot, which
  froze the client as loot such as Cursed Surge bags appeared. Combat-end
  scans now wait for bag events to settle and reuse unchanged tooltip snapshots.

## 0.2.10

- Coalesced mailbox and other bag bursts into one scan after items stop
  arriving, and reused tooltip snapshots for unchanged slots so picking up
  mail no longer reclassifies the whole bag on every item.

## 0.2.9

- Stopped bag rescans on `GET_ITEM_INFO_RECEIVED` and `ITEM_DATA_LOAD_RESULT`
  unless ItemFYI previously asked for that item, so hovering tooltips no longer
  hitch while every bag slot is reclassified.

## 0.2.8

- Identified caged battle pets from TooltipData's `battlePetSpeciesID` field,
  battle-pet tooltip type, and companion-pet item class so bag scans skip
  `SetBagItem` after a reload even when the nested `battlePet` table is absent.

## 0.2.7

- Stopped bag scans from erroring on caged battle pets after a reload, when
  Blizzard's pet tooltip tries to anchor to a GameTooltip that has no points yet.
- Kept Lua 5.1 tests passing when pet-journal lookup returns no species ID.

## 0.2.6

- Detected WoD garrison bag items from their use text, including naval
  equipment such as Ice Cutter and Trained Shark Tank, follower upgrades, and
  building blueprints.
- Detected reputation tokens such as Legion insignias whose use text grants a
  numeric amount of reputation, including after the faction is at Paragon.

## 0.2.5

- Hid the battle-pet companion tooltip when leaving the ItemFYI button, and
  stopped bag scans from leaving a pet card stuck over other items.

## 0.2.4

- Tightened the attention glow so it sits closer to the icon.
- Added a settings toggle to show or hide the attention glow.

## 0.2.3

- Sized the attention glow outside the icon and raised the stack count above it
  so the quantity is no longer hidden by the proc sparkle.

## 0.2.2

- Detected bag items whose use text is `Disenchant this item to produce ...`,
  such as Darkmoon Faire Discarded Weapons, using the same processing path as
  salvage. Ordinary gear that can be disenchanted with Enchanting remains
  excluded.

## 0.2.1

- Detected 12.1 Venomous Abyss tier tokens such as Venomcast Relic, whose use
  text creates a soulbound set slot item for the current class rather than a
  loot-specialization class-set item.

## 0.2.0

- Stopped Alt-drag from using the current item when click-on-press is enabled.
- Stopped `Use: Opens ...` portal and similar text from matching as openables.
- Required Voidshards and Void Vestiges to be usable before they are offered.
- Switched the attention glow to `ActionButtonSpellAlertManager`, with the
  deprecated overlay-glow helpers as a fallback.
- Replaced the deprecated Options slider template with `UISliderTemplate` and
  addon-owned labels.
- Cached each bag tooltip once per scan, including requirement colours and
  battle-pet metadata.
- Hid appearances already known to `C_TransmogCollection` while still showing
  Warband tokens on the wrong armour class.
- Rescanned after loot-spec changes and player quest-log updates so weekly
  treatises and spec-specific tokens refresh without a bag event.
- Listed ignored item names in settings and added `/ifyi ignored`.
- Documented that a bare `/ifyi` opens settings, and registered the Addon
  Compartment entry.
- Confirmed the embedded EditModeExpanded-1.0 library is still upstream MINOR
  118 for 12.1.

- Added generic learnable visual-effect detection for all five Coiled Huntress
  pearls: Cerulean, Sinful, Amber, Cursebound, and Blighted.
- Renamed the transmog setting to **Transmog & visual unlocks** to reflect the
  additional learnable family it controls.
- Generalized word-number stack conversions such as `Combine two ... to create
  ...`, allowing Venom-Cursed Fragments and similarly worded items to work
  without item-ID rules.
- Generalized explicit single-item gutting and salvage actions, replacing the
  Shimmersiren and Rotten Rimefin Tuna ID rules with guarded tooltip detection.
- Documented the detection hierarchy and the narrow cases where explicit item
  data remains necessary, reducing the exception list from 68 to 64 rules.
- Added generic numeric stack-conversion detection for tooltip actions such as
  Bloom Baubles, using the whole-bag count and Blizzard's usability result.
- Renamed the container setting to **Openables & stack combines** to reflect the
  actions it controls.
- Added Fractured Spark of Starlight conversion when at least two usable
  fragments are present across equipped bags.
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
