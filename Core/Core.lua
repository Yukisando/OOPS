-- O.O.P.S Core
-- Run state machine: starting/stopping hard modes, the escalating punishment
-- level, death tracking, Mythic+ integration and the emergency reset.

local ADDON_NAME, OOPS = ...

OOPS.MAX_PUNISHMENT = 10
OOPS.INTENSITY_LABELS = { "Mild", "Spicy", "Brutal" }
OOPS.INTENSITY_COLORS = { "|cff7fff7f", "|cffffb347", "|cffff5050" }

-- Volatile run state (mirrored into db.activeRun for reload persistence)
OOPS.run = {
    active = false,
    obstacles = {},   -- set of obstacle keys
    intensity = 2,
    punishmentLevel = 0,
    deaths = 0,
    owner = nil,      -- player who started/proposed the run
    startedAt = nil,
}

function OOPS:PlayerFullName()
    local name = UnitName("player")
    local realm = GetNormalizedRealmName and GetNormalizedRealmName()
    if realm and realm ~= "" then
        return name .. "-" .. realm
    end
    return name
end

function OOPS:IsPlayerSender(sender)
    if not sender then return false end
    if sender == self:PlayerFullName() then return true end
    return Ambiguate(sender, "none") == UnitName("player")
end

function OOPS:GetIntensityLabel(intensity)
    local label = self.INTENSITY_LABELS[intensity] or "?"
    local color = self.INTENSITY_COLORS[intensity] or "|cffffffff"
    return color .. label .. "|r"
end

-- ---------------------------------------------------------------------------
-- Combat lockdown queue: some effects (CVar changes) must wait for combat end
-- ---------------------------------------------------------------------------

function OOPS:RunWhenOutOfCombat(fn)
    if not (InCombatLockdown and InCombatLockdown()) then
        fn()
        return
    end
    self.combatQueue = self.combatQueue or {}
    table.insert(self.combatQueue, fn)
end

function OOPS:FlushCombatQueue()
    if not self.combatQueue then return end
    local queue = self.combatQueue
    self.combatQueue = nil
    for _, fn in ipairs(queue) do
        pcall(fn)
    end
end

-- ---------------------------------------------------------------------------
-- Run lifecycle
-- ---------------------------------------------------------------------------

local function CountSet(set)
    local n = 0
    for _ in pairs(set) do n = n + 1 end
    return n
end

function OOPS:GetActiveObstacleNames()
    local names = {}
    for _, key in ipairs(self.obstacleOrder) do
        if self.run.obstacles[key] then
            table.insert(names, self.obstacles[key].name)
        end
    end
    return names
end

-- Start a hard mode. obstacleKeys is a set { key = true }, owner is the full
-- name of whoever initiated it (defaults to the local player for solo starts).
function OOPS:StartRun(obstacleKeys, intensity, owner)
    if self.run.active then
        self:Print("A hard mode is already active. Stop it first with /oops stop.")
        return false
    end

    -- Keep only obstacles this client knows about (guards against version
    -- mismatches between group members).
    local validKeys = {}
    for key in pairs(obstacleKeys or {}) do
        if self.obstacles[key] then
            validKeys[key] = true
        end
    end
    if CountSet(validKeys) == 0 then
        self:Print("Select at least one obstacle before starting a hard mode.")
        return false
    end

    intensity = math.max(1, math.min(3, tonumber(intensity) or 2))

    self.run.active = true
    self.run.obstacles = validKeys
    self.run.intensity = intensity
    self.run.punishmentLevel = 0
    self.run.deaths = 0
    self.run.owner = owner or self:PlayerFullName()
    self.run.startedAt = GetTime()

    for key in pairs(validKeys) do
        local obstacle = self.obstacles[key]
        local ok, err = pcall(obstacle.OnApply, obstacle, intensity)
        if not ok then
            self:Print("Failed to apply obstacle '" .. obstacle.name .. "': " .. tostring(err))
        end
    end

    self.db.stats.runsStarted = self.db.stats.runsStarted + 1
    self:PersistRun()
    self:RefreshUI()

    self:Print(("Hard mode |cffff5050ACTIVE|r (%s): %s"):format(
        self:GetIntensityLabel(intensity),
        table.concat(self:GetActiveObstacleNames(), ", ")))
    self:Print("Every group death raises the punishment level. Good luck.")
    return true
end

-- Start using the obstacles ticked in the control panel.
function OOPS:StartRunFromSelection()
    return self:StartRun(self.db.selectedObstacles, self.db.intensity)
end

function OOPS:StopRun(reason)
    if not self.run.active then
        self:Print("No hard mode is active.")
        return
    end

    for key in pairs(self.run.obstacles) do
        local obstacle = self.obstacles[key]
        if obstacle then
            pcall(obstacle.OnRemove, obstacle)
        end
    end

    local duration = self.run.startedAt and (GetTime() - self.run.startedAt) or 0
    local minutes = math.floor(duration / 60)
    local seconds = math.floor(duration % 60)

    self:Print(("Hard mode ended%s after %d:%02d - deaths: %d, final punishment level: %d.")
        :format(reason and (" (" .. reason .. ")") or "", minutes, seconds,
            self.run.deaths, self.run.punishmentLevel))

    self.run.active = false
    self.run.obstacles = {}
    self.run.punishmentLevel = 0
    self.run.deaths = 0
    self.run.owner = nil
    self.run.startedAt = nil

    self:PersistRun()
    self:RefreshUI()
end

-- Stop button / "/oops stop": if we own the run, stop the whole group;
-- otherwise only bail out locally (leaving the hard mode is always allowed -
-- this is a consent-based addon, not a trap).
function OOPS:RequestStop()
    if not self.run.active then
        self:Print("No hard mode is active.")
        return
    end
    if self:IsPlayerSender(self.run.owner) then
        if self.Comms then
            self.Comms:Broadcast("STOP")
        end
        self:StopRun("stopped by you")
    else
        self:StopRun("you abandoned the group hard mode... shame")
    end
end

-- Persist the run so a /reload does not silently disable the hard mode.
function OOPS:PersistRun()
    if self.run.active and self.db.persistThroughReload then
        local keys = {}
        for key in pairs(self.run.obstacles) do
            table.insert(keys, key)
        end
        self.db.activeRun = {
            obstacles = keys,
            intensity = self.run.intensity,
            punishmentLevel = self.run.punishmentLevel,
            deaths = self.run.deaths,
            owner = self.run.owner,
        }
    else
        self.db.activeRun = nil
    end
end

function OOPS:RestorePersistedRun()
    local saved = self.db.activeRun
    if not saved or self.run.active then return end

    local keys = {}
    for _, key in ipairs(saved.obstacles or {}) do
        keys[key] = true
    end

    self.db.activeRun = nil
    if self:StartRun(keys, saved.intensity, saved.owner) then
        -- This is the same run continuing, not a new one
        self.db.stats.runsStarted = self.db.stats.runsStarted - 1
        self.run.punishmentLevel = saved.punishmentLevel or 0
        self.run.deaths = saved.deaths or 0
        self:NotifyPunishmentChanged()
        self:PersistRun()
        self:Print("Hard mode restored after reload. Reloading is not an escape hatch!")
    end
end

-- ---------------------------------------------------------------------------
-- Punishment system
-- ---------------------------------------------------------------------------

function OOPS:NotifyPunishmentChanged()
    for key in pairs(self.run.obstacles) do
        local obstacle = self.obstacles[key]
        if obstacle and obstacle.OnPunishmentChanged then
            pcall(obstacle.OnPunishmentChanged, obstacle, self.run.punishmentLevel)
        end
    end
    self:RefreshUI()
end

-- A group member died: raise the shared punishment level.
-- isLocalDeath is true when it was our own death (we then broadcast it).
function OOPS:AddPunishment(victimName, isLocalDeath)
    if not self.run.active then return end

    self.run.deaths = self.run.deaths + 1
    self.run.punishmentLevel = math.min(self.run.punishmentLevel + 1, self.MAX_PUNISHMENT)

    self.db.stats.totalDeaths = self.db.stats.totalDeaths + 1
    if self.run.punishmentLevel > self.db.stats.maxPunishment then
        self.db.stats.maxPunishment = self.run.punishmentLevel
    end

    local who = victimName and Ambiguate(victimName, "none") or "Someone"
    self:Print(("|cffff5050%s died!|r Group punishment level rises to |cffff5050%d|r.")
        :format(who, self.run.punishmentLevel))

    if self.db.flashOnPunishment then
        self:FlashScreen()
    end
    if self.db.soundOnPunishment then
        pcall(PlaySound, SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, "Master")
    end

    if isLocalDeath and self.Comms then
        self.Comms:Broadcast("PUNISH|" .. self:PlayerFullName())
    end

    self:NotifyPunishmentChanged()
    self:PersistRun()
end

-- Short red full-screen flash on punishment. Click-through, auto-hides.
function OOPS:FlashScreen()
    if not self.flashFrame then
        local f = CreateFrame("Frame", "OOPSPunishmentFlash", UIParent)
        f:SetAllPoints(UIParent)
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:EnableMouse(false)
        local tex = f:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints(f)
        tex:SetTexture("Interface\\FullScreenTextures\\LowHealth")
        tex:SetVertexColor(1, 0, 0, 1)
        f.tex = tex

        local anim = f:CreateAnimationGroup()
        local alpha = anim:CreateAnimation("Alpha")
        alpha:SetFromAlpha(0.7)
        alpha:SetToAlpha(0)
        alpha:SetDuration(0.8)
        anim:SetScript("OnFinished", function() f:Hide() end)
        f.anim = anim
        f:Hide()
        self.flashFrame = f
    end
    self.flashFrame:Show()
    self.flashFrame.anim:Stop()
    self.flashFrame.anim:Play()
end

-- ---------------------------------------------------------------------------
-- Status / reset
-- ---------------------------------------------------------------------------

function OOPS:PrintStatus()
    if not self.run.active then
        self:Print("No hard mode active. Open the panel with /oops to set one up.")
        return
    end
    self:Print(("Hard mode ACTIVE (%s) - punishment level %d, deaths %d.")
        :format(self:GetIntensityLabel(self.run.intensity),
            self.run.punishmentLevel, self.run.deaths))
    self:Print("Obstacles: " .. table.concat(self:GetActiveObstacleNames(), ", "))
end

-- Nuclear option: undo every effect regardless of tracked state. Always safe
-- to run; this is the answer to "something looks stuck".
function OOPS:EmergencyReset()
    for _, key in ipairs(self.obstacleOrder) do
        local obstacle = self.obstacles[key]
        pcall(obstacle.OnRemove, obstacle)
    end
    self:RestoreAllCVars()

    self.run.active = false
    self.run.obstacles = {}
    self.run.punishmentLevel = 0
    self.run.deaths = 0
    self.run.owner = nil
    self.run.startedAt = nil
    self.db.activeRun = nil

    if self.flashFrame then self.flashFrame:Hide() end
    self:RefreshUI()
    self:Print("Emergency reset complete. All effects removed.")
end

-- Refresh whatever UI exists (panel, HUD); safe to call at any time.
function OOPS:RefreshUI()
    if self.RefreshControlPanel then self:RefreshControlPanel() end
    if self.RefreshHUD then self:RefreshHUD() end
end

-- ---------------------------------------------------------------------------
-- Events & bootstrap
-- ---------------------------------------------------------------------------

function OOPS:OnInitialize()
    self.version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "dev"
    self:InitializeDatabase()

    if self.Comms then
        self.Comms:Initialize()
    end

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_DEAD")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterEvent("CHALLENGE_MODE_START")
    events:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    events:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_DEAD" then
            self:AddPunishment(self:PlayerFullName(), true)
        elseif event == "PLAYER_REGEN_ENABLED" then
            self:FlushCombatQueue()
        elseif event == "CHALLENGE_MODE_START" then
            self:OnKeystoneStart()
        elseif event == "CHALLENGE_MODE_COMPLETED" then
            self:OnKeystoneCompleted()
        end
    end)
    self.eventFrame = events

    self:RestorePersistedRun()
    self:Print("O.O.P.S v" .. self.version .. " loaded. Type /oops to set up a hard mode.")
end

function OOPS:OnKeystoneStart()
    if self.db.armForKeystone and not self.run.active then
        if self:StartRunFromSelection() then
            self:Print("Keystone detected - your hard mode armed itself automatically.")
        end
    end
end

function OOPS:OnKeystoneCompleted()
    if not self.run.active then return end
    self.db.stats.runsCompleted = self.db.stats.runsCompleted + 1
    self:Print(("|cff7fff7fKeystone completed under hard mode!|r Deaths: %d, final punishment level: %d.")
        :format(self.run.deaths, self.run.punishmentLevel))
    self:StopRun("keystone completed")
end

-- Bootstrap: initialize only after login has fully settled, mirroring the
-- defensive startup used by B.O.L.T to avoid touching the UI during
-- Blizzard's secure bootstrap.
local function TryInitialize()
    if OOPS._initialized then return end
    if not (IsLoggedIn and IsLoggedIn()) or (InCombatLockdown and InCombatLockdown()) then
        C_Timer.After(0.2, TryInitialize)
        return
    end
    OOPS._initialized = true
    OOPS:OnInitialize()
end

C_Timer.After(0.2, TryInitialize)
