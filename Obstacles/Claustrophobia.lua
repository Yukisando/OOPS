-- Obstacle: Claustrophobia
-- Locks the camera into first person for the whole run. Periodically zooms
-- all the way in (same technique as B.O.L.T's hardcore mode, minus the
-- black screen), and restores your original camera distance afterwards.

local ADDON_NAME, OOPS = ...

local Claustrophobia = {
    name = "Claustrophobia",
    description = "Your camera is locked into first person. Situational awareness sold separately.",
    icon = "Interface\\Icons\\Ability_Hunter_SniperShot",
}

function Claustrophobia:OnApply(intensity)
    if self.ticker then return end
    self.originalZoom = GetCameraZoom and GetCameraZoom() or nil

    -- Re-zoom on a ticker so scrolling out only buys a split second of relief.
    pcall(CameraZoomIn, 50)
    self.ticker = C_Timer.NewTicker(0.4, function()
        pcall(CameraZoomIn, 50)
    end)
end

function Claustrophobia:OnRemove()
    if self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end
    if self.originalZoom and GetCameraZoom then
        -- No SetCameraZoom API exists; zoom out by the measured difference.
        local current = GetCameraZoom()
        local diff = self.originalZoom - current
        if diff > 0 then
            pcall(CameraZoomOut, diff)
        elseif diff < 0 then
            pcall(CameraZoomIn, -diff)
        end
        self.originalZoom = nil
    end
end

OOPS:RegisterObstacle("claustrophobia", Claustrophobia)
