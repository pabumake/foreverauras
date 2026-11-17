# Design record: Warlock DoT Rotation (`auras/warlock-dot-rotation/`)

Worked example of a **rotation queue + uptime tracker** aura. User-facing doc: `auras/warlock-dot-rotation/README.md`.

## Goal (as requested)
Show what to cast next for a warlock leveling in WoW Forever (character was level 12): the current spell plus the next two, scrolling as casts happen; running DoTs leave the queue and sit in a strip with a cooldown swipe; only known/ready spells; a "switch target" hint. Display only (see decision below).

## Final design
- Region: invisible 142x48 texture, Warlock-only load, kept active so it is always draggable. `box` frame anchored to the region holds 3 slot frames (48/38/38 px, slot 1 has a yellow border), an orange "SWITCH TARGET" label, and a strip of small DoT icons (30 px, `CooldownFrameTemplate` swipe + seconds text).
- Named global frames (`FAWarlockRotBox<VERSION>` + `...Driver`), a ~10 Hz `OnUpdate` driver calls `refresh()`; the trigger also runs it on events.
- `ROTATION` table (priority order): Life Tap (mana < 25% and health > 50%), Bane of Agony, Corruption, Siphon Life, Immolate, Drain Soul (target <= 25%), Shoot (wand, target <= 25%), Shadow Bolt (filler). Order of DoTs follows Icy Veins' Forever Affliction priority (Agony > Corruption > Siphon Life > Immolate).
- A DoT is queued when missing or <= `refresh` (2 s) left, and not while it is being cast, and not on a dying target (`DYING` = 25%: leveling guide says only DoT targets that survive most of the duration). A running DoT is shown in the strip instead.
- `SWITCH TARGET` shows when the target is dying and a DoT is missing.
- Spells matched by name; `known(name)` = `C_Spell.GetSpellInfo(name) ~= nil`; ready = cooldown <= ~GCD; usable = `C_Spell.IsSpellUsable`. Health/mana values are checked with `issecretvalue`.

## DoT tracking: three layers (the hard part)
Problem: in combat the client hides aura data, and the first versions looked debuffs up by name, found nothing, so every DoT looked missing and stayed first in the queue (Bane of Agony visibly). Layers, first hit wins:
1. Scan target debuffs by index, match by name, only when `ShouldAurasBeSecret()` is false. Remember the spell IDs seen in `aura_env.saved.ids`.
2. `C_UnitAuras.GetUnitAuraBySpellID("target", id)` over the static rank-ID list in `ROTATION` plus remembered IDs (the only lookup that works while secret). Own-debuff check via `isFromPlayerOrPlayerPet` / `sourceUnit`.
3. Local timer: `UNIT_SPELLCAST_SUCCEEDED:player` sets `expire = now + base` per DoT per target (key = target GUID, or `"target"` if the GUID is secret; cleared on target change).
Layer 3 is what made it work in game ("seems to work now"). It is an estimate and misses resists/dispels. Debug readout (`DEBUG = true`) prints per DoT which layer matched.

## History of failures (so they are not repeated)
| Symptom | Cause | Fix |
|---------|-------|-----|
| Spells from retail (Unstable Affliction, Haunt) | Wrong game: Forever is vanilla-based | Rotation rebuilt from Forever guides, name-based |
| "Secure frame detected" warning | Secure buttons anchored to WA region | Anchor to UIParent, then dropped secure frames entirely |
| `ADDON_ACTION_BLOCKED Frame:SetShown()` | Showing a wrapper of a secure button in combat | Display-only queue (no secure frames), see secure-frames.md |
| "overwritten the global" warning | `_G[NAME] = box` | Rely on named `CreateFrame`, read via `_G[NAME]` |
| Could not move the aura | Row anchored to screen, not region | Anchor to region (possible once nothing is secure) |
| Two rows on screen | Frames of old versions survive re-import | Named frames + `/reload` |
| Import error `Modernize.lua:2471 ... 'actions'` | `aura.py` had `internalVersion` 70 and no `actions` | `internalVersion` 91 + `actions` table |
| DoT never leaves slot 1 / returns while still applied | Aura data hidden in combat; lookup by name | Three-layer tracking above |

## Sources used
Metabot + RankedBoost (spell list, learn levels: Immolate 1, Corruption 4, Life Tap 6, Bane of Agony 8, Drain Soul 10, Siphon Life 30), Icy Veins Forever Affliction rotation and leveling guides (via search excerpts, direct fetch 403), warcraft.wiki.gg Bane of Agony, DoT Ledger addon page. Third-party, Forever is new: re-verify names/levels. The 25% thresholds, Shoot as finisher and the 2 s refresh window are the author's choices, not from a guide.

## Not done / ideas
- Nightfall proc (instant Shadow Bolt, level 25+; buff name in Forever unknown), Wrack (talent), Bane of Doom (level 60), Curse slot, Conflagrate for Destruction.
- Multi-target uptime tracking (nameplates). Judged unnecessary while leveling; the strip already shows uptimes on the current target.
- Other specs: change `ROTATION` (names, `ids`, `base`, conditions); the engine is spec-agnostic.
- Spell IDs for new DoTs: take them from `ForeverAurasOptions.lua` spell cache, or learn them in game (layer 1 remembers them).

## Adapting for another class/aura
1. Copy the folder. 2. Replace `ROTATION` entries; give every tracked DoT `ids` (all ranks) and `base`. 3. Adjust `load.class`. 4. Re-run the mock harness with the new spell names/IDs. 5. Check names in game; ship with `DEBUG = false`.
