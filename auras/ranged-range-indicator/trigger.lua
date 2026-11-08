-- Custom trigger (type: Status, events: PLAYER_TARGET_CHANGED, FRAME_UPDATE)
-- Shows the estimated distance to your target (monster or player) in a box whose
-- background color depends on the distance:
--   > 30 red | 20-30 green | 10-20 yellow | 5-10 orange | < 5 red
-- (no pcall: it is forbidden in WeakAuras custom code)
function(event)
    local env = aura_env
    local region = env.region
    if not region then return false end

    -- label lives on the region itself so reloads never create duplicates
    local fs = region.faLabel
    if not fs then
        fs = region:CreateFontString(nil, "OVERLAY")
        fs:SetFont(STANDARD_TEXT_FONT, 24, "OUTLINE")
        fs:SetPoint("CENTER", region, "CENTER", 0, 0)
        fs:SetTextColor(1, 1, 1, 1)
        region.faLabel = fs
    end

    local function compute()
        if not UnitExists("target") or UnitIsUnit("target", "player") or UnitIsDead("target") then
            fs:SetText("")
            return false
        end

        -- exact distance if the client provides it
        local exact
        if UnitDistanceSquared then
            local d2, checked = UnitDistanceSquared("target")
            if checked and d2 and not (issecretvalue and issecretvalue(d2)) then
                exact = math.sqrt(d2)
            end
        end

        local RC = LibStub("LibRangeCheck-3.0", true)
        local minR, maxR
        if not exact and RC then
            -- maxCacheAge 0 = never reuse a cached value (stale after target switch)
            minR, maxR = RC:GetRange("target", false, false, 0)
        end

        -- fallback: probe item ranges ourselves if the library gave nothing
        if not exact and not minR then
            local probes = { {5,37727}, {8,34368}, {10,32321}, {15,33069}, {20,10645},
                             {25,24268}, {30,835}, {35,24269}, {40,28767} }
            local inR = C_Item and C_Item.IsItemInRange or IsItemInRange
            local lastIn, firstOut
            for _, p in ipairs(probes) do
                local r = inR(p[2], "target")
                if r ~= nil then
                    if r then lastIn = lastIn or p[1]; break
                    else firstOut = p[1] end
                end
            end
            if lastIn then
                minR, maxR = (firstOut or 0), lastIn
            elseif firstOut then
                minR, maxR = firstOut, nil
            end
        end

        local r, g, b = 0.8, 0, 0
        local text
        if not minR and not exact then
            text = "OUT OF RANGE"
        else
            local hi = exact or maxR or minR
            if hi > 30 then r, g, b = 0.8, 0, 0          -- red: out of 30 yd
            elseif hi > 20 then r, g, b = 0, 0.6, 0      -- green: 20-30
            elseif hi > 10 then r, g, b = 0.8, 0.7, 0    -- yellow: 10-20
            elseif hi > 5 then r, g, b = 0.9, 0.4, 0     -- orange: 5-10
            else r, g, b = 0.8, 0, 0 end                 -- red: < 5
            if exact then text = string.format("%.0f yd", exact)
            elseif not maxR then text = string.format("%d+", minR)
            else text = string.format("%d - %d", minR, maxR) end
        end
        if region.Color then region:Color(r, g, b, 0.85) end
        fs:SetText(text)
        return true
    end

    -- fast independent driver (FRAME_UPDATE alone proved too slow); updates ~20x/sec
    local d = region.faDriver
    if not d then
        d = CreateFrame("Frame")
        d.acc = 0
        d:SetScript("OnUpdate", function(self, elapsed)
            self.acc = self.acc + elapsed
            if self.acc >= 0.05 and self.fn then
                self.acc = 0
                self.fn()
            end
        end)
        region.faDriver = d
    end
    d.fn = compute

    -- instant refresh on target change, clear the old text immediately
    if event == "PLAYER_TARGET_CHANGED" then fs:SetText("") end
    return compute()
end
