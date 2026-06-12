-- Obstacle: Tunnel Vision
-- Darkens the edges of the screen with a vignette. The vignette thickens as
-- the group punishment level rises - the worse you play, the less you see.
-- Unlike B.O.L.T's old blackout prank, the screen is never fully covered and
-- the overlay is always click-through.

local ADDON_NAME, OOPS = ...

local TunnelVision = {
    name = "Tunnel Vision",
    description = "A dark vignette closes in around your screen and thickens with every group death.",
    icon = "Interface\\Icons\\Spell_Shadow_EvilEye",
}

local function GetAlpha(intensity, punishmentLevel)
    -- Mild 0.30, Spicy 0.45, Brutal 0.60 base; +0.04 per punishment level,
    -- hard-capped so the game always stays playable.
    return math.min(0.15 + 0.15 * intensity + 0.04 * (punishmentLevel or 0), 0.85)
end

function TunnelVision:GetFrame()
    if not self.frame then
        local f = CreateFrame("Frame", "OOPSTunnelVision", UIParent)
        f:SetAllPoints(UIParent)
        f:SetFrameStrata("FULLSCREEN")
        f:EnableMouse(false)
        local tex = f:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints(f)
        tex:SetTexture("Interface\\FullScreenTextures\\LowHealth")
        tex:SetVertexColor(0, 0, 0)
        f.tex = tex
        f:Hide()
        self.frame = f
    end
    return self.frame
end

function TunnelVision:OnApply(intensity)
    self.intensity = intensity
    local frame = self:GetFrame()
    frame.tex:SetAlpha(GetAlpha(intensity, OOPS.run.punishmentLevel))
    frame:Show()
end

function TunnelVision:OnPunishmentChanged(level)
    if self.frame and self.frame:IsShown() then
        self.frame.tex:SetAlpha(GetAlpha(self.intensity or 2, level))
    end
end

function TunnelVision:OnRemove()
    if self.frame then
        self.frame:Hide()
    end
end

OOPS:RegisterObstacle("tunnelVision", TunnelVision)
