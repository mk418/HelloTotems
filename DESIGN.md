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

## Ideas / next

In rough order of value-to-effort. None implemented yet.

1. **Lightning Shield charge count overlay.** Show 1–9 on the shield button so Enhancement shamans can see when the buff is about to drop. `UnitBuff` already returns `count`; just a small FontString on top of the swirl. Sets the precedent for "in-combat state overlays beyond timers" — fine, but worth being deliberate about.
2. **Totemic Call recall button.** Small button at the end of the bar that recalls all active totems for the 25% mana refund. One click, no combat caveats.
3. **Standard action-button dimming.** Red tint when the assigned spell is out of range; faded when out of mana. Currently buttons always look "ready" regardless of cast state.
4. **Per-character totem ordering.** Flyout order saved per character instead of account-wide. Matters when a tank-spec alt and a DPS-spec main want different priorities for the same element.
5. **Bar scale via slash command.** `/ht scale 0.8` to resize. Size is fixed at 36px today.

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
