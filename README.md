# Forever Auras

WoW WeakAuras I build, one folder per aura under `auras/`.

| Aura | What it does |
|------|--------------|
| [ranged-range-indicator](auras/ranged-range-indicator/) | Shows distance to target, green/yellow/red for ranged classes |

## Adding a new aura
1. `cp -r auras/_template auras/<new-aura-name>`
2. Fill in the README, write the Lua (`trigger.lua`, etc.) and `aura.py` (the aura definition).
3. `python3 tools/build_import.py auras/<new-aura-name>/aura.py` → writes `import.txt`
4. In game: WeakAuras → Import → paste the contents of `import.txt`.
5. Add a row to the table above.

`tools/build_import.py` produces `!WA:1!` strings (AceSerializer + deflate), which WeakAuras still imports.
After import, WeakAuras re-exports in its own newer format if you want to share it.
