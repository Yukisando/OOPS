-- O.O.P.S Group Communication
-- Hard modes are synchronized over hidden addon messages instead of trigger
-- words in player chat. This is both polite (nothing is spammed in chat) and
-- Midnight-proof: in 12.0 player chat inside instances arrives as Secret
-- Values that addons cannot read, while addon messages keep working.
--
-- Protocol (prefix "OOPS1", fields separated by "|"):
--   PROPOSE|<keysCSV>|<intensity>  - propose a hard mode to the group
--   ACCEPT / DECLINE               - reply to the proposer (informational)
--   PUNISH|<victimFullName>        - a member died, raise punishment level
--   STOP                           - run owner ends the hard mode for everyone

local ADDON_NAME, OOPS = ...

local PREFIX = "OOPS1"

local Comms = {}
OOPS.Comms = Comms

function Comms:Initialize()
    pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)

    self.frame = CreateFrame("Frame")
    self.frame:RegisterEvent("CHAT_MSG_ADDON")
    self.frame:SetScript("OnEvent", function(_, _, prefix, message, _, sender)
        self:OnAddonMessage(prefix, message, sender)
    end)

    self:SetupProposalPopup()
end

function Comms:GetChannel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    elseif IsInRaid() then
        return "RAID"
    elseif IsInGroup() then
        return "PARTY"
    end
    return nil
end

function Comms:Broadcast(message)
    local channel = self:GetChannel()
    if not channel then return end
    pcall(C_ChatInfo.SendAddonMessage, PREFIX, message, channel)
end

function Comms:OnAddonMessage(prefix, message, sender)
    if prefix ~= PREFIX then return end
    -- Defensive Midnight guard: never operate on Secret Values.
    if issecretvalue and (issecretvalue(message) or issecretvalue(sender)) then return end
    if type(message) ~= "string" then return end

    local parts = { strsplit("|", message) }
    local command = parts[1]
    local fromSelf = OOPS:IsPlayerSender(sender)

    if command == "PROPOSE" and not fromSelf then
        self:OnProposal(sender, parts[2], tonumber(parts[3]))
    elseif command == "ACCEPT" and not fromSelf then
        if OOPS.run.active and OOPS:IsPlayerSender(OOPS.run.owner) then
            OOPS:Print(Ambiguate(sender, "none") .. " |cff7fff7faccepted|r the hard mode. Welcome to the pain train.")
        end
    elseif command == "DECLINE" and not fromSelf then
        if OOPS.run.active and OOPS:IsPlayerSender(OOPS.run.owner) then
            OOPS:Print(Ambiguate(sender, "none") .. " |cffff5050declined|r the hard mode. Coward.")
        end
    elseif command == "PUNISH" and not fromSelf then
        OOPS:AddPunishment(parts[2] or sender, false)
    elseif command == "STOP" and not fromSelf then
        -- Only the run owner may end the run for the whole group.
        if OOPS.run.active and OOPS.run.owner and sender == OOPS.run.owner then
            OOPS:StopRun("stopped by " .. Ambiguate(sender, "none"))
        end
    end
end

-- ---------------------------------------------------------------------------
-- Proposing a hard mode to the group
-- ---------------------------------------------------------------------------

-- Called from the control panel: start locally and invite everyone else.
function Comms:ProposeToGroup()
    if not IsInGroup() then
        OOPS:Print("You are not in a group. Use Start instead.")
        return
    end
    local keys = {}
    for key in pairs(OOPS.db.selectedObstacles) do
        if OOPS.db.selectedObstacles[key] and OOPS.obstacles[key] then
            table.insert(keys, key)
        end
    end
    if #keys == 0 then
        OOPS:Print("Select at least one obstacle before proposing a hard mode.")
        return
    end

    if not OOPS:StartRun(OOPS.db.selectedObstacles, OOPS.db.intensity) then
        return
    end
    self:Broadcast(("PROPOSE|%s|%d"):format(table.concat(keys, ","), OOPS.db.intensity))
    OOPS:Print("Hard mode proposed to your group. Members with O.O.P.S will be asked to join.")
end

function Comms:OnProposal(sender, keysCSV, intensity)
    if OOPS.run.active then
        OOPS:Print(Ambiguate(sender, "none") .. " proposed a hard mode but you already have one active.")
        return
    end

    local keys = {}
    local names = {}
    for key in string.gmatch(keysCSV or "", "[^,]+") do
        if OOPS.obstacles[key] then
            keys[key] = true
            table.insert(names, OOPS.obstacles[key].name)
        end
    end
    if not next(keys) then return end
    intensity = math.max(1, math.min(3, intensity or 2))

    if OOPS.db.autoAccept then
        if OOPS:StartRun(keys, intensity, sender) then
            self:Broadcast("ACCEPT")
            OOPS:Print("Auto-accepted " .. Ambiguate(sender, "none") .. "'s hard mode proposal.")
        end
        return
    end

    self.pendingProposal = { sender = sender, keys = keys, intensity = intensity }
    StaticPopup_Show("OOPS_PROPOSAL", Ambiguate(sender, "none"),
        table.concat(names, ", ") .. "  (" .. OOPS:GetIntensityLabel(intensity) .. "|cffffd100)")
end

function Comms:SetupProposalPopup()
    StaticPopupDialogs["OOPS_PROPOSAL"] = {
        text = "|cffff5050O.O.P.S Hard Mode|r\n\n%s invites you to suffer together:\n\n|cffffffff%s|r\n\nEvery group death raises the punishment level for everyone. Accept?",
        button1 = "Bring it on",
        button2 = "No thanks",
        OnAccept = function()
            local proposal = Comms.pendingProposal
            Comms.pendingProposal = nil
            if proposal and OOPS:StartRun(proposal.keys, proposal.intensity, proposal.sender) then
                Comms:Broadcast("ACCEPT")
            end
        end,
        OnCancel = function()
            Comms.pendingProposal = nil
            Comms:Broadcast("DECLINE")
        end,
        timeout = 45,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end
