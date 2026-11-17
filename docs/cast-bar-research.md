# Cast bar research (WoW Forever)

Research behind `auras/universal-cast-bar/`. Verified items cite the installed ForeverAuras source (`<addon>` = path in weakauras-workflow.md) or a web page; everything marked **UNVERIFIED** is an assumption that only the game can confirm.

## 1. What data exists for casts
| Unit | Readable? | Evidence |
|------|-----------|----------|
| `player` (own casts, incl. pets) | Yes, also in combat | `<addon>/Prototypes.lua` `Private.CastCombatStatus` returns "Works in combat" for player; Blizzard 12.0 notes (Alpha 6, Nov 4): own spellcasts no longer secret, "Units controlled by the player (including pets) are also included" |
| `target`, `focus`, any other unit | **Name, icon, spell ID, interruptible flag are secret**, in and out of combat on this server. Timers are available as a DurationObject. | `<addon>/Prototypes.lua` ~2489 comment: "on this server another unit's spell is secret in and out of combat (probed in game)"; the trigger there falls back to `UnitCastingDuration` / `UnitChannelDuration` when `hasanysecretvalues(spell, startTime, endTime, stageTotal)` |

Consequences: a bar for another unit cannot filter by spell, cannot show tick marks/latency (needs total length), but CAN show a bar, a countdown and (via curve API) an interruptible colour, and can pass the secret name/icon straight into widgets.

## 2. API toolbox (Patch 12.0 / Midnight client, used by Forever)
- `UnitCastingInfo(unit)` -> `name, text, texture, startTimeMs, endTimeMs, isTradeskill, castID, notInterruptible, spellID, ...`
- `UnitChannelInfo(unit)` -> `name, text, texture, startTimeMs, endTimeMs, isTradeskill, notInterruptible, spellID, isEmpowered, numStages`. Note the flag position differs from casts (7th vs 8th). `<addon>/Prototypes.lua` 8678-8730 names the cast flag `interruptible` but it IS `notInterruptible`.
- `UnitCastingDuration(unit)` / `UnitChannelDuration(unit)` -> **DurationObject** (secret-safe). Also `UnitEmpoweredChannelDuration`, `UnitEmpoweredStageDurations` (Forever is vanilla-based, no empower; not used).
- `StatusBar:SetTimerDuration(duration, interpolation, direction)`; `Enum.StatusBarInterpolation` Immediate=0 / ExponentialEaseOut=1; `Enum.StatusBarTimerDirection` ElapsedTime=0 (fills) / RemainingTime=1 (drains, for channels). Used by `<addon>/ProgressTextureNative.lua:211`.
- DurationObject methods: `GetTotalDuration`, `GetRemainingDuration`, `GetElapsedDuration`, `HasSecretValues`, `SetTimeSpan(start, end)`, `FormatRemainingDuration(formatter, modifier)`, ... Create with `C_DurationUtil.CreateDuration()` (zero length). Source: warcraft.wiki.gg ScriptObject_DurationObject.
- **Time text from a hidden duration:** build a formatter with `C_StringUtil.CreateNumericRuleFormatter()`, `:SetBreakpoints({ {threshold=0, format=""}, {threshold=0.000001, format="%.1f"}, {threshold=10, format="%d", step=1, rounding=Enum.NumericRuleFormatRounding.Up} })`, then `duration:FormatRemainingDuration(formatter, Enum.DurationTimeModifier.RealTime)` returns a string you can hand to `FontString:SetText`. Pattern copied from `<addon>/DurationText.lua` 227-275.
- **Colour from a secret boolean:** `C_CurveUtil.EvaluateColorValueFromBoolean(secretBool, valueIfTrue, valueIfFalse)` per colour component (pattern in `<addon>/Conditions.lua` ~1046); `Region:SetAlphaFromBoolean(bool, alphaIfTrue, alphaIfFalse)` (12.0 notes, Dec 1).
- Spark/fill edge without reading values: anchor the spark to `bar:GetStatusBarTexture()` RIGHT edge; it follows the fill natively.
- Events: `UNIT_SPELLCAST_START/STOP/FAILED/FAILED_QUIET/INTERRUPTED/DELAYED/CHANNEL_START/CHANNEL_STOP/CHANNEL_UPDATE/INTERRUPTIBLE/NOT_INTERRUPTIBLE` (unit-filtered with `:unit`), `UNIT_SPELLCAST_SENT:player` (args `unit, target(secret), castGUID, spellID`), `PLAYER_TARGET_CHANGED`, `PLAYER_FOCUS_CHANGED`. START/STOP/FAILED args: `unit, castGUID, spellID`.
- Positioning preview: `WeakAuras.IsOptionsOpen()` (exists, `<addon>/ForeverAuras.lua:907`).
- Sandbox: no `pcall`/`xpcall` (`<addon>/AuraEnvironment.lua:237`), so risky calls cannot be wrapped; guard with `issecretvalue` and existence checks.

## 3. Vanilla-era behaviours to handle
- Pushback: `UNIT_SPELLCAST_DELAYED` (casts) / `CHANNEL_UPDATE` (channels) -> re-read the duration object.
- A `FAILED` event for a new attempt (spamming a key mid-cast) arrives while the first cast continues: compare `castGUID` with the active cast's before treating it as a failure.
- Event order on interrupt can be `INTERRUPTED` then `STOP` or the reverse: a late `INTERRUPTED` must upgrade an already-finished "success".
- A cast can already be running when the aura loads (reload, target change): poll `UnitCastingInfo/UnitChannelInfo`, do not rely on start events only.
- Classic quirk (Quartz maintainer): some ranged abilities (multishot, aimed shot) do not fire a start event; polling covers it too.
- Auto Shot / wand (Shoot) are auto-repeat, not casts: no bar (a swing/auto-shot timer is a different aura).

## 4. Existing cast bar addons (feature survey)
| Addon | Forever? | Notable |
|-------|----------|---------|
| Quartz Redux (v3.8.11, GPLv2, github NoSelph/Quartz) | Yes (listed) | player/target/focus, enemies in combat, GCD, latency, interruptible shown, tradeskill merge, range recolour. No stated secret-value approach. |
| nugsCastBars 0.12.0 | Yes (listed) | player/target/focus/pet/bosses, channel colour, non-interruptible shield+colour, latency tail, cast-target text, interrupt announcements. States for hidden casts: timed / secret / guessed (remembered length, "?") / unknown (sweep). Says empowered stages unknowable. |
| Pulsar Cast Bars | No (Retail/Classic only) | Quartz-based, spell-school colours, swing timer. |
| DoT Ledger | Yes | not a cast bar, same secret-data constraints. |
Gaps none of them list: tick marks, pushback behaviour. We add tick marks for own channels (table-driven) and pushback via re-binding.

## 5. Design decisions
- One trigger parameterised by `UNIT`; `aura.py` builds player/target/focus variants (`AURAS` dict -> `import-<unit>.txt`).
- Everything goes through the DurationObject path (works for readable and secret casts alike, handles pushback by re-binding).
- Colours: cast gold, channel green, non-interruptible steel (secret boolean through the curve API), interrupted/failed red, success green flash; hold 0.3 s then fade.
- Visuals only from WHITE8X8 + gradients (no reliance on legacy spark textures that may be missing).
- Display only, no secure frames (see secure-frames.md).
- Hide the default Blizzard bar via `SetUnit(nil)` + `UnregisterAllEvents()` + `Hide()` (reversible with `/reload`, off with `HIDE_BLIZZARD = false`).

## 6. UNVERIFIED assumptions (check in game first)
1. Passing a secret name/texture to `FontString:SetText` / `Texture:SetTexture` is allowed for addon code (ForeverAuras' own Cast trigger sets such values on its regions).
2. `StatusBar:SetStatusBarColor` accepts the (possibly secret) numbers returned by `EvaluateColorValueFromBoolean`.
3. `SetTimerDuration` with a frozen duration (`setStatic`) overrides a previous timer; `SetValue` alone might not.
4. Blizzard frame names `PlayerCastingBarFrame`, `TargetFrameSpellBar`, `FocusFrameSpellBar` exist in the Forever client (guarded, nothing happens if not).
5. GCD pseudo-spell 61304 works with `C_Spell.GetSpellCooldown` and is not secret for the player.
6. Tick counts for Drain Life (5) and Hellfire (15) come from Forever guide text (1 tick/s); other channels are not in the table.
7. Whether `C_CurveUtil.EvaluateColorValueFromBoolean(bool, a, b)` argument order is (true value, false value): copied from `<addon>/Conditions.lua`.

## Sources
- warcraft.wiki.gg: ScriptObject_DurationObject, API StatusBar_SetTimerDuration, API UnitCastingDuration, Patch_12.0.0/API_changes/notes
- curseforge.com: nugsCastBars, Quartz Redux (quartz-midnight), Pulsar Cast Bars
- Installed ForeverAuras source (files named above)
