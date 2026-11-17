# WeakAuras workflow

## Layout
```
auras/<name>/aura.py      aura definition: a Python dict `AURA` (reads trigger.lua and inlines it)
auras/<name>/trigger.lua  custom trigger / code (anything longer than a line lives in .lua, not in aura.py)
auras/<name>/import.txt   GENERATED import string, commit it
auras/<name>/README.md    user-facing doc (copy auras/_template/README.md)
tools/build_import.py     dict -> "!WA:1!" import string (AceSerializer + raw deflate + LibDeflate print-encoding)
```

## Steps for a new aura
1. `cp -r auras/_template auras/<name>`; write `trigger.lua`, `aura.py`, README.
2. `python3 tools/build_import.py auras/<name>/aura.py` writes `import.txt`.
3. In game: `/wa` -> New -> Import -> paste `import.txt`. Same `id` replaces the aura.
4. After updating from an older version that created frames: `/reload` (frames cannot be removed otherwise).
5. Add a row to the root README table; add a changelog line to the aura README.

Syntax-check a trigger (it is a bare anonymous function, so wrap it): `(echo "local f = "; cat trigger.lua) | luac -p -`

## aura.py must contain (learned the hard way)
- `"internalVersion": 91` (current for ForeverAuras 1.4.3, see `ForeverAuras.lua:8`). Older values run upgrade steps in `Modernize.lua` that crash on missing fields.
- `"actions": {"init": {}, "start": {}, "finish": {}}`. `Modernize.lua:2471` reads `data.actions` for versions < 88 without a nil check. Import error text: `Modernize.lua:2471: attempt to index field 'actions' (a nil value)`.
- Check the installed addon's current version before assuming: `grep -n "internalVersion =" <addon>/ForeverAuras.lua`.
- One folder can ship several auras: define `AURAS = {"player": {...}, "target": {...}}` instead of `AURA`; the build writes `import-<key>.txt` for each. Add a parent `GROUP = {...}` dict (copy the one in `universal-cast-bar/aura.py`, taken from a group ForeverAuras exported) and the build also writes `import-group.txt`: payload `d` = group, `c` = list of children; the importer sets `controlledChildren` and each child's `parent` itself (`Transmission.lua` ~699). Generate variants in Python (see `universal-cast-bar/aura.py`, which rewrites a `UNIT` constant in the Lua and the event list per unit).
- The build script only needs plain dicts/lists/str/num/bool. Lua arrays are 1-indexed lists; integer dict keys (e.g. `triggers[1]`) are fine.

## Custom trigger conventions
- Type `custom`, `custom_type: "status"`, `check: "event"`, `events: "A, B, FRAME_UPDATE"`. Function signature `function(event, arg1, arg2, ...)`; return true to show the region.
- Unit-filtered events use `EVENT:unit`, e.g. `UNIT_SPELLCAST_SUCCEEDED:player`; args arrive as `(event, unit, castGUID, spellID)`. Verified in `GenericTrigger.lua` (~line 2083).
- `FRAME_UPDATE` alone was too slow in practice; the aura creates its own `OnUpdate` driver frame (~10-20 Hz) and the trigger just calls the same refresh function.
- `aura_env.region` is the aura's region. `aura_env.saved` persists across sessions (used to remember learned spell IDs).
- Return `true` from the trigger even with nothing to show, if the invisible region should stay selectable/draggable in the options.

## Sandbox rules (custom code runs in a WeakAuras sandbox)
- No `pcall`. No assigning globals: `_G[name] = x` triggers the warning "The aura has overwritten the global ...". Naming a frame in `CreateFrame("Frame", NAME, ...)` registers it without the warning; read it back with `_G[NAME]`.
- Create frames once and keep them on a named global frame so re-imports/re-runs never stack duplicates.
- Frames created by old versions of the code cannot be found or removed: tell the user to `/reload`, and bump a `VERSION` suffix in frame names only when the structure changes incompatibly.

## Position / dragging
- Anchor your own frames to `aura_env.region` (`box:SetPoint("CENTER", region, "CENTER")`) so the aura can be dragged in WeakAuras. Give the region a width/height matching your content and `color` alpha 0 so it is an invisible drag handle.
- Exception: anything secure must NOT be anchored to the region, see [secure-frames.md](secure-frames.md).

## Reference: the installed addon's source
Reading the addon source beats guessing. Machine-specific path (this setup):
`/mnt/02-games/BattleNetGames/World of Warcraft/_forever_/Interface/AddOns/ForeverAuras/` (files: `Modernize.lua`, `GenericTrigger.lua`, `BuffTrigger2.lua`, `AuraEnvironment.lua`, ...).
Saved variables (aura exports, spell cache): `.../_forever_/WTF/Account/<account>/SavedVariables/ForeverAuras.lua` and `ForeverAurasOptions.lua`. Do not copy account IDs into the repo.
