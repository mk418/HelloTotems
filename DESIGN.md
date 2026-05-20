# HelloTotems — Design Document

A lean, opinionated totem manager for World of Warcraft Classic Era Shamans. Companion to HelloHealer; out-of-scope for that addon's heal-target UI.

---

## Design philosophy

1. **Zero-config first launch.** Detect Shaman + spellbook, apply sensible defaults, ready to drop.
2. **Reliability over features.** Same conventions as HelloHealer: secure templates where possible, no clever in-combat reconfiguration, no Blizzard monkey-patching.
3. **You decide what to drop; the addon makes it fast.** No "smart totem rotation."

---

## Current scope

- **Quick-cast bar** of secure-cast buttons, one column per element (Fire / Earth / Water / Air), plus a Weapon imbue column and a Lightning Shield column.
- **Flyout pickers** per slot (toggled by a small upward chevron or right-click) listing every known spell for that school. Selecting an entry casts it and reassigns the slot.
- **Active-duration timers** on the buttons themselves: `GetTotemInfo` for the four totem slots, `GetWeaponEnchantInfo` for the imbue slot, `UnitBuff` for Lightning Shield.
- **Empty-slot placeholder icons** — desaturated, dimmed icon of a representative spell so the slot reads as "this is the Fire slot, just empty" even at low level.
- **Action-button styling** — UI-Quickslot2 gold border with the standard pushed/highlight textures.
- **User-customizable key bindings** via `Bindings.xml`, using the engine's `CLICK <Button>:<Button>` form so the keypress dispatches a real hardware click (the only way to avoid `ADDON_ACTION_FORBIDDEN` for `CastSpellByName` in Classic Era 1.15).

## Out of scope

- Auto-drop / smart rotation.
- Totem-twisting helpers.
- Anything that touches non-Shaman gameplay.

---

## File structure

```
HelloTotems/
├── HelloTotems.toc
├── Bindings.xml            -- key bindings (auto-loaded by WoW)
├── Core.lua                -- namespace, event dispatcher, slash commands,
│                              BINDING_NAME globals
├── Config.lua              -- saved-variables schema, defaults
├── Totems.lua              -- per-slot spell catalog + spellbook scanner
└── TotemBar.lua            -- bar frame, main buttons, flyouts, timers
```
