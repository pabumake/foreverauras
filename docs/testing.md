# Testing

## 1. Syntax
`(echo "local f = "; cat auras/<name>/trigger.lua) | luac -p -` (the trigger is a bare anonymous function).
`python3 tools/build_import.py auras/<name>/aura.py` must succeed.

## 2. Logic without the game: mock harness
`auras/warlock-dot-rotation/test_harness.lua` and `auras/universal-cast-bar/test_harness.lua` (run with `luajit`, see their headers; the cast bar one also mocks frames, DurationObjects, the numeric formatter and secret values) stubs the WoW API (frames as no-op objects, `C_Spell`, `C_UnitAuras`, `C_Secrets`, `GetTime`, ...), loads the trigger, feeds events and prints the resulting queue. It simulates fully hidden aura data, casts and elapsed time. Use it for any aura whose logic depends on state over time. Copy and adapt per aura (frame names, known spells, IDs).
Rules of thumb for the mock: capitalized method names return no-op functions, lowercase fields return nil (so custom fields like `frame.dbg` behave as in the game).
What it cannot prove: real API behaviour (what the client returns, secret values, restrictions). That only shows up in game.

## 3. In game
- Re-import, `/reload` if frame structure changed.
- Build a debug readout into the aura (a `DEBUG` constant that shows what each detection layer sees, which layer matched, seconds left) before guessing at API behaviour; ship it `false`. The warlock aura's readout is what exposed that aura data is hidden in combat.
- Errors: use BugSack/BugGrabber (`/bugsack`). `ADDON_ACTION_BLOCKED` text names the blocked function and the trigger line.
- Warnings seen from WeakAuras itself are listed in weakauras-workflow.md and secure-frames.md.

## 4. Before handing over
- Import succeeds on a fresh profile (no `Modernize` error).
- No `ADDON_ACTION_BLOCKED`, no WeakAuras warnings.
- Works in combat and out of combat; works after `/reload`; dragging the aura moves the display.
- README has: import steps, what it shows, config knobs, limitations, changelog.
