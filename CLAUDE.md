# Forever Auras

WeakAuras for **WoW Forever** (Classic+ on the modern client), one folder per aura under `auras/`. Auras are Python dicts + Lua, compiled into import strings. No test suite beyond a Lua mock harness; most verification happens in game.

`AGENTS.md` is a symlink to this file. Edit `CLAUDE.md` only.

## Commands
- Build one aura: `python3 tools/build_import.py auras/<name>/aura.py` -> writes `auras/<name>/import.txt` (commit it). If `aura.py` defines `AURAS = {name: dict}` instead of `AURA`, it writes `import-<name>.txt` per entry; add a `GROUP` dict and it also writes `import-group.txt` (one paste imports the group with all children). See `universal-cast-bar`.
- Syntax check a trigger: `(echo "local f = "; cat auras/<name>/trigger.lua) | luac -p -`
- Logic tests with mock WoW API: `luajit auras/<name>/test_harness.lua auras/<name>/trigger.lua` (exists for `warlock-dot-rotation`, `universal-cast-bar`)
- After editing `trigger.lua` or `aura.py` ALWAYS rebuild `import.txt`, update the aura README changelog.

## Read first (docs/)
- `docs/weakauras-workflow.md` build/import pipeline, required `aura.py` fields, trigger conventions, sandbox rules
- `docs/wow-forever.md` Forever specifics: ranks, hidden aura data in combat, web sources that work/403
- `docs/secure-frames.md` why click-to-cast and dynamic icons conflict
- `docs/testing.md` mock harness, in-game debugging, handover checklist
- `docs/cast-bar-research.md` cast data on Forever, secret-value toolbox (DurationObject, formatter, curve colours); reuse for any timer/bar aura
- `docs/warlock-dot-rotation.md` design record + history of failures (the template for rotation/uptime auras)

## Hard rules (each cost a debugging round)
1. `aura.py` needs `"internalVersion": 91` and `"actions": {"init": {}, "start": {}, "finish": {}}` or import crashes in `Modernize.lua`.
2. Custom code is sandboxed: no `pcall`, no global assignment (`_G[x] = ...`). Name frames via `CreateFrame("Frame", NAME, ...)`, read via `_G[NAME]`.
3. Never anchor secure frames to the WA region; never Show/Hide/move/resize secure frames (or their parents) in combat; alpha only. Default to display-only auras.
4. In combat the client hides aura data (`C_Secrets.ShouldAurasBeSecret()`): name/index lookups fail, check `issecretvalue`. Track debuffs by spell ID and/or a local timer from `UNIT_SPELLCAST_SUCCEEDED:player`.
5. Match spells by name (ranks have different IDs); verify names/levels against Forever sources, not retail/Classic memory.
6. Frames from old versions survive re-import: tell the user to `/reload` after structural changes.
7. Nothing here can be tested without the game except pure logic: say "untested in game" in READMEs and final answers until the user confirms.

## Conventions
- Folder `auras/<kebab-name>/` with `aura.py`, `trigger.lua`, `import.txt`, `README.md` (from `auras/_template/`); aura ids are prefixed `FA - `; `uid` unique per aura.
- Config knobs (constants/tables) at the top of `trigger.lua`, documented in the aura README.
- Add each aura to the table in the root `README.md`.
- Commit only when asked. Do not put account IDs, emails or other personal data in the repo or in web requests.
- The addon source is on this machine (path in `docs/weakauras-workflow.md`); read it before guessing at addon behaviour.
