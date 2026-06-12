-- O.O.P.S Options Panel
-- Registers a category in the Blizzard Settings UI (ESC > Options > AddOns)
-- with behavior toggles and lifetime stats. The day-to-day controls live in
-- the /oops control panel; this is for preferences.

local ADDON_NAME, OOPS = ...

local OPTIONS = {
    { key = "showHUD",              label = "Show punishment HUD during a run" },
    { key = "autoAccept",           label = "Auto-accept group hard mode proposals (skip the popup)" },
    { key = "armForKeystone",       label = "Auto-start my selected obstacles when a Mythic+ run begins" },
    { key = "persistThroughReload", label = "Hard mode survives /reload (no escape hatch)" },
    { key = "flashOnPunishment",    label = "Red screen flash when the punishment level rises" },
    { key = "soundOnPunishment",    label = "Warning sound when the punishment level rises" },
}

local category

local function CreateOptionsPanel()
    local panel = CreateFrame("Frame")
    panel.name = "O.O.P.S"

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cffff5050O.O.P.S|r - Obstacle-Oriented Punishment System")

    local desc = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    desc:SetWidth(560)
    desc:SetJustifyH("LEFT")
    desc:SetText("Consent-based hard modes for groups that think Mythic+ is too easy. Pick obstacles, drag your friends in, and let every death make things worse.")

    local openBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    openBtn:SetSize(180, 26)
    openBtn:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -12)
    openBtn:SetText("Open Control Panel")
    openBtn:SetScript("OnClick", function() OOPS:ToggleControlPanel() end)

    local checks = {}
    local anchor = openBtn
    for _, option in ipairs(OPTIONS) do
        local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        check:SetSize(26, 26)
        check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)

        local label = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("LEFT", check, "RIGHT", 4, 0)
        label:SetText(option.label)

        check:SetScript("OnClick", function(btn)
            OOPS.db[option.key] = btn:GetChecked() and true or false
            OOPS:RefreshUI()
        end)
        check.optionKey = option.key
        table.insert(checks, check)
        anchor = check
    end

    local stats = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    stats:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 4, -16)
    stats:SetJustifyH("LEFT")
    panel.stats = stats

    panel:SetScript("OnShow", function()
        for _, check in ipairs(checks) do
            check:SetChecked(OOPS.db and OOPS.db[check.optionKey] and true or false)
        end
        if OOPS.db then
            local s = OOPS.db.stats
            stats:SetText(("Lifetime stats:  %d runs started  -  %d keystones completed under hard mode  -  %d deaths punished  -  highest punishment level: %d")
                :format(s.runsStarted, s.runsCompleted, s.totalDeaths, s.maxPunishment))
        end
    end)

    return panel
end

local function RegisterOptions()
    local panel = CreateOptionsPanel()
    if Settings and Settings.RegisterCanvasLayoutCategory then
        category = Settings.RegisterCanvasLayoutCategory(panel, "O.O.P.S")
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

function OOPS:OpenOptions()
    if category and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
    end
end

RegisterOptions()
