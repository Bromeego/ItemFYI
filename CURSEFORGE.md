# ITEMFYI

### Openables & Learnables, Without the Bag Diving

*"That coffer from three dungeons ago? Still in your bags."*

[![Report an issue](https://img.shields.io/badge/Report_an_issue-GitHub-24292f?style=for-the-badge&logo=github&logoColor=white)](https://github.com/Bromeego/ItemFYI/issues) [![License: MIT](https://img.shields.io/badge/License-MIT-3da639?style=for-the-badge)](https://github.com/Bromeego/ItemFYI/blob/main/LICENSE) ![WoW Retail](https://img.shields.io/badge/WoW-Retail-f8b700?style=for-the-badge&logo=battledotnet&logoColor=white) ![WoW Forever](https://img.shields.io/badge/WoW-Forever-f8b700?style=for-the-badge&logo=battledotnet&logoColor=white)

⭐ **Follow this project** to hear about updates. Following is the only way CurseForge tells you when a new version ships.

<!-- Replace with a Gallery image URL: the button and its tooltip over a bag item -->
![ItemFYI in action](SCREENSHOT_URL)

---

## 🎒 About the Addon

**ItemFYI** watches your bags and shows a single button whenever you're carrying something you can **open, learn, or use**: a cache, a mount you never clicked, a new recipe, a toy, or a quest starter. Click it to handle the item, and the button moves on to the next one.

It's lightweight, it never does anything without a click, and it works alongside whatever bag addon you already use.

---

## 🎯 What It Finds

| 📦 Openables | 🐎 Collections | 🎨 Appearances & Home |
| :-- | :-- | :-- |
| • Caches, coffers & loot bags<br>• Stacks ready to combine<br>• Holiday treat bags | • Uncollected mounts<br>• Toys you don't have<br>• Battle pets (with owned count) | • Appearance tokens & costumes<br>• Unlearned class glyphs<br>• Housing decor for your House Chest |

| 📜 Professions | 🏆 Progression | ❗ Quests & Delves |
| :-- | :-- | :-- |
| • Unlearned recipes<br>• Profession knowledge<br>• Items ready to process | • Reputation tokens<br>• Garrison & progression items<br>• Permanent power unlocks | • Items that start a quest<br>• Companion Curios for Delves |

Items you can't use yet (too low level, missing a skill or reputation) and anything you already know are left out. **Each category can be switched off in settings.**

---

## 🖱️ Controls

| Action | What it does |
| :-- | :-- |
| **Left-click** | Use or open the item |
| **Right-click** | Skip it for this session |
| **Ctrl-right-click** | Ignore it permanently |
| **Alt-drag** | Move the button (or place it in **Edit Mode**) |
| **Keybinding** | *Options → Keybindings → ItemFYI* uses the current item |

> 💡 **Tip:** A cooldown sweep shows when the item is on cooldown, and the icon turns grey in combat if its action has to wait until combat ends.

---

## 🛡️ Safe by Design

- **Nothing is automatic.** ItemFYI never opens, learns, or uses anything unless you click.
- **It hides at vendors, banks, mailboxes, the auction house, trade, and the scrapper**, so a click can never sell, deposit, or mail an item by accident. It comes back when you close the window.
- It doesn't scan your bank or touch locked boxes.

---

## 🎛️ Slash Commands

| Command | Description |
| :-- | :-- |
| `/ifyi` | Open settings (also in *Options → AddOns* and the minimap Addon Compartment) |
| `/ifyi scan` | Clear skips and rescan your bags |
| `/ifyi list` | List everything currently detected |
| `/ifyi ignored` | Show your ignore list |
| `/ifyi unignore <key>` | Restore an ignored item |
| `/ifyi reset` | Reset the button position |
| `/ifyi help` | Show all commands |

---

## 🧩 Compatibility

- **Retail** and **WoW: Forever**. On Forever, categories for systems the game doesn't have (such as housing decor or Delve Curios) simply stay empty.
- Doesn't replace or change your bag addon; it just reads what's in your bags
- Matches **ElvUI** and **EllesmereUI** styling automatically when they're installed
- Works best on English clients. Other languages use the game's collection data and translated tooltip text, so most items are detected, but a few item-specific checks are English-only.

---

### 🐛 Found Something It Missed?

Spotted an item ItemFYI should show, or one it shouldn't? [**Open an issue on GitHub**](https://github.com/Bromeego/ItemFYI/issues) with the item name or a Wowhead link. That's much easier to track than CurseForge comments.
