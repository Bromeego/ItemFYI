# ItemFYI

**ItemFYI** helps you notice useful items in your bags that are easy to forget
about.

It checks your bags for supported items such as:

- Containers and other items that can be opened
- Items that teach you something, such as toys, pets, mounts, recipes, or
  appearances
- Items that begin a quest

When ItemFYI finds something, it shows a small notification so you can decide
what to do with it.

## How to use it

When an item appears in the ItemFYI notification:

- **Click** the item to use or open it
- **Right-click** to skip it for this session and move on to the next item
- **Ctrl-right-click** to ignore it if you do not want ItemFYI to show that
  item again

Alt-drag moves the button, or you can place it in Blizzard Edit Mode.

You can also type:

```text
/ifyi
```

to open the addon settings. Options are also available under
**Options → AddOns → ItemFYI** and from the minimap Addon Compartment.

ItemFYI is designed to stay simple and out of the way. It does not manage your
bags or replace your inventory addon — it just gives you a quick heads-up
about items you may have missed. It never opens or learns anything
automatically.

## Installation

1. Extract the `ItemFYI` folder into
   `World of Warcraft/_retail_/Interface/AddOns/`
2. Restart WoW or type `/reload`

## Commands

- `/ifyi` — open settings
- `/ifyi help` — show command help
- `/ifyi scan` — clear session skips and scan again
- `/ifyi list` — list currently detected actions
- `/ifyi skip` / `/ifyi ignore` — skip or permanently ignore the current item
- `/ifyi ignored` / `/ifyi unignore <key>` / `/ifyi clearignored` — manage the
  ignore list
- `/ifyi clearskips` — clear session skips
- `/ifyi reset` — reset the button position

## Notes

Retail only. ItemFYI does not scan the bank, auto-open items, or pick locks.
ElvUI and EllesmereUI skins are used when those addons are installed.

See [CHANGELOG.md](CHANGELOG.md) for release notes.

## Reporting issues

Please [open a GitHub issue](https://github.com/Bromeego/ItemFYI/issues) in
this repository. Bug reports and suggestions submitted here are easier to
track than comments on CurseForge.

## Development

Maintainer notes for testing, packaging, and releases live in
[CONTRIBUTING.md](CONTRIBUTING.md).
