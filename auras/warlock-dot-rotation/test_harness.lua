-- Logic test for trigger.lua against a minimal WoW API mock (no game needed).
-- Run: luajit auras/warlock-dot-rotation/test_harness.lua auras/warlock-dot-rotation/trigger.lua
-- Simulates: aura data fully hidden (restricted), casts via UNIT_SPELLCAST_SUCCEEDED, time passing.
-- Not the real game: it only proves the queue logic, not API behaviour. Extend the mock per aura.
local now = 1000
local dummyMT = {}
dummyMT.__index = function(t, k)
  if type(k) == "string" and k:match("^%u") then return function(self, ...) return self end end
  return nil
end
local function Dummy() return setmetatable({}, dummyMT) end
function CreateFrame(kind, name) local f = Dummy(); f.shown=true
  f.Hide=function(s) s.shown=false end; f.Show=function(s) s.shown=true end
  f.SetShown=function(s,v) s.shown=v end; f.IsShown=function(s) return s.shown end
  f.CreateTexture=function() local t=Dummy(); t.SetTexture=function(s,v) s.tex=v end; return t end
  f.CreateFontString=function() local t=Dummy(); t.SetText=function(s,v) s.text=v end; t.SetShown=function(s,v) s.shown=v end; return t end
  if name then _G[name]=f end; return f end
UIParent = Dummy(); STANDARD_TEXT_FONT = "x"
local known = { ["Bane of Agony"]=true, ["Corruption"]=true, ["Immolate"]=true, ["Shadow Bolt"]=true, ["Life Tap"]=true, ["Drain Soul"]=true, ["Shoot"]=true }
local idname = { [980]="Bane of Agony", [172]="Corruption", [707]="Immolate", [695]="Shadow Bolt" }
C_Spell = {
  GetSpellInfo=function(n) return known[n] and {name=n} or nil end,
  GetSpellName=function(id) return idname[id] end,
  GetSpellTexture=function(n) return "tex:"..tostring(n) end,
  GetSpellCooldown=function() return {startTime=0,duration=0} end,
  IsSpellUsable=function() return true end,
}
RESTRICTED = true
C_Secrets = { ShouldAurasBeSecret=function() return RESTRICTED end }
C_UnitAuras = { GetAuraDataByIndex=function() return nil end, GetUnitAuraBySpellID=function() return nil end }
function GetTime() return now end
function UnitExists() return true end
function UnitCanAttack() return true end
function UnitIsDead() return false end
function UnitCastingInfo() return nil end
function UnitChannelInfo() return nil end
function UnitHealth() return 90 end
function UnitHealthMax() return 100 end
function UnitPower() return 90 end
function UnitPowerMax() return 100 end
function UnitGUID() return "Creature-0-1" end
function InCombatLockdown() return true end
-- pcall-free load of the trigger
local src = io.open(arg[1]):read("*a")
local fn = assert(load("return " .. src))()
aura_env = { region = Dummy() }
local function names() local b=_G["FAWarlockRotBox5"]; local t={}
  for i=1,3 do t[#t+1]=tostring(b.slots[i].spell) end; return table.concat(t," | ") end
fn("FRAME_UPDATE");                         print("initial          :", names())
fn("UNIT_SPELLCAST_SUCCEEDED","player","g",980); print("after Agony cast :", names())
fn("UNIT_SPELLCAST_SUCCEEDED","player","g",172); print("after Corr cast  :", names())
fn("UNIT_SPELLCAST_SUCCEEDED","player","g",707); print("after Immo cast  :", names())
now = now + 20; fn("FRAME_UPDATE");          print("+20s (Corr/Immo expired):", names())
now = now + 10; fn("FRAME_UPDATE");          print("+30s (Agony expired too):", names())
