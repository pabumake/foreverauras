-- Custom trigger (type: Status, events: PLAYER_TARGET_CHANGED, SPELLS_CHANGED, FRAME_UPDATE, UNIT_SPELLCAST_SUCCEEDED:player)
-- WoW Forever (Classic+) warlock rotation queue (display only, no secure frames).
--  * QUEUE (3 icons): the spell to cast NOW (big, yellow border) plus the next 2 after it.
--    When you cast, the queue scrolls.
--  * ACTIVE strip (small, below): your DoTs that are currently running, with a cooldown swipe + seconds
--    left, so you can see when they need recasting. They are not in the queue while running.
-- Position: drag the aura in WeakAuras; the queue is centered on it.
-- Spells are matched by NAME (not ID). Names are English; on another client language change them in ROTATION.
function(event, unit, castGUID, spellID)
    local env = aura_env
    local region = env.region
    if not region then return false end

    local VERSION = 5
    local DEBUG = false  -- shows what the aura sees (per DoT: which layer found it, seconds left; target debuffs). Set false when done.
    local SLOT_SIZE = { 48, 38, 38 }            -- sizes of the 3 queue slots
    local GAP, ACT_SIZE = 6, 30
    -- Priority order, top = most important.
    --   dot = track my debuff; ids = ALL rank spell IDs of the debuff (needed: in combat the client hides aura
    --         names, only a lookup by spell ID works); base = full duration (sec, only for the local-timer fallback); refresh = (re)queue when this many sec remain
    --         (a dot is NOT queued on a dying target: see DYING)
    --   mana = utility, queued only when mana% below this (and own health > 50%)
    --   execute = queued only when target health% at or below this
    --   filler = queued whenever ready
    local DYING = 25   -- target health % at or below which new DoTs are not worth it (it dies before they tick)
    local ROTATION = {
        { name = "Life Tap",       mana = 25 },
        { name = "Bane of Agony",  dot = true, base = 24, refresh = 2, ids = { 980, 1014, 6217, 11711, 11712, 11713 } },
        { name = "Corruption",     dot = true, base = 18, refresh = 2, ids = { 172, 6222, 6223, 7648, 11671, 11672, 25311 } },
        { name = "Siphon Life",    dot = true, base = 30, refresh = 2, ids = { 18265, 18879, 18880, 18881 } },
        { name = "Immolate",       dot = true, base = 15, refresh = 2, ids = { 348, 707, 1094, 2941, 11665, 11667, 11668, 25309 } },
        { name = "Drain Soul",     execute = 25 },
        { name = "Shoot",          execute = 25 },   -- wand: finish low-health mobs without spending mana
        { name = "Shadow Bolt",    filler = true },
    }

    local isSecret = function(v) return issecretvalue and issecretvalue(v) end
    local function known(name)
        if C_Spell and C_Spell.GetSpellInfo then return C_Spell.GetSpellInfo(name) ~= nil end
        return GetSpellInfo(name) ~= nil
    end

    -- Named frames so re-imports reuse them (/reload after updating from an older version removes the old ones).
    local NAME = "FAWarlockRotBox" .. VERSION
    local box = _G[NAME]
    if not box then
        local totalW = -GAP
        for _, s in ipairs(SLOT_SIZE) do totalW = totalW + s + GAP end
        box = CreateFrame("Frame", NAME, UIParent)
        box:SetFrameStrata("MEDIUM")
        box:SetSize(totalW, SLOT_SIZE[1])
        box.slots, box.act = {}, {}
        local left = 0
        for i, size in ipairs(SLOT_SIZE) do
            local f = CreateFrame("Frame", nil, box)
            f:SetSize(size, size)
            f:SetPoint("LEFT", box, "LEFT", left, 0)
            left = left + size + GAP
            if i == 1 then
                local br = f:CreateTexture(nil, "BACKGROUND")
                br:SetColorTexture(1, 0.85, 0, 1)
                br:SetPoint("TOPLEFT", -2, 2)
                br:SetPoint("BOTTOMRIGHT", 2, -2)
            end
            f.icon = f:CreateTexture(nil, "ARTWORK")
            f.icon:SetAllPoints()
            f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            f:Hide()
            box.slots[i] = f
        end
    end
    box:ClearAllPoints()
    box:SetPoint("CENTER", region, "CENTER", 0, 0)
    if not box.hint then   -- "switch target" label above the queue (created lazily, so no /reload needed)
        local h = box:CreateFontString(nil, "OVERLAY")
        h:SetFont(STANDARD_TEXT_FONT, 18, "OUTLINE")
        h:SetPoint("BOTTOM", box, "TOP", 0, 8)
        h:SetTextColor(1, 0.55, 0.1)
        h:SetText("SWITCH TARGET")
        h:Hide()
        box.hint = h
    end

    -- ---- DoT tracking: three layers, first hit wins -------------------------------------------------
    --  1. scan the target's debuffs by index and match by NAME (only possible while auras are not "secret");
    --     the spell IDs found this way are remembered (env.saved) for layer 2.
    --  2. lookup by spell ID (static list + remembered): the only thing that works while auras are secret.
    --  3. local timer: started when your cast SUCCEEDS (duration = base). An estimate (it cannot see a
    --     resist/dispel), but it keeps the queue working if the client's aura data is unreadable.
    local saved = env.saved or {}
    env.saved = saved
    saved.ids = saved.ids or {}
    box.timers = box.timers or {}
    local locked = C_Secrets and type(C_Secrets.ShouldAurasBeSecret) == "function"
    local function tkey()
        local g = UnitGUID("target")
        if g and not isSecret(g) then return g end
        return "target"
    end

    if event == "PLAYER_TARGET_CHANGED" then box.timers["target"] = nil end
    if event == "UNIT_SPELLCAST_SUCCEEDED" and spellID and not isSecret(spellID) then
        local sname = C_Spell.GetSpellName(spellID)
        for _, e in ipairs(ROTATION) do
            if e.dot and e.name == sname then
                local k = tkey()
                box.timers[k] = box.timers[k] or {}
                box.timers[k][sname] = GetTime() + e.base
            end
        end
    end

    local function isMine(d)
        local m = d.isFromPlayerOrPlayerPet
        if m ~= nil and not isSecret(m) then return m end
        local su = d.sourceUnit
        if su == nil or isSecret(su) then return true end
        return su == "player" or su == "pet"
    end

    -- returns remaining, duration, expiration. rem nil = missing, -1 = present but unreadable
    local function dotInfo(e)
        local data, layer
        local restricted = locked and C_Secrets.ShouldAurasBeSecret()
        -- 1. by name via index scan
        if not restricted and C_UnitAuras.GetAuraDataByIndex then
            for i = 1, 80 do
                local d = C_UnitAuras.GetAuraDataByIndex("target", i, "HARMFUL")
                if not d then break end
                if not isSecret(d.name) and d.name == e.name and isMine(d) then
                    data, layer = d, "scan"
                    if d.spellId and not isSecret(d.spellId) then
                        saved.ids[e.name] = saved.ids[e.name] or {}
                        saved.ids[e.name][d.spellId] = true
                    end
                    break
                end
            end
        end
        -- 2. by spell ID (static list + remembered)
        if not data then
            local function try(id)
                local d = C_UnitAuras.GetUnitAuraBySpellID("target", id)
                if d then
                    if isSecret(d) then return -1 end
                    if isMine(d) then data, layer = d, "id" end
                end
            end
            for _, id in ipairs(e.ids or {}) do
                if try(id) == -1 then return -1 end
                if data then break end
            end
            if not data and saved.ids[e.name] then
                for id in pairs(saved.ids[e.name]) do
                    if try(id) == -1 then return -1 end
                    if data then break end
                end
            end
        end
        if data then
            local exp, dur = data.expirationTime, data.duration
            if exp == nil or isSecret(exp) then return -1, nil, nil, layer .. "?" end
            if exp == 0 then return 9999, nil, nil, layer end
            return exp - GetTime(), (dur and not isSecret(dur)) and dur or nil, exp, layer
        end
        -- 3. local timer
        local t = box.timers[tkey()]
        local exp = t and t[e.name]
        if exp and exp > GetTime() then return exp - GetTime(), e.base, exp, "timer" end
        return nil
    end

    local function spellReady(name)
        local cd = C_Spell.GetSpellCooldown(name)
        if not cd or isSecret(cd.startTime) or isSecret(cd.duration) then return true end
        if cd.duration == 0 then return true end
        return (cd.startTime + cd.duration - GetTime()) <= 0.3 -- ~GCD
    end
    local function usable(name)
        local ok = C_Spell.IsSpellUsable(name)
        if isSecret(ok) then return true end
        return ok and true or false
    end
    local function pct(unit)
        local hp, mx = UnitHealth(unit), UnitHealthMax(unit)
        if not hp or not mx or isSecret(hp) or isSecret(mx) or mx == 0 then return nil end
        return hp / mx * 100
    end
    local function manaPct()
        local p, mx = UnitPower("player", 0), UnitPowerMax("player", 0)
        if not p or not mx or isSecret(p) or isSecret(mx) or mx == 0 then return nil end
        return p / mx * 100
    end

    if DEBUG and not box.dbg then
        local t = box:CreateFontString(nil, "OVERLAY")
        t:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
        t:SetPoint("TOP", box, "BOTTOM", 0, -60)
        t:SetJustifyH("LEFT")
        t:SetTextColor(0.7, 1, 0.7)
        box.dbg = t
    end
    if box.dbg then box.dbg:SetShown(DEBUG) end

    -- small icon for a running DoT
    local function actIcon(name)
        local f = box.act[name]
        if not f then
            f = CreateFrame("Frame", nil, box)
            f:SetSize(ACT_SIZE, ACT_SIZE)
            f.icon = f:CreateTexture(nil, "ARTWORK")
            f.icon:SetAllPoints()
            f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            f.icon:SetTexture(C_Spell.GetSpellTexture(name))
            f.cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
            f.cd:SetAllPoints()
            f.cd:SetDrawEdge(false)
            f.cd:SetHideCountdownNumbers(true)
            f.txt = f:CreateFontString(nil, "OVERLAY")
            f.txt:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
            f.txt:SetPoint("CENTER", 0, 0)
            f:Hide()
            box.act[name] = f
        end
        return f
    end

    local function refresh()
        local show = UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDead("target")
        if not show then
            box:Hide()
            box.hint:Hide()
            return true -- keep the (invisible) region active so you can always select and drag it
        end
        box:Show()

        local casting = UnitCastingInfo("player") or UnitChannelInfo("player")
        local tHP, myMana, myHP = pct("target"), manaPct(), pct("player")
        local queue, active = {}, {}
        local missingDot = false
        local dbg
        if DEBUG then
            local restricted = locked and C_Secrets.ShouldAurasBeSecret()
            dbg = { restricted and "AURAS SECRET (name scan impossible)" or "auras readable" }
            if not restricted and C_UnitAuras.GetAuraDataByIndex then
                local seen = {}
                for i = 1, 40 do
                    local d = C_UnitAuras.GetAuraDataByIndex("target", i, "HARMFUL")
                    if not d then break end
                    seen[#seen + 1] = (isSecret(d.name) and "?" or tostring(d.name)) .. "#" .. ((d.spellId and not isSecret(d.spellId)) and d.spellId or "?")
                end
                dbg[#dbg + 1] = "target debuffs: " .. (#seen > 0 and table.concat(seen, ", ") or "(none)")
            end
        end
        for _, e in ipairs(ROTATION) do
            if known(e.name) and spellReady(e.name) and usable(e.name) then
                local needs = false
                if e.dot then
                    local rem, dur, exp, layer = dotInfo(e)
                    if dbg then dbg[#dbg + 1] = string.format("%s: %s", e.name, rem == nil and "MISSING" or (tostring(layer) .. " " .. string.format("%.1f", rem))) end
                    if rem ~= nil and rem > e.refresh or rem == -1 then
                        -- running (or unreadable): not queued, shown in the active strip
                        active[#active + 1] = { name = e.name, rem = rem, dur = dur, exp = exp }
                    else
                        if rem == nil then missingDot = true end
                        -- missing or about to expire; not if I'm already casting it or the target is nearly dead
                        needs = (casting ~= e.name) and not (tHP ~= nil and tHP <= DYING)
                    end
                elseif e.mana then
                    needs = myMana ~= nil and myMana < e.mana and (myHP or 100) > 50
                elseif e.execute then
                    needs = tHP ~= nil and tHP <= e.execute
                else
                    needs = e.filler and true or false
                end
                if needs and #queue < 3 then queue[#queue + 1] = e.name end
            end
        end

        if dbg and box.dbg then box.dbg:SetText(table.concat(dbg, "\n")) end

        -- hint: target is nearly dead, so a missing DoT won't pay off here; start them on the next mob
        box.hint:SetShown(tHP ~= nil and tHP <= DYING and missingDot)

        for i = 1, 3 do
            local f, name = box.slots[i], queue[i]
            if name then
                if f.spell ~= name then f.icon:SetTexture(C_Spell.GetSpellTexture(name)); f.spell = name end
                f:Show()
            else
                f.spell = nil; f:Hide()
            end
        end

        -- active strip below the queue
        local used = {}
        local n = #active
        for i, a in ipairs(active) do
            local f = actIcon(a.name)
            used[a.name] = true
            f:ClearAllPoints()
            f:SetPoint("TOP", box, "BOTTOM", (i - (n + 1) / 2) * (ACT_SIZE + GAP), -10)
            if a.rem and a.rem >= 0 and a.dur and a.exp then
                if f.exp ~= a.exp then f.cd:SetCooldown(a.exp - a.dur, a.dur); f.exp = a.exp end
                f.txt:SetText(a.rem < 100 and string.format("%.0f", a.rem) or "")
            else
                f.cd:Clear(); f.exp = nil; f.txt:SetText("")
            end
            f:Show()
        end
        for name, f in pairs(box.act) do if not used[name] then f:Hide(); f.exp = nil end end
        return true
    end

    -- fast independent driver, ~10x/sec
    local DN = NAME .. "Driver"
    local d = _G[DN]
    if not d then
        d = CreateFrame("Frame", DN)
        d.acc = 0
        d:SetScript("OnUpdate", function(self, elapsed)
            self.acc = self.acc + elapsed
            if self.acc >= 0.1 and self.fn then self.acc = 0; self.fn() end
        end)
    end
    d.fn = refresh
    return refresh()
end
