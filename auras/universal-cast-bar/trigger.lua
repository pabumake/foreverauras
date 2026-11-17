-- Custom trigger (type: Status). Events are generated per unit by aura.py (UNIT_SPELLCAST_*:<unit> ...).
-- Universal cast bar for ONE unit (player / target / focus / pet ...): casts, channels, pushback,
-- interrupts, failures, latency (own casts), channel tick marks (own channels), GCD line (own casts).
-- Works with hidden ("secret") cast data: the bar is driven by the client's duration object, so other
-- units' casts still get a bar, a timer and an interruptible colour even though name/ID are unreadable
-- to addons (the client lets us pass them straight to widgets, we never compare or format them).
-- Display only (no secure frames). Position: drag the aura; the bar is centered on it.
function(event, unit, castGUID, spellID)
    local env = aura_env
    local region = env.region
    if not region then return false end

    -- ===== config =====================================================================================
    local UNIT = "player"            -- aura.py rewrites this for the target / focus builds
    local VERSION = 1
    local WIDTH, HEIGHT = 260, 22
    local SHOW_ICON, SHOW_NAME, SHOW_TIMER = true, true, true
    local SHOW_LATENCY, SHOW_GCD, SHOW_TICKS = true, true, true      -- own casts only (need readable data)
    local HIDE_BLIZZARD = true       -- hide the default Blizzard cast bar for this unit (/reload to undo)
    local FADE_IN, HOLD_END, FADE_OUT = 0.08, 0.30, 0.35
    local FONT_SIZE = 11
    local COLORS = {                 -- r, g, b
        cast            = { 1.00, 0.72, 0.18 },
        channel         = { 0.30, 0.85, 0.45 },
        uninterruptible = { 0.62, 0.64, 0.74 },
        success         = { 0.40, 0.90, 0.45 },
        interrupted     = { 0.90, 0.15, 0.15 },
        failed          = { 0.80, 0.25, 0.25 },
    }
    -- number of ticks of channels you cast (name -> ticks), draws divider marks. Add your own.
    local TICKS = {
        ["Drain Life"] = 5,          -- 5 s, 1 tick/s (Forever guides)
        ["Hellfire"]   = 15,         -- 15 s, 1 tick/s (Forever guides)
    }
    local GCD_SPELL = 61304          -- "Global Cooldown" pseudo-spell
    -- ==================================================================================================

    local isSecret = function(v) return issecretvalue and issecretvalue(v) end
    local WHITE = "Interface\\Buttons\\WHITE8X8"
    local NAME = "FACastBar_" .. UNIT .. "_" .. VERSION

    local box = _G[NAME]
    if not box then
        box = CreateFrame("Frame", NAME, UIParent)
        box:SetFrameStrata("MEDIUM")
        box:SetSize(WIDTH, HEIGHT)
        box:SetAlpha(0)

        local bd = CreateFrame("Frame", nil, box, "BackdropTemplate")
        bd:SetAllPoints(box)
        bd:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
        bd:SetBackdropColor(0.04, 0.04, 0.06, 0.78)
        bd:SetBackdropBorderColor(0, 0, 0, 1)
        box.bd = bd

        local left = 0
        if SHOW_ICON then
            local f = CreateFrame("Frame", nil, box)
            f:SetSize(HEIGHT, HEIGHT)
            f:SetPoint("LEFT", box, "LEFT", 0, 0)
            box.icon = f:CreateTexture(nil, "ARTWORK")
            box.icon:SetPoint("TOPLEFT", 1, -1)
            box.icon:SetPoint("BOTTOMRIGHT", -1, 1)
            box.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            box.icon:SetTexture(134400)
            left = HEIGHT
        end

        local bar = CreateFrame("StatusBar", nil, box)
        bar:SetPoint("TOPLEFT", box, "TOPLEFT", left + 1, -1)
        bar:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -1, 1)
        bar:SetStatusBarTexture(WHITE)
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
        box.bar = bar

        -- gloss: light at the top fading down
        local gloss = bar:CreateTexture(nil, "OVERLAY", nil, 1)
        gloss:SetAllPoints(bar)
        gloss:SetColorTexture(1, 1, 1, 1)
        if gloss.SetGradient and CreateColor then
            gloss:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0.00), CreateColor(1, 1, 1, 0.26))
        else
            gloss:SetAlpha(0.1)
        end

        -- spark: bright line on the fill edge with a soft trail behind it
        local fillTex = bar:GetStatusBarTexture()
        local trail = bar:CreateTexture(nil, "OVERLAY", nil, 2)
        trail:SetBlendMode("ADD")
        trail:SetSize(22, HEIGHT - 2)
        trail:SetColorTexture(1, 1, 1, 1)
        if trail.SetGradient and CreateColor then
            trail:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 0.00), CreateColor(1, 1, 1, 0.38))
        end
        trail:SetPoint("RIGHT", fillTex, "RIGHT", 0, 0)
        local spark = bar:CreateTexture(nil, "OVERLAY", nil, 3)
        spark:SetBlendMode("ADD")
        spark:SetSize(2, HEIGHT - 2)
        spark:SetColorTexture(1, 1, 1, 0.95)
        spark:SetPoint("CENTER", fillTex, "RIGHT", 0, 0)
        box.spark, box.trail = spark, trail

        -- latency segment (own casts), tick marks (own channels)
        box.lat = bar:CreateTexture(nil, "OVERLAY", nil, 4)
        box.lat:SetColorTexture(0.9, 0.1, 0.1, 0.55)
        box.lat:Hide()
        box.ticks = {}

        local nameText = bar:CreateFontString(nil, "OVERLAY")
        nameText:SetFont(STANDARD_TEXT_FONT, FONT_SIZE, "OUTLINE")
        nameText:SetPoint("LEFT", bar, "LEFT", 6, 0)
        nameText:SetPoint("RIGHT", bar, "RIGHT", -44, 0)
        nameText:SetJustifyH("LEFT")
        nameText:SetWordWrap(false)
        box.nameText = nameText
        local timerText = bar:CreateFontString(nil, "OVERLAY")
        timerText:SetFont(STANDARD_TEXT_FONT, FONT_SIZE, "OUTLINE")
        timerText:SetPoint("RIGHT", bar, "RIGHT", -5, 0)
        timerText:SetJustifyH("RIGHT")
        box.timerText = timerText

        -- GCD line under the bar (own casts); also shows for instant casts when the bar itself is hidden
        local gcd = CreateFrame("StatusBar", nil, UIParent)   -- own parent: visible even while the bar is faded out
        gcd:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -2)
        gcd:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", 0, -2)
        gcd:SetHeight(3)
        gcd:SetStatusBarTexture(WHITE)
        gcd:SetStatusBarColor(1, 1, 1, 0.55)
        gcd:Hide()
        box.gcd = gcd

        box.st = {}   -- cast state
    end
    box:ClearAllPoints()
    box:SetPoint("CENTER", region, "CENTER", 0, 0)
    local bar, st = box.bar, box.st

    -- ---- helpers --------------------------------------------------------------------------------------
    local function setColor(c, a) bar:SetStatusBarColor(c[1], c[2], c[3], a or 1) end

    -- colour for a live cast; notInt may be nil, a plain boolean or a SECRET boolean
    local function applyCastColor(kind, notInt)
        local c, u = COLORS[kind], COLORS.uninterruptible
        if notInt == nil then return setColor(c) end
        if isSecret(notInt) then
            local E = C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean
            if E then
                -- the client picks the component for us; we never read the boolean
                return bar:SetStatusBarColor(E(notInt, u[1], c[1]), E(notInt, u[2], c[2]), E(notInt, u[3], c[3]), 1)
            end
            return setColor(c)
        end
        setColor(notInt and u or c)
    end

    local function timerFormatter()
        if box.fmt == nil then
            if C_StringUtil and C_StringUtil.CreateNumericRuleFormatter and Enum and Enum.NumericRuleFormatRounding then
                local f = C_StringUtil.CreateNumericRuleFormatter()
                f:SetBreakpoints({
                    { threshold = 0, format = "" },
                    { threshold = 0.000001, format = "%.1f" },
                    { threshold = 10, format = "%d", step = 1, rounding = Enum.NumericRuleFormatRounding.Up },
                })
                box.fmt = f
            else
                box.fmt = false
            end
        end
        return box.fmt
    end

    local function hideDecor()
        box.lat:Hide()
        for _, t in ipairs(box.ticks) do t:Hide() end
        box.gcd:Hide()
    end

    local function hideBlizzard()
        if not HIDE_BLIZZARD or box.blizDone then return end
        local f = (UNIT == "player" and _G.PlayerCastingBarFrame) or (UNIT == "target" and _G.TargetFrameSpellBar)
                  or (UNIT == "focus" and _G.FocusFrameSpellBar) or nil
        if f then
            if f.SetUnit then f:SetUnit(nil) end
            f:UnregisterAllEvents()
            f:Hide()
            box.blizDone = true
        end
    end

    local function ensureTicks(n)
        local W = bar:GetWidth()
        for i = 1, math.max(#box.ticks, n - 1) do
            if not box.ticks[i] then
                local t = bar:CreateTexture(nil, "OVERLAY", nil, 5)
                t:SetColorTexture(0, 0, 0, 0.8)
                t:SetSize(1, HEIGHT - 2)
                box.ticks[i] = t
            end
        end
        for i, t in ipairs(box.ticks) do
            if i < n then
                t:ClearAllPoints()
                t:SetPoint("LEFT", bar, "LEFT", W * i / n, 0)
                t:Show()
            else
                t:Hide()
            end
        end
    end

    -- fill the bar to a fixed fraction (0..1) with a frozen duration object. SetValue alone may not override
    -- the bar's timer mode, so finished / preview states go through the same SetTimerDuration path.
    local function setStatic(frac)
        if C_DurationUtil and C_DurationUtil.CreateDuration and Enum and bar.SetTimerDuration then
            local d = box.sd
            if not d then d = C_DurationUtil.CreateDuration(); box.sd = d end
            local now = GetTime()
            d:SetTimeSpan(now - frac, now + (1 - frac))
            bar:SetTimerDuration(d, Enum.StatusBarInterpolation.Immediate, Enum.StatusBarTimerDirection.ElapsedTime)
        else
            bar:SetMinMaxValues(0, 1)
            bar:SetValue(frac)
        end
    end

    -- ---- state machine --------------------------------------------------------------------------------
    local function fetchCast()
        local n, _, tex, s, e, _, castID, notInt, sid = UnitCastingInfo(UNIT)
        if n then return "cast", n, tex, s, e, notInt, castID, sid end
        local n2, _, tex2, s2, e2, _, notInt2, sid2 = UnitChannelInfo(UNIT)
        if n2 then return "channel", n2, tex2, s2, e2, notInt2, nil, sid2 end
    end

    local function bind()
        local kind, name, tex, s, e, notInt, castID = fetchCast()
        if not kind then return false end
        local dur
        local fn = (kind == "cast") and UnitCastingDuration or UnitChannelDuration
        if fn then dur = fn(UNIT) end
        if not dur and s and e and not isSecret(s) and not isSecret(e) and C_DurationUtil then
            dur = C_DurationUtil.CreateDuration()
            dur:SetTimeSpan(s / 1000, e / 1000)
        end
        if not dur then return false end

        st.active, st.kind, st.dur, st.fade, st.endKind = true, kind, dur, nil, nil
        st.castID = (castID and not isSecret(castID)) and castID or st.pendingCastID
        bar:SetTimerDuration(dur, Enum.StatusBarInterpolation.Immediate,
            kind == "cast" and Enum.StatusBarTimerDirection.ElapsedTime or Enum.StatusBarTimerDirection.RemainingTime)
        if SHOW_NAME then box.nameText:SetText(name) end
        if box.icon then box.icon:SetTexture(tex or 134400) end
        applyCastColor(kind, notInt)
        box.spark:Show(); box.trail:Show()
        hideDecor()

        -- own casts only: total length is readable
        local total
        if not (dur.HasSecretValues and dur:HasSecretValues()) then total = dur:GetTotalDuration() end
        if total and total > 0 then
            if SHOW_LATENCY and kind == "cast" and st.sentAt then
                local lat = GetTime() - st.sentAt
                if lat > 0 and lat < total then
                    box.lat:ClearAllPoints()
                    box.lat:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
                    box.lat:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
                    box.lat:SetWidth(math.max(1, bar:GetWidth() * math.min(lat, total) / total))
                    box.lat:Show()
                end
            end
            if SHOW_TICKS and kind == "channel" and not isSecret(name) and TICKS[name] then
                ensureTicks(TICKS[name])
            end
        end
        st.sentAt = nil
        return true
    end

    local function finish(kind)
        st.active, st.endKind = false, nil
        st.fade = { t = GetTime(), kind = kind }
        setStatic(1)
        setColor(COLORS[kind] or COLORS.success)
        box.timerText:SetText("")
        box.spark:Hide(); box.trail:Hide()
        hideDecor()
        if kind == "interrupted" then box.nameText:SetText("Interrupted")
        elseif kind == "failed" then box.nameText:SetText("Failed") end
    end

    local function reset()
        st.active, st.fade, st.endKind = false, nil, nil
        box:SetAlpha(0)
        hideDecor()
    end

    local function previewing()
        return WeakAuras.IsOptionsOpen and WeakAuras.IsOptionsOpen()
    end

    local lastGcd = 0
    local function tick(dt)
        local now = GetTime()
        if st.active then
            if not (UnitCastingInfo(UNIT) or UnitChannelInfo(UNIT)) then
                finish(st.endKind or "success")
            else
                local a = box:GetAlpha()
                if a < 1 then box:SetAlpha(math.min(1, a + dt / FADE_IN)) end
                if SHOW_TIMER then
                    local f = timerFormatter()
                    if f then
                        box.timerText:SetText(st.dur:FormatRemainingDuration(f, Enum.DurationTimeModifier.RealTime))
                    elseif not (st.dur.HasSecretValues and st.dur:HasSecretValues()) then
                        box.timerText:SetText(string.format("%.1f", st.dur:GetRemainingDuration()))
                    end
                end
            end
        elseif st.fade then
            local el = now - st.fade.t
            if el < HOLD_END then
                box:SetAlpha(1)
            elseif el < HOLD_END + FADE_OUT then
                box:SetAlpha(1 - (el - HOLD_END) / FADE_OUT)
            else
                st.fade = nil
                box:SetAlpha(0)
            end
        else
            if (UnitCastingInfo(UNIT) or UnitChannelInfo(UNIT)) then
                bind()   -- cast we did not see start (target change, reload)
            elseif previewing() then
                -- positioning preview while the WeakAuras options are open
                setStatic(0.6); setColor(COLORS.cast)
                box.nameText:SetText("Preview Cast"); box.timerText:SetText("1.2")
                box.spark:Show(); box.trail:Show()
                box:SetAlpha(1)
            else
                box:SetAlpha(0)
            end
        end

        -- GCD line (own casts): readable only for the player and out of secret restrictions
        if SHOW_GCD and UNIT == "player" and now - lastGcd >= 0.03 then
            lastGcd = now
            local cd = C_Spell.GetSpellCooldown(GCD_SPELL)
            if cd and not isSecret(cd.startTime) and not isSecret(cd.duration) and cd.duration and cd.duration > 0
               and cd.startTime + cd.duration > now then
                box.gcd:SetMinMaxValues(0, cd.duration)
                box.gcd:SetValue(now - cd.startTime)
                box.gcd:Show()
            else
                box.gcd:Hide()
            end
        end
    end
    box.tick = tick
    if not box.driver then
        box.driver = true
        box:SetScript("OnUpdate", function(self, dt) if self.tick then self.tick(dt) end end)
    end

    -- ---- events ---------------------------------------------------------------------------------------
    hideBlizzard()
    if event == "UNIT_SPELLCAST_SENT" then
        st.sentAt = GetTime()
        st.pendingCastID = nil
    elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        st.pendingCastID = castGUID
        bind()
    elseif event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        if st.active then bind() end   -- pushback / channel change: take the new duration
    elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" or event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
        if st.active then
            local kind, _, _, _, _, notInt = fetchCast()
            if kind then applyCastColor(kind, notInt) end
        end
    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        if st.active then finish(st.endKind or "success") end
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_FAILED_QUIET" then
        -- a FAILED for another attempt (spamming a key mid-cast) must not kill the cast in progress
        local other = castGUID and st.castID and not isSecret(castGUID) and not isSecret(st.castID) and castGUID ~= st.castID
        if not other then
            local kind = (event == "UNIT_SPELLCAST_INTERRUPTED") and "interrupted" or "failed"
            if st.active then st.endKind = kind
            elseif st.fade and st.fade.kind == "success" then finish(kind) end
        end
    elseif event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
        reset()
    end
    return true
end
