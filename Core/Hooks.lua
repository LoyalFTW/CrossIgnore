local _, ns = ...
local CrossIgnore = ns.Addon
local L = ns.L

local LFGFrameIsOpen = false

function CrossIgnore:ClearLFGCache()
    if self.LFGCacheTimer then
        self.LFGCacheTimer:Cancel()
        self.LFGCacheTimer = nil
    end
end

function CrossIgnore:HookFunctions()
    if EventRegistry and Menu and Menu.GetManager then
        EventRegistry:RegisterCallback("Menu.OpenMenuTag", function(_, tag, contextData)
            self:ShowUnitMenuButton(tag, contextData)
        end, self)
    end
    if Menu and Menu.ModifyMenu then
        if LFGListFrame then
            Menu.ModifyMenu("MENU_LFG_FRAME_SEARCH_ENTRY", function(...)
                self:CrossIgnore_LFG_ApplicantMenu(...)
            end)

            LFGListFrame:HookScript("OnShow", function()
                LFGFrameIsOpen = true
                CrossIgnore:ClearLFGCache()
            end)
            LFGListFrame:HookScript("OnHide", function()
                LFGFrameIsOpen = false
                CrossIgnore:ClearLFGCache()
            end)

            hooksecurefunc("LFGListSearchEntry_Update", function(entry)
                if not LFGFrameIsOpen or not entry.resultID then return end
                local info = C_LFGList.GetSearchResultInfo(entry.resultID)
                if info and info.leaderName then
                    if CrossIgnore:IsPlayerBlocked(info.leaderName) then
                        if not entry.Backdrop then
                            entry.Backdrop = entry:CreateTexture(nil, "BACKGROUND")
                            entry.Backdrop:SetAllPoints(entry)
                        end
                        entry.Backdrop:SetColorTexture(1, 0, 0, 0.3)
                    elseif entry.Backdrop then
                        entry.Backdrop:SetColorTexture(0, 0, 0, 0)
                    end
                end
            end)

            hooksecurefunc("LFGListSearchEntry_OnEnter", function(selfEntry)
                if not LFGFrameIsOpen or not selfEntry.resultID then return end
                local info = C_LFGList.GetSearchResultInfo(selfEntry.resultID)
                if info and info.leaderName and CrossIgnore:IsPlayerBlocked(info.leaderName) then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(L["CI_ALERT_LEADER_BLOCKED"], 1, 0.3, 0.3)
                    GameTooltip:Show()
                end
            end)
        end

    end
end
