local addonName, addonTable = ...
local L = addonTable.L

function CrossIgnore:CreateOptionsUI(parent)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    label:SetPoint("TOP", 0, -12)
    label:SetText(L["CI_OPTIONS"])

    local lfgLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lfgLabel:SetPoint("TOPLEFT", 10, -50)
    lfgLabel:SetText(L["LFG_AUTO_BLOCK"])

    local lfgCheckbox = CreateFrame("CheckButton", "CrossIgnoreLFGBlockCheckbox", parent, "ChatConfigCheckButtonTemplate")
    lfgCheckbox:SetPoint("LEFT", lfgLabel, "RIGHT", 10, 0)
    lfgCheckbox:SetChecked(CrossIgnore.charDB.profile.settings.LFGBlock)
    lfgCheckbox:SetScript("OnClick", function(button)
        local value = button:GetChecked()
        CrossIgnore.charDB.profile.settings.LFGBlock = value
        print("LFG Block " .. (value and "enabled" or "disabled"))
    end)

    lfgCheckbox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["AUTOMATICALLY_BLOCK_LEADER_OF_THE_GROUP"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    lfgCheckbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end
