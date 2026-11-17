# Warlock DoT Rotation (WoW Forever)

Rotation queue for a WoW Forever (Classic+) warlock: the spell to cast now plus the next two, scrolling as you cast. Running DoTs are not in the queue; they sit in a small strip below with a cooldown swipe showing when to recast. Display only: cast with your normal keybinds / action bars.

## Import
Paste the contents of `import.txt` into WeakAuras (`/wa` → New → Import), then **`/reload`**.
(`/reload` removes frames left by older versions of this aura; they cannot be removed any other way.)
Regenerate with: `python3 tools/build_import.py auras/warlock-dot-rotation/aura.py`

## What it does
- **Queue** (3 icons): slot 1 (largest, yellow border) = cast now; slots 2 and 3 = the next two.
- Priority: Life Tap (only when mana < 25% and health > 50%) → Bane of Agony → Corruption → Siphon Life → Immolate → Drain Soul (target ≤ 25% health) → Shoot (wand, target ≤ 25% health) → Shadow Bolt (filler). Order follows the Icy Veins Forever Affliction guide.
- A DoT is queued when it is missing or has ≤ 2 s left, but not on a dying target (health ≤ `DYING`, default 25%; it would die before the DoT ticks, per the leveling guide: finish it with the wand instead). While it is running it leaves the queue and shows in the **active strip** (small icons, cooldown swipe + seconds left). No downtime calculation.
- Only known, ready, usable spells are queued. Spells are matched by **name**, so every rank works and new spells appear as you learn them.
- **SWITCH TARGET** (orange text above the queue) appears when the target is nearly dead (health ≤ `DYING`) and one of your DoTs is not on it: the DoT would not pay off here, so start it on the next mob. It cannot tell whether another enemy is nearby.
- Hidden when you have no living hostile target.

## Files
- `aura.py` – aura definition (invisible 142x48 anchor texture, Warlock-only load)
- `trigger.lua` – builds the queue + active strip, ~10x/sec driver
- `import.txt` – generated import string
- `test_harness.lua` – logic test against a mock WoW API (`luajit`, see its header)

Design record and history: `docs/warlock-dot-rotation.md`.

## Configuration
- `ROTATION` table at the top of `trigger.lua`: spell names, refresh window, order. Add e.g. `Curse of Weakness`, `Wrack` or `Conflagrate` here. `DYING` = health % below which DoTs are skipped.
- `SLOT_SIZE`, `ACT_SIZE`, `GAP` for sizes.
- **Position:** drag the aura in WeakAuras (invisible 142x48 box; the queue is centered on it).

## Requirements / known limitations
- Untested in game. Spell list is from third-party Forever guides (metabot.gg, rankedboost.com): Immolate L1, Corruption L4, Life Tap L6, Bane of Agony L8, Drain Soul L10, Siphon Life L30. Names may still change while Forever is new.
- English spell names. On another client language, rename the entries in `ROTATION`.
- **Not clickable, on purpose.** WoW does not let secure (click-to-cast) buttons change spell, position or visibility in combat, so a queue that scrolls cannot also be clickable (earlier versions tried and hit `ADDON_ACTION_BLOCKED` on `Frame:SetShown()`).
- In combat the client hides aura names ("secret auras"), so DoTs are looked up by spell ID. `ROTATION` lists every rank's ID per DoT (from the ForeverAuras spell cache); a rank/ID missing from the list is only found out of combat, by name. Also, if an aura's data is hidden entirely, the DoT is treated as running (active strip, not queued).
- The Ranged Range Indicator is a separate aura and will overlap this queue if both are enabled at the same spot; move one of them.

- Not yet handled: Nightfall (instant Shadow Bolt proc, level 25+), Wrack (talent), Bane of Doom (level 60). The proc's buff name in Forever is unknown.
- Wand cutoffs (`DYING`, Drain Soul/Shoot at 25%) are my choice, not from the guide.

## Changelog
- 2026-11-17 – initial version
- 2026-11-17 – reworked for WoW Forever: name-based spells (rank-proof), Classic+ rotation
- 2026-11-17 – 3-slot scrolling queue + active DoT strip
- 2026-11-17 – display only (no secure buttons): fixes `ADDON_ACTION_BLOCKED`, "Secure frame detected" and the position problem; follows the aura position
- 2026-11-17 – order per Icy Veins guide, skip DoTs on dying targets, wand (Shoot) finisher
- 2026-11-17 – "SWITCH TARGET" hint on dying targets with missing DoTs
- 2026-11-17 – DoT detection by spell ID: in combat the client hides aura names, so name lookups failed and DoTs stayed queued
- 2026-11-17 – DoT detection in three layers (name scan, spell-ID lookup with remembered IDs, local cast timer) because the debuff was not being found
- 2026-11-17 – debug readout off by default (`DEBUG` constant in `trigger.lua`)
