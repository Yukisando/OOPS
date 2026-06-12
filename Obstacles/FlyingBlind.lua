-- Obstacle: Flying Blind
-- Disables enemy nameplates. Health bars are a crutch anyway. Nameplate
-- CVars cannot be written during combat, so changes are queued and applied
-- the moment combat ends; original values are backed up to the saved
-- variables so they survive even a crash mid-run.

local ADDON_NAME, OOPS = ...

local FlyingBlind = {
    name = "Flying Blind",
    description = "Enemy nameplates are disabled. Eyeball the pack like a true gamer.",
    icon = "Interface\\Icons\\Ability_Rogue_MasterOfSubtlety",
}

function FlyingBlind:OnApply(intensity)
    OOPS:RunWhenOutOfCombat(function()
        OOPS:BackupCVar("nameplateShowEnemies")
        pcall(SetCVar, "nameplateShowEnemies", "0")
    end)
end

function FlyingBlind:OnRemove()
    OOPS:RunWhenOutOfCombat(function()
        OOPS:RestoreCVar("nameplateShowEnemies")
    end)
end

OOPS:RegisterObstacle("flyingBlind", FlyingBlind)
