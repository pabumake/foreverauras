-- Logic test for trigger.lua against a minimal WoW API mock (no game needed).
-- Run: luajit auras/universal-cast-bar/test_harness.lua auras/universal-cast-bar/trigger.lua
-- Covers: cast, pushback, stray FAILED of another cast, interrupt, success fade, channel ticks, latency,
-- and a fully secret (hidden) target cast. Proves queue/state logic only, not real client behaviour.
local now = 1000
local fails, passes = 0, 0
local function check(cond, msg) if cond then passes = passes + 1 else fails = fails + 1; print("FAIL: " .. msg) end end

-- ---- mock frames --------------------------------------------------------------------------------------
local function mk(kind)
  local f = { kind = kind, alpha = 1, shown = true, scripts = {}, calls = {} }
  local M = {
    SetAlpha = function(s, a) s.alpha = a end, GetAlpha = function(s) return s.alpha end,
    SetText = function(s, t) s.text = t end, GetText = function(s) return s.text end,
    Show = function(s) s.shown = true end, Hide = function(s) s.shown = false end,
    SetShown = function(s, v) s.shown = v end, IsShown = function(s) return s.shown end,
    SetScript = function(s, n, fn) s.scripts[n] = fn end,
    GetWidth = function() return 238 end,
    SetWidth = function(s, w) s.width = w end,
    SetStatusBarColor = function(s, r, g, b) s.color = { r, g, b } end,
    SetTimerDuration = function(s, d, i, dir) s.timer = d; s.dir = dir; s.timerCalls = (s.timerCalls or 0) + 1 end,
    SetValue = function(s, v) s.value = v end,
    SetTexture = function(s, t) s.tex = t end,
    GetStatusBarTexture = function(s) s.fill = s.fill or mk("tex"); return s.fill end,
    CreateTexture = function() return mk("tex") end,
    CreateFontString = function() return mk("fs") end,
    SetColorTexture = function() end,
  }
  return setmetatable(f, { __index = function(t, k)
    if M[k] then return M[k] end
    if type(k) == "string" and k:match("^%u") then return function(self) return self end end
  end })
end
function CreateFrame(kind, name) local f = mk(kind); if name then _G[name] = f end; return f end
UIParent = mk(); STANDARD_TEXT_FONT = "x"; CreateColor = function() return {} end

-- ---- mock API -----------------------------------------------------------------------------------------
Enum = { StatusBarInterpolation = { Immediate = 0 }, StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 },
         DurationTimeModifier = { RealTime = 1 }, NumericRuleFormatRounding = { Up = 1 } }
function issecretvalue(v) return type(v) == "table" and v.__secret == true end
local function Dur(total, secret)
  return { total = total, secret = secret, t0 = now,
    HasSecretValues = function(s) return s.secret end,
    GetTotalDuration = function(s) return s.total end,
    GetRemainingDuration = function(s) return s.total - (now - s.t0) end,
    SetTimeSpan = function(s, a, b) s.span = { a, b } end,
    FormatRemainingDuration = function(s) return string.format("%.1f", s.total - (now - s.t0)) end }
end
C_DurationUtil = { CreateDuration = function() return Dur(0) end }
C_StringUtil = { CreateNumericRuleFormatter = function() return { SetBreakpoints = function() end } end }
local evalCalls = 0
C_CurveUtil = { EvaluateColorValueFromBoolean = function(b, t, f) evalCalls = evalCalls + 1; return 0.5 end }
C_Spell = { GetSpellCooldown = function() return { startTime = now, duration = 1.5 } end }
WeakAuras = { IsOptionsOpen = function() return false end }
function GetTime() return now end

CAST = nil   -- { kind="cast"|"channel", name=, tex=, notInt=, id=, dur=Dur, secret=bool }
function UnitCastingInfo() if CAST and CAST.kind == "cast" then return CAST.name, "", CAST.tex, 0, 0, false, CAST.id, CAST.notInt, 1 end end
function UnitChannelInfo() if CAST and CAST.kind == "channel" then return CAST.name, "", CAST.tex, 0, 0, false, CAST.notInt, 1 end end
function UnitCastingDuration() return CAST and CAST.kind == "cast" and CAST.dur or nil end
function UnitChannelDuration() return CAST and CAST.kind == "channel" and CAST.dur or nil end

-- ---- load ---------------------------------------------------------------------------------------------
local function load_trigger(unit)
  local src = io.open(arg[1]):read("*a")
  if unit then src = src:gsub('local UNIT = "player"', 'local UNIT = "' .. unit .. '"', 1) end
  aura_env = { region = mk() }
  return assert(load("return " .. src))()
end
local function drive(fn, box, secs)   -- run OnUpdate for secs
  local steps = math.floor(secs / 0.05)
  for _ = 1, steps do now = now + 0.05; box.scripts.OnUpdate(box, 0.05) end
end

-- ---- scenarios: player --------------------------------------------------------------------------------
local fn = load_trigger("player")
fn("PLAYER_ENTERING_WORLD")
local box = _G["FACastBar_player_1"]
check(box ~= nil, "box frame created and named")
check(box.alpha == 0, "hidden with no cast")

-- latency: SENT 0.1s before START
fn("UNIT_SPELLCAST_SENT", "player", "tgt", "g1", 1)
now = now + 0.1
CAST = { kind = "cast", name = "Shadow Bolt", tex = 136197, notInt = false, id = "g1", dur = Dur(2.5) }
fn("UNIT_SPELLCAST_START", "player", "g1", 1)
check(box.st.active and box.st.kind == "cast", "cast bound")
check(box.nameText.text == "Shadow Bolt", "name shown")
check(box.bar.timer == CAST.dur and box.bar.dir == 0, "bar driven by duration object, filling (elapsed)")
check(box.lat.shown, "latency segment shown")
drive(fn, box, 0.5)
check(box.timerText.text == "2.0", "timer text updates (got " .. tostring(box.timerText.text) .. ")")
check(box.alpha == 1, "faded in")

-- pushback
local oldDur = CAST.dur
CAST.dur = Dur(2.9)
fn("UNIT_SPELLCAST_DELAYED", "player", "g1", 1)
check(box.bar.timer == CAST.dur and box.bar.timer ~= oldDur, "pushback rebinds the new duration")

-- stray FAILED of a different cast (spamming a key) must not kill the current cast
fn("UNIT_SPELLCAST_FAILED", "player", "g-other", 1)
drive(fn, box, 0.1)
check(box.st.active and not box.st.endKind, "FAILED for another cast ignored")

-- success
CAST = nil
fn("UNIT_SPELLCAST_STOP", "player", "g1", 1)
check(not box.st.active and box.st.fade and box.st.fade.kind == "success", "finished as success")
check(box.alpha == 1, "holds briefly at end")
drive(fn, box, 1.0)
check(box.alpha == 0 and not box.st.fade, "fades out completely")

-- interrupt (INTERRUPTED then STOP, as the client sends them)
CAST = { kind = "cast", name = "Fireball", tex = 135812, notInt = false, id = "g2", dur = Dur(3) }
fn("UNIT_SPELLCAST_START", "player", "g2", 2)
drive(fn, box, 0.3)
fn("UNIT_SPELLCAST_INTERRUPTED", "player", "g2", 2)
CAST = nil
fn("UNIT_SPELLCAST_STOP", "player", "g2", 2)
check(box.st.fade and box.st.fade.kind == "interrupted" and box.nameText.text == "Interrupted", "interrupt shown")
check(box.bar.color[1] == 0.90, "interrupt colour red")
drive(fn, box, 1.0)

-- STOP arriving before INTERRUPTED still ends as interrupted
CAST = { kind = "cast", name = "Fireball", tex = 135812, notInt = false, id = "g3", dur = Dur(3) }
fn("UNIT_SPELLCAST_START", "player", "g3", 2); drive(fn, box, 0.2)
CAST = nil
fn("UNIT_SPELLCAST_STOP", "player", "g3", 2)
fn("UNIT_SPELLCAST_INTERRUPTED", "player", "g3", 2)
check(box.st.fade and box.st.fade.kind == "interrupted", "late INTERRUPTED upgrades the finish")
drive(fn, box, 1.0)

-- channel with ticks, draining direction
CAST = { kind = "channel", name = "Drain Life", tex = 136169, notInt = false, dur = Dur(5) }
fn("UNIT_SPELLCAST_CHANNEL_START", "player", "g4", 3)
check(box.st.kind == "channel" and box.bar.dir == 1, "channel drains (remaining direction)")
local visible = 0; for _, t in ipairs(box.ticks) do if t.shown then visible = visible + 1 end end
check(visible == 4, "Drain Life shows 4 tick dividers (got " .. visible .. ")")
check(box.bar.color[2] == 0.85, "channel colour green")
CAST = nil; fn("UNIT_SPELLCAST_CHANNEL_STOP", "player", "g4", 3); drive(fn, box, 1.0)

-- cast already running when the aura starts (reload): picked up by polling
CAST = { kind = "cast", name = "Immolate", tex = 135817, notInt = false, id = "g5", dur = Dur(2) }
drive(fn, box, 0.1)
check(box.st.active and box.nameText.text == "Immolate", "cast found by polling without a start event")
CAST = nil; drive(fn, box, 0.1); drive(fn, box, 1.0)

-- ---- scenarios: target with fully hidden (secret) data -------------------------------------------------
local fn2 = load_trigger("target")
fn2("PLAYER_TARGET_CHANGED")
local box2 = _G["FACastBar_target_1"]
local S = function(v) return { __secret = true, v = v } end
CAST = { kind = "cast", name = S("Pyroblast"), tex = S(135808), notInt = S(true), id = S("x"), dur = Dur(2, true) }
evalCalls = 0
fn2("UNIT_SPELLCAST_START", "target", S("x"), S(11366))
check(box2.st.active, "secret cast still gets a bar")
check(box2.nameText.text == CAST.name, "secret name passed straight to the widget")
check(evalCalls == 3, "interruptible colour from the secret boolean via curve API, never read (calls=" .. evalCalls .. ")")
drive(fn2, box2, 0.3)
check(box2.timerText.text and box2.timerText.text ~= "", "timer text via duration object formatter")
check(not box2.lat.shown and not box2.ticks[1], "no latency/ticks for hidden casts")
fn2("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "target")
CAST = nil; fn2("UNIT_SPELLCAST_STOP", "target", S("x"), S(1)); drive(fn2, box2, 1.0)
-- target switch resets
CAST = { kind = "cast", name = S("A"), tex = S(1), notInt = S(false), id = S("y"), dur = Dur(2, true) }
fn2("UNIT_SPELLCAST_START", "target", S("y"), S(1))
fn2("PLAYER_TARGET_CHANGED")
check(not box2.st.active and box2.alpha == 0, "target change clears the bar")
CAST = nil

print(string.format("%d passed, %d failed", passes, fails))
os.exit(fails == 0 and 0 or 1)
