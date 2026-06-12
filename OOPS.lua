-- O.O.P.S - Obstacle-Oriented Punishment System
-- Entry point: addon namespace, obstacle registry and slash commands.
-- Everything O.O.P.S does is visible, opt-in and consent-based: group hard
-- modes are proposed via addon messages and each member explicitly accepts.

local ADDON_NAME, OOPS = ...

OOPS.name = ADDON_NAME
OOPS.version = "dev" -- Set from TOC metadata during initialization
OOPS.obstacles = {}
OOPS.obstacleOrder = {}

-- Register an obstacle (called by files in Obstacles/ at load time).
-- An obstacle implements:
--   name, description, icon  - display data for the control panel and HUD
--   OnApply(intensity)       - activate the effect (1=Mild, 2=Spicy, 3=Brutal)
--   OnRemove()               - fully undo the effect
--   OnPunishmentChanged(lvl) - optional, react to the group punishment level
function OOPS:RegisterObstacle(key, obstacle)
    if self.obstacles[key] then return end
    obstacle.key = key
    obstacle.parent = self
    self.obstacles[key] = obstacle
    table.insert(self.obstacleOrder, key)
end

function OOPS:Print(msg)
    print("|cffff5050[O.O.P.S]|r " .. tostring(msg))
end

-- Slash commands
SLASH_OOPS1 = "/oops"
SlashCmdList["OOPS"] = function(msg)
    local args = {}
    for word in msg:gmatch("%S+") do
        table.insert(args, word:lower())
    end

    if #args == 0 then
        OOPS:ToggleControlPanel()
    elseif args[1] == "start" then
        OOPS:StartRunFromSelection()
    elseif args[1] == "stop" then
        OOPS:RequestStop()
    elseif args[1] == "status" then
        OOPS:PrintStatus()
    elseif args[1] == "reset" then
        OOPS:EmergencyReset()
    elseif args[1] == "options" then
        OOPS:OpenOptions()
    elseif args[1] == "help" then
        OOPS:Print("O.O.P.S v" .. OOPS.version .. " - Obstacle-Oriented Punishment System")
        print("  |cffFFFFFF/oops|r - Toggle the control panel")
        print("  |cffFFFFFF/oops start|r - Start a hard mode with your selected obstacles")
        print("  |cffFFFFFF/oops stop|r - Stop the current hard mode")
        print("  |cffFFFFFF/oops status|r - Show the current run status")
        print("  |cffFFFFFF/oops options|r - Open the options panel")
        print("  |cffFFFFFF/oops reset|r (or |cffFFFFFF/oopsreset|r) - Emergency reset of all effects")
    else
        OOPS:Print("Unknown command. Type '/oops help' for available commands.")
    end
end

-- Emergency reset is intentionally its own command so it is easy to find
-- and type even with obstacles active.
SLASH_OOPSRESET1 = "/oopsreset"
SlashCmdList["OOPSRESET"] = function()
    OOPS:EmergencyReset()
end

_G[ADDON_NAME] = OOPS
