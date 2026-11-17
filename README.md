# Forever Auras

WoW WeakAuras I build, one folder per aura under `auras/`.

| Aura | What it does |
|------|--------------|
| [ranged-range-indicator](auras/ranged-range-indicator/) | Shows distance to target, green/yellow/red for ranged classes |
| [universal-cast-bar](auras/universal-cast-bar/) | Fancy cast bar for player/target/focus: casts, channels, pushback, interrupts, latency, ticks, GCD |
| [warlock-dot-rotation](auras/warlock-dot-rotation/) | WoW Forever warlock rotation queue (now + next 2, scrolling) with a strip of running DoTs |

## Adding a new aura
1. `cp -r auras/_template auras/<new-aura-name>`
2. Fill in the README, write the Lua (`trigger.lua`, etc.) and `aura.py` (the aura definition).
3. `python3 tools/build_import.py auras/<new-aura-name>/aura.py` → writes `import.txt`
4. In game: WeakAuras → Import → paste the contents of `import.txt` (then `/reload` if you are replacing an older version).
5. Add a row to the table above.

`tools/build_import.py` produces `!WA:1!` strings (AceSerializer + deflate), which WeakAuras still imports.
After import, WeakAuras re-exports in its own newer format if you want to share it.

## Docs
See [docs/](docs/README.md) for the workflow, WoW Forever specifics, secure-frame limits and testing. `CLAUDE.md` (also `AGENTS.md`) holds the rules for AI agents working in this repo.
