# WoW Forever notes

WoW: Forever is Blizzard's official Classic+ project: vanilla-based content (level cap 60), on the modern client API. The addon is a WeakAuras fork called ForeverAuras (v1.4.3 at time of writing). Third-party guide sites call it beta; spell data may change.

## Consequences for auras
- **Ranks.** Spells have ranks with different IDs (e.g. Immolate 348, 707, 1094, 2941, 11665, 11667, 11668, 25309). Match spells by **name** (`C_Spell.GetSpellInfo(name)`, cast with `type=spell, spell=<name>` = highest rank). Use ID lists only where the API needs IDs (see below).
- **Spell cache with all rank IDs.** `SavedVariables/ForeverAurasOptions.lua` has entries like `["Corruption"] = { ["spells"] = "172=136118,6222=...", }` (spellID=iconID). Good source for rank IDs of spells you have seen.
- **Names differ from retail/Classic.** Curse of Agony is **Bane of Agony** here; Agony/Unstable Affliction/Haunt do not exist. Curse of Shadow and Dark Pact are removed. New: Wrack (Affliction talent), Bane of Havoc (Destruction talent). Verify names against the spellbook; English only.
- **Aura data is hidden ("secret") in combat.** `C_Secrets.ShouldAurasBeSecret()` is true then. While true: scanning by index raises, aura names/IDs are secret values, name lookups find nothing; only `C_UnitAuras.GetUnitAuraBySpellID(unit, id)` can still work (this is what `BuffTrigger2.lua` does, see `SafeForEachAura`). Check with `issecretvalue(v)` before comparing/formatting values. Observed with DoT Ledger's debug: `auras=restricted` right after a cast in combat, `readable` later.
- **Target debuff timers are therefore unreliable in combat.** The working approach is layered (name scan when readable, ID lookup, local timer from `UNIT_SPELLCAST_SUCCEEDED`), see [warlock-dot-rotation.md](warlock-dot-rotation.md). A local timer cannot see resists/dispels; it is an estimate (DoT Ledger does the same and marks estimates `~`).
- **Secure frames** (click-to-cast) are restricted in combat as everywhere in WoW: [secure-frames.md](secure-frames.md).

## Web sources: what worked, what did not
| Source | Result |
|--------|--------|
| metabot.gg/en/wow-forever/changes/warlock | Works. Rank tables, changed/new abilities. Two of its pages disagree with rankedboost on Wrack numbers. |
| rankedboost.com/world-of-warcraft/forever/class/warlock | Works. Spell list with learn levels. |
| warcraft.wiki.gg (e.g. /wiki/Bane_of_Agony) | Works. Name, duration, only rank 1 and 6 IDs, debuff ID not stated. |
| icy-veins.com (guides) | **HTTP 403 for direct fetch.** Search-result excerpts (WebSearch with `allowed_domains`) still give a summary of the rotation/leveling guide. Treat as secondhand. |
| curseforge.com addon pages | Works (e.g. DoT Ledger, a Forever addon: shows `/dl debug`, uses readable aura data else cast-based estimates). No source link. |
| wowhead / wago.io | Searches returned nothing usable for Forever. |
Do not retry a URL that returned 403.

## Useful in-game commands
- `/dump C_Secrets.ShouldAurasBeSecret()` auras currently hidden?
- `/run for i=1,20 do local a=C_UnitAuras.GetDebuffDataByIndex("target",i) if not a then break end print(i,a.name,a.spellId) end` list target debuffs (only works while readable).
- `/dl debug` (DoT Ledger addon) prints what it can read.
