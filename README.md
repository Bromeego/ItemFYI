# ItemFYI: Openables & Learnables

ItemFYI is a lightweight World of Warcraft Retail addon that points out useful,
actionable items already sitting in your bags. It shows one secure button and
never opens or learns anything automatically.

## MVP behaviour

- Scans all equipped bags at login and after bag changes.
- Shows one item at a time, with a small `+N` count when more are waiting.
- Prioritises uncollected mounts, pets, companion Curios, toys, housing decor,
  transmog tokens, learnable visual effects, profession skill and knowledge
  items, recipes, garrison items, and reputation tokens before ordinary
  containers.
- Uses Blizzard collection APIs where available, tooltip signals for explicit
  learnable tokens and non-battle companions, and a small exception list for
  known crest packs.
- Surfaces directly usable legacy tier tokens that create a class-set item for
  the current loot specialization, and 12.1 slot tokens that create a soulbound
  set item for the current class, while excluding unmet class and level
  restrictions.
- Recognises learnable visual-effect consumables from their explicit unlock
  action, including all five Coiled Huntress pearls, without maintaining a
  separate item-ID list for them.
- Recognises digit- and word-number stack-conversion instructions such as
  `Combine 10 ... to create ...` and `Combine two ... to create ...`, totals
  matching items across equipped bags, and only offers the action once the
  threshold is met. Fractured Sparks of Starlight and Venom-Cursed Fragments
  therefore use the same generic detector as Bloom Baubles; only conversions
  without a safely readable threshold need explicit rules.
- Detects profession knowledge consumables from Midnight, The War Within, and
  Dragonflight through their explicit study action. Weekly Thalassian, Algari,
  Undermine, and Draconic Treatises also use their completion flags so they
  disappear after that week's use.
- Recognises explicit single-item gutting, salvage, and bag-item disenchant
  actions generically, so items such as Shimmersiren, Rotten Rimefin Tuna, and
  Darkmoon Faire Discarded Weapons do not need ID rules.
- Surfaces WoD garrison bag items from their use text, including naval
  equipment such as Ice Cutter and Trained Shark Tank, follower upgrades, and
  building blueprints.
- Surfaces reputation tokens whose use text grants a numeric amount of
  reputation, such as Legion insignias, including when the faction is already
  at Paragon.
- Surfaces all small, regular, and enormous Draenor fish only when their
  tooltip-required batch of five is available across equipped bags.
- Surfaces Rotten Rimefin Tuna for salvage. Frosted Rimefin Tuna is
  intentionally excluded because defrosting starts the resulting fish's
  one-hour expiry timer.
- Only suggests recipes that are usable by the current character, combining
  Blizzard's usability result with the tooltip's rendered requirement state so
  red profession, specialization, level, or skill requirements are excluded.
- Uses secure item-ID actions for containers and other non-equippable items so
  vendor bag-slot changes cannot stale their targets. Equippable appearance
  tokens use their exact bag slot so WoW learns them instead of trying to equip
  an unsupported armour or weapon type.
- Invalidates slot-targeted appearance actions immediately when their bag
  changes and blocks those actions in combat.
- Keeps slot-targeted appearances available at merchants by closing the
  merchant interaction immediately before the secure use. WoW does not
  reliably let addons reopen a fully closed merchant interaction, so the
  tooltip warns that the vendor will close and the player can interact with it
  again afterward. If the safe close is unavailable, the action is hidden
  rather than risking a sale.
- Suppresses slot-targeted appearance actions while bank, mail, trade, auction,
  scrapping, upgrade, and similar inventory-routing windows are active,
  preventing the click from moving the item instead.
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
- `/ifyi ignored` — list permanently ignored items.
- `/ifyi unignore <key>` — restore an ignored item.
- `/ifyi clearignored` — clear the permanent ignore list.
- `/ifyi clearskips` — clear session skips.
- `/ifyi reset` — reset the button position.

## Settings

Open **Options → AddOns → ItemFYI**, type `/ifyi`, or use the minimap Addon
Compartment. The panel can enable or disable ItemFYI, toggle individual item
categories, show or hide the attention glow, change the button size, reset its
position, list and clear skipped or ignored items, and rescan the bags.

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
- Legacy tier tokens are shown when the current character can activate them.
  ItemFYI cannot reliably determine whether every possible spec-specific result
  is already collected, so a token may occasionally create a known appearance.
- Housing items require an explicit tooltip action and satisfied character or
  profession requirements; non-usable housing dyes are excluded.
- Companion Curios require the explicit action to add the Curio to the
  companion collection; incidental Curio references in flavour text are ignored.
- Permanent profession skill items require an explicit base-skill cap in their
  use text. They are hidden when that profession is already at the stated cap;
  temporary skill buffs are excluded.
- Profession knowledge items require an explicit study action and a satisfied
  profession requirement. Treatises are additionally hidden after their weekly
  completion flag is set.
- Temporary fish buffs, location-dependent fish summons, and actions that begin
  an expiry timer are deliberately excluded.
- Locked lockboxes are excluded until their tooltip no longer reports them as
  locked or requiring lockpicking.
- Multi-part combines such as Darkmoon card sets are excluded because ItemFYI
  cannot verify every distinct required item; only numeric stack conversions
  with a usable item action are detected generically.
- No bank scanning, lockpicking, profession disenchanting of gear, quest
  automation, auto-opening, analytics, or external dependencies. Bag items
  whose own use text is `Disenchant this item to produce ...` are treated as
  processing actions, not as Enchanting-profession disenchanting.
- The secure button requires in-game testing. Static tests cannot reproduce
  Blizzard's combat-lockdown and taint behaviour.

## Initial in-game checks

1. Confirm an ordinary loot container appears and opens with one click.
2. Confirm Warbound Pack of Hero Mistcrests (`280732`) appears.
3. Confirm an unlearned transmog token appears even on another armour class.
4. Confirm an eligible legacy tier token appears and creates its class-set item;
   confirm a token for another class remains hidden.
5. Confirm known collectibles do not appear.
6. Confirm housing dye and locked lockboxes do not appear.
7. Confirm right-click skips without consuming the item.
8. Enter and leave combat with the button visible; verify no blocked-action or
   Lua errors and that the button refreshes afterward.
9. Confirm an uncollected companion Curio appears, can be added, and disappears
   after collection.
10. With an equippable appearance action waiting, open a merchant and use it.
    Confirm the tooltip warns that the vendor will close, the appearance is
    learned rather than sold, and the merchant remains closed after the click.

## Detection and maintenance boundary

ItemFYI is a quiet heads-up, not an inventory manager. Features should earn
their place by improving detection, confidence, or click safety without turning
the addon into a permanent dashboard.

Detection follows a strict order so the addon does not become an item database:

1. Prefer Blizzard collection and bag APIs for mounts, pets, toys, and ordinary
   loot-bearing containers.
2. Use narrowly scoped action text for reusable families such as learnables,
   profession progress, garrison and reputation tokens, stack combines, and
   processing actions.
3. Require usability, stack thresholds, and rendered requirement checks where
   clicking could otherwise fail or perform the wrong action.
4. Add an item-ID rule only when required state is not exposed generically,
   such as a hidden weekly completion quest or unreliable container metadata.

Distinct multi-item recipes still require explicit dependency data and are not
guessed from tooltip prose. Broad `Use:` or item-spell matching is intentionally
avoided because it would include potions, buffs, equipment, and other items that
do not belong in ItemFYI.

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
