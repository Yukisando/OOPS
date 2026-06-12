-- Obstacle: No Cartographer
-- Hides the minimap for the whole run. You did learn the dungeon routes,
-- right? (The MinimapCluster is not a protected frame, so this is safe to
-- toggle even in instances.)

local ADDON_NAME, OOPS = ...

local NoCartographer = {
    name = "No Cartographer",
    description = "Your minimap is gone. Navigate from memory like it's 2004.",
    icon = "Interface\\Icons\\INV_Misc_Map_01",
}

function NoCartographer:OnApply(intensity)
    if MinimapCluster and MinimapCluster:IsShown() then
        self.wasShown = true
        MinimapCluster:Hide()
    end
end

function NoCartographer:OnRemove()
    if MinimapCluster and self.wasShown then
        MinimapCluster:Show()
    end
    self.wasShown = nil
end

OOPS:RegisterObstacle("noCartographer", NoCartographer)
