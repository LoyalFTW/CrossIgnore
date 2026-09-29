local _, ns = ...
local CrossIgnore = ns.Addon
local L = ns.L

function CrossIgnore:OnLFGDecline(event, id, status)
    if not self.isForever and C_LFGList and C_LFGList.GetSearchResultInfo and self.db.profile.settings.LFGBlock and status == "declined" then
        local info = C_LFGList.GetSearchResultInfo(id)
        if info and info.leaderName then
            local days = math.max(0, tonumber(self.db.profile.settings.lfgExpireDays) or 1)
            self:AddIgnore(info.leaderName, L["LFG_DECLINE_REASON"], days * 86400)
        end
    end
end
