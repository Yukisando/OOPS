-- O.O.P.S Control Panel
-- The main, very-much-not-hidden window: pick obstacles, pick an intensity,
-- start solo or propose to your group. Opened with /oops.

local ADDON_NAME, OOPS = ...

local PANEL_WIDTH = 480
local ROW_HEIGHT = 46

local panel

local function SavePosition(frame)
    local point, _, _, x, y = frame:GetPoint()
    OOPS.db.panelPos = { point = point, x = x, y = y }
end

local function CreateObstacleRow(parent, key, yOffset)
    local obstacle = OOPS.obstacles[key]
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(PANEL_WIDTH - 32, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 16, yOffset)

    local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    check:SetSize(28, 28)
    check:SetPoint("LEFT", 0, 0)
    check:SetScript("OnClick", function(btn)
        OOPS.db.selectedObstacles[key] = btn:GetChecked() and true or nil
    end)
    row.check = check

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(26, 26)
    icon:SetPoint("LEFT", check, "RIGHT", 6, 0)
    icon:SetTexture(obstacle.icon)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, 1)
    name:SetText(obstacle.name)

    local desc = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
    desc:SetWidth(PANEL_WIDTH - 130)
    desc:SetJustifyH("LEFT")
    desc:SetText(obstacle.description)

    return row
end

local function CreatePanel()
    local numObstacles = #OOPS.obstacleOrder
    local height = 96 + numObstacles * ROW_HEIGHT + 130

    local f = CreateFrame("Frame", "OOPSControlPanel", UIParent, "BackdropTemplate")
    f:SetSize(PANEL_WIDTH, height)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        SavePosition(frame)
    end)

    local pos = OOPS.db.panelPos
    if pos then
        f:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER", pos.x or 0, pos.y or 0)
    else
        f:SetPoint("CENTER")
    end

    -- ESC closes the panel
    tinsert(UISpecialFrames, "OOPSControlPanel")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -18)
    title:SetText("|cffff5050O.O.P.S|r - Obstacle-Oriented Punishment System")

    local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -4)
    subtitle:SetText("Pick your obstacles. Every group death cranks up the punishment.")

    -- Obstacle rows
    f.rows = {}
    local y = -64
    for _, key in ipairs(OOPS.obstacleOrder) do
        f.rows[key] = CreateObstacleRow(f, key, y)
        y = y - ROW_HEIGHT
    end

    -- Intensity selector (radio buttons)
    local intensityLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    intensityLabel:SetPoint("TOPLEFT", 20, y - 8)
    intensityLabel:SetText("Intensity:")

    f.intensityButtons = {}
    local anchor = intensityLabel
    for i, label in ipairs(OOPS.INTENSITY_LABELS) do
        local radio = CreateFrame("CheckButton", nil, f, "UIRadioButtonTemplate")
        radio:SetPoint("LEFT", anchor, "RIGHT", i == 1 and 12 or 60, 0)
        radio:SetScript("OnClick", function()
            OOPS.db.intensity = i
            OOPS:RefreshControlPanel()
        end)
        local text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("LEFT", radio, "RIGHT", 4, 0)
        text:SetText(OOPS.INTENSITY_COLORS[i] .. label .. "|r")
        f.intensityButtons[i] = radio
        anchor = radio
    end

    -- Surprise Me: random obstacles, for groups that like gambling
    local randomBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    randomBtn:SetSize(110, 22)
    randomBtn:SetPoint("TOPRIGHT", -20, y - 6)
    randomBtn:SetText("Surprise Me")
    randomBtn:SetScript("OnClick", function()
        if OOPS.run.active then return end
        wipe(OOPS.db.selectedObstacles)
        local picked = {}
        for _, key in ipairs(OOPS.obstacleOrder) do
            if math.random() < 0.5 then
                OOPS.db.selectedObstacles[key] = true
                table.insert(picked, key)
            end
        end
        if #picked == 0 then
            local key = OOPS.obstacleOrder[math.random(#OOPS.obstacleOrder)]
            OOPS.db.selectedObstacles[key] = true
        end
        OOPS:RefreshControlPanel()
    end)
    f.randomBtn = randomBtn

    y = y - 40

    -- Action buttons
    local startBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    startBtn:SetSize(130, 26)
    startBtn:SetPoint("TOPLEFT", 20, y)
    startBtn:SetText("Start (Solo)")
    startBtn:SetScript("OnClick", function() OOPS:StartRunFromSelection() end)
    f.startBtn = startBtn

    local proposeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    proposeBtn:SetSize(150, 26)
    proposeBtn:SetPoint("LEFT", startBtn, "RIGHT", 8, 0)
    proposeBtn:SetText("Propose to Group")
    proposeBtn:SetScript("OnClick", function() OOPS.Comms:ProposeToGroup() end)
    f.proposeBtn = proposeBtn

    local stopBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    stopBtn:SetSize(130, 26)
    stopBtn:SetPoint("LEFT", proposeBtn, "RIGHT", 8, 0)
    stopBtn:SetText("Stop")
    stopBtn:SetScript("OnClick", function() OOPS:RequestStop() end)
    f.stopBtn = stopBtn

    -- Status line
    local status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    status:SetPoint("BOTTOM", 0, 22)
    status:SetWidth(PANEL_WIDTH - 40)
    f.status = status

    return f
end

function OOPS:RefreshControlPanel()
    if not panel then return end
    local active = self.run.active

    for key, row in pairs(panel.rows) do
        local checked = active and self.run.obstacles[key] or self.db.selectedObstacles[key]
        row.check:SetChecked(checked and true or false)
        row.check:SetEnabled(not active)
    end

    local intensity = active and self.run.intensity or self.db.intensity
    for i, radio in ipairs(panel.intensityButtons) do
        radio:SetChecked(i == intensity)
        radio:SetEnabled(not active)
    end

    panel.startBtn:SetEnabled(not active)
    panel.proposeBtn:SetEnabled(not active and IsInGroup())
    panel.stopBtn:SetEnabled(active)
    panel.randomBtn:SetEnabled(not active)

    if active then
        panel.status:SetText(("|cffff5050HARD MODE ACTIVE|r (%s) - punishment level %d - deaths %d")
            :format(self:GetIntensityLabel(self.run.intensity),
                self.run.punishmentLevel, self.run.deaths))
    else
        panel.status:SetText("|cff7fff7fIdle.|r Select obstacles and start when ready. /oopsreset always bails you out.")
    end
end

function OOPS:ToggleControlPanel()
    if not self.db then
        self:Print("Still loading, try again in a second.")
        return
    end
    if not panel then
        panel = CreatePanel()
    end
    if panel:IsShown() then
        panel:Hide()
    else
        self:RefreshControlPanel()
        panel:Show()
    end
end
