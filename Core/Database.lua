-- O.O.P.S Database Management
-- Account-wide saved variables (OOPSDB). O.O.P.S deliberately uses a single
-- account-wide settings table: hard-mode preferences are about how you like
-- to play, not about a specific character.

local ADDON_NAME, OOPS = ...

OOPS.defaults = {
    -- Which obstacles are ticked in the control panel
    selectedObstacles = {},
    -- 1 = Mild, 2 = Spicy, 3 = Brutal
    intensity = 2,
    -- Accept group hard-mode proposals without the confirmation popup
    autoAccept = false,
    -- Show the punishment HUD while a run is active
    showHUD = true,
    -- Automatically start a hard mode when a Mythic+ keystone run begins
    armForKeystone = false,
    -- Reloading the UI does not let you escape your hard mode
    persistThroughReload = true,
    -- Red screen flash when the group punishment level rises
    flashOnPunishment = true,
    -- Warning sound when the group punishment level rises
    soundOnPunishment = true,
    -- Saved frame positions { point, x, y }
    hudPos = nil,
    panelPos = nil,
    -- Lifetime statistics
    stats = {
        runsStarted = 0,
        runsCompleted = 0,
        totalDeaths = 0,
        maxPunishment = 0,
    },
}

function OOPS:InitializeDatabase()
    if not OOPSDB then
        OOPSDB = {}
    end
    self.db = OOPSDB
    self:MergeDefaults(self.db, self.defaults)

    -- CVar safety net: obstacles back up every CVar they touch into
    -- db.cvarBackup. If we find leftovers without an active run (crash,
    -- disable mid-run, ...), restore them so nobody stays muted or blind.
    if self.db.cvarBackup and next(self.db.cvarBackup) and not self.db.activeRun then
        self:RestoreAllCVars()
        self:Print("Restored leftover settings from an interrupted run.")
    end
end

function OOPS:MergeDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then
            if type(value) == "table" then
                target[key] = {}
                self:MergeDefaults(target[key], value)
            else
                target[key] = value
            end
        elseif type(value) == "table" and type(target[key]) == "table" then
            self:MergeDefaults(target[key], value)
        end
    end
end

-- Back up a CVar value once (first writer wins) before an obstacle changes it.
function OOPS:BackupCVar(name)
    self.db.cvarBackup = self.db.cvarBackup or {}
    if self.db.cvarBackup[name] == nil then
        local ok, value = pcall(GetCVar, name)
        if ok and value ~= nil then
            self.db.cvarBackup[name] = value
        end
    end
end

-- Restore a single backed-up CVar and clear it from the backup table.
function OOPS:RestoreCVar(name)
    local backup = self.db.cvarBackup
    if backup and backup[name] ~= nil then
        pcall(SetCVar, name, backup[name])
        backup[name] = nil
    end
end

function OOPS:RestoreAllCVars()
    local backup = self.db.cvarBackup
    if not backup then return end
    for name in pairs(backup) do
        self:RestoreCVar(name)
    end
end
