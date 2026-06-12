-- Obstacle: Deafened
-- Mutes all game audio for the run. No boss yells, no cast warnings, no
-- "you are standing in fire" sound cues. The original sound setting is
-- backed up to saved variables so it is restored even after a crash.

local ADDON_NAME, OOPS = ...

local Deafened = {
    name = "Deafened",
    description = "All game audio is muted. Hope you memorized the boss timers.",
    icon = "Interface\\Icons\\Spell_Holy_Silence",
}

function Deafened:OnApply(intensity)
    OOPS:BackupCVar("Sound_EnableAllSound")
    pcall(SetCVar, "Sound_EnableAllSound", "0")
end

function Deafened:OnRemove()
    OOPS:RestoreCVar("Sound_EnableAllSound")
end

OOPS:RegisterObstacle("deafened", Deafened)
