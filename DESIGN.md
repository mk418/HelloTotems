# HelloTotems — Design Document

A lean, opinionated totem manager for World of Warcraft Classic Era Shamans. Companion to HelloHealer; out-of-scope for that addon's heal-target UI.

---

## Design philosophy

1. **Zero-config first launch.** Detect Shaman + spellbook, apply sensible defaults, ready to drop.
2. **Reliability over features.** Same conventions as HelloHealer: secure templates where possible, no clever in-combat reconfiguration, no Blizzard monkey-patching.
3. **You decide what to drop; the addon makes it fast.** No "smart totem rotation."

---

## Scope

TBD. Starting points:
- Quick-cast totem bar (one column per school, ordered by player preference).
- Cooldown display for short-CD totems (Tremor, Grounding, Mana Tide).
- Active-totem timers (mirrors Blizzard's TotemFrame data, restyled to match HelloHealer's cell visuals).

## Out of scope

- Auto-drop / smart rotation.
- Totem-twisting helpers.
- Anything that touches non-Shaman gameplay.

---

## File structure

```
HelloTotems/
├── HelloTotems.toc
├── Core.lua              -- namespace, event dispatcher, slash commands
├── Config.lua            -- saved-variables schema, defaults
└── (modules TBD)
```
