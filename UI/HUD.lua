-- O.O.P.S Punishment HUD
-- Small always-visible readout while a hard mode is active: punishment level,
-- death count and the icons of the active obstacles. Drag to reposition.

local ADDON_NAME, OOPS = ...

local hud

local function CreateHUD()
    local f = CreateFrame("Frame", "OOPSHud", UIParent, "BackdropTemplate")
    f:SetSize(280, 56)
    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0, 0, 0, 0.6)
    f:SetBackdropBorderColor(1, 0.3, 0.3, 0.8)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        local point, _, _, x, y = frame:GetPoint()
        OOPS.db.hudPos = { point = point, x = x, y = y }
    end)

    local pos = OOPS.db.hudPos
    if pos then
        f:SetPoint(pos.point or "TOP", UIParent, pos.point or "TOP", pos.x or 0, pos.y or -120)
    else
        f:SetPoint("TOP", 0, -120)
    end

    local skull = f:CreateTexture(nil, "ARTWORK")
    skull:SetSize(28, 28)
    skull:SetPoint("LEFT", 10, 0)
    skull:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
    f.skull = skull

    local levelText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    levelText:SetPoint("TOPLEFT", skull, "TOPRIGHT", 8, 0)
    f.levelText = levelText

    local deathText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    deathText:SetPoint("TOPLEFT", levelText, "BOTTOMLEFT", 0, -2)
    f.deathText = deathText

    -- Row of active obstacle icons, right-aligned
    f.icons = {}
    for i = 1, #OOPS.obstacleOrder do
        local icon = f:CreateTexture(nil, "ARTWORK")
        icon:SetSize(18, 18)
        icon:SetPoint("RIGHT", -10 - (i - 1) * 22, 0)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        icon:Hide()
        f.icons[i] = icon
    end

    f:Hide()
    return f
end

function OOPS:RefreshHUD()
    if not (self.run.active and self.db.showHUD) then
        if hud then hud:Hide() end
        return
    end

    if not hud then
        hud = CreateHUD()
    end

    hud.levelText:SetText(("|cffff5050PUNISHMENT Lv. %d|r"):format(self.run.punishmentLevel))
    hud.deathText:SetText(("Deaths: %d  -  %s"):format(self.run.deaths,
        self:GetIntensityLabel(self.run.intensity)))

    local i = 1
    for _, key in ipairs(self.obstacleOrder) do
        if self.run.obstacles[key] then
            local icon = hud.icons[i]
            icon:SetTexture(self.obstacles[key].icon)
            icon:Show()
            i = i + 1
        end
    end
    for j = i, #hud.icons do
        hud.icons[j]:Hide()
    end

    hud:Show()
end
