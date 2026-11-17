# Universal Cast Bar

A fancy cast bar for WoW Forever that works for every kind of cast (casts, channels) on every unit. One import per unit: **player**, **target**, **focus**.

## Import
Easiest: paste the contents of **`import-group.txt`** into WeakAuras (`/wa` -> New -> Import). It imports the group **FA - Cast Bars** with all three bars as children. Then **`/reload`**.
Or import a single bar:
- `import-player.txt` your own casts
- `import-target.txt` your target's casts
- `import-focus.txt` your focus target's casts
Regenerate with: `python3 tools/build_import.py auras/universal-cast-bar/aura.py` (writes all four files).
In the group you can drag each bar separately, or the whole group. Importing a group again replaces the same-named auras, so remove or rename the single-bar auras if you imported those earlier.
Each aura is an invisible 260x22 box: drag it in WeakAuras to place the bar (the bar is centered on it). While the WeakAuras options are open a preview bar shows so you can position it.

## What it does
- **Casts fill, channels drain**, with a soft spark on the fill edge, gloss, dark backdrop and a 1px border; icon, spell name and a countdown (`1.4` under 10 s, whole seconds above).
- **Colours:** cast gold, channel green, **non-interruptible steel grey**, interrupted/failed red ("Interrupted" / "Failed" for a moment), success flashes green; then fades out.
- **Pushback / channel changes** are followed (the bar takes the new duration). A failed spell you spam while another is still casting does not cancel the running cast.
- **Own casts only** (readable data): red **latency** segment at the end of a cast, **tick marks** on known channels (`TICKS` table: Drain Life 5, Hellfire 15), thin **GCD line** under the bar (also for instants).
- **Other units' casts** are hidden from addons by the client (name, spell, interruptible flag): the bar is driven by the client's duration object, so you still get bar + countdown, and the name/icon/interruptible colour are handed to the widgets without the addon ever reading them.
- Hides the default Blizzard cast bar for that unit (`HIDE_BLIZZARD`, `/reload` or disable the aura to bring it back).
- Display only, no click-to-cast.

## Files
- `aura.py` builds one aura per unit (`UNITS` dict: unit -> default position); add a line for pet / boss / mouseover
- `trigger.lua` all logic and drawing; `UNIT` is rewritten per build
- `test_harness.lua` mock-API logic test: `luajit auras/universal-cast-bar/test_harness.lua auras/universal-cast-bar/trigger.lua`
- `import-group.txt` (all three bars in one group), `import-player.txt`, `import-target.txt`, `import-focus.txt` generated

## Configuration (top of `trigger.lua`)
`WIDTH, HEIGHT`, `SHOW_ICON/NAME/TIMER`, `SHOW_LATENCY/GCD/TICKS`, `HIDE_BLIZZARD`, `FADE_IN/HOLD_END/FADE_OUT`, `FONT_SIZE`, `COLORS`, `TICKS`, `GCD_SPELL`. Size/icon options apply on the next `/reload` (the frame is built once).

## Requirements / known limitations
- **Untested in game.** Logic passes the mock test (26 checks). Real-client behaviour is listed as UNVERIFIED in `docs/cast-bar-research.md` section 6 (secret values into widgets, colour from a secret boolean, Blizzard frame names, GCD spell). If the bar shows but name/icon/colour are wrong for target casts, that is where to look.
- No spell-school colours, no cast-target text (target name of a cast is secret), no empowered stages (not in Forever).
- Auto-repeat attacks (Auto Shot, wand Shoot) are not casts and get no bar.
- Research and design: `docs/cast-bar-research.md`.

## Changelog
- 2026-11-17 – initial version (player / target / focus)
- 2026-11-17 – group import (`import-group.txt`)