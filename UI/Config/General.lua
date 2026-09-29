local _, ns = ...
local CrossIgnore = ns.Addon
local L = ns.L

function CrossIgnore:CreateOptionsUI(parent)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    label:SetPoint("TOP", 0, -12)
    label:SetText(L["CI_OPTIONS"])

    if CrossIgnore.isForever then
        local unavailableLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        unavailableLabel:SetPoint("TOPLEFT", 10, -50)
        unavailableLabel:SetWidth(410)
        unavailableLabel:SetJustifyH("LEFT")
        unavailableLabel:SetText(L["LFG_UNAVAILABLE_FOREVER"])
        return
    end

    local lfgLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lfgLabel:SetPoint("TOPLEFT", 10, -50)
    lfgLabel:SetText(L["LFG_AUTO_BLOCK"])

    local lfgCheckbox = CreateFrame("CheckButton", "CrossIgnoreLFGBlockCheckbox", parent, "ChatConfigCheckButtonTemplate")
    lfgCheckbox:SetPoint("LEFT", lfgLabel, "RIGHT", 10, 0)
    lfgCheckbox:SetChecked(CrossIgnore.charDB.profile.settings.LFGBlock)

    lfgCheckbox:SetScript("OnClick", function(button)
        local value = button:GetChecked() and true or false
        CrossIgnore.charDB.profile.settings.LFGBlock = value
        print("LFG Block " .. (value and "enabled" or "disabled"))
    end)

    lfgCheckbox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["AUTOMATICALLY_BLOCK_LEADER_OF_THE_GROUP"], 1, 1, 1, true)
        GameTooltip:SetClampedToScreen(true)
        if GameTooltip.SetMaximumWidth then
            GameTooltip:SetMaximumWidth(320)
        end
        GameTooltip:Show()
    end)

    lfgCheckbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local expireLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    expireLabel:SetPoint("TOPLEFT", lfgLabel, "BOTTOMLEFT", 0, -30)
    expireLabel:SetText(L["LFG_EXPIRE_LABEL"])

    local expireBox = CreateFrame("EditBox", "CrossIgnoreLFGExpireBox", parent, "InputBoxTemplate")
    expireBox:SetSize(50, 20)
    expireBox:SetPoint("LEFT", expireLabel, "RIGHT", 10, 0)
    expireBox:SetAutoFocus(false)
    expireBox:SetNumeric(true)
    expireBox:SetText(tostring(CrossIgnore.charDB.profile.settings.lfgExpireDays or 1))
    expireBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local expireOkayBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    expireOkayBtn:SetSize(60, 22)
    expireOkayBtn:SetPoint("TOPLEFT", expireLabel, "BOTTOMLEFT", 0, -12)
    expireOkayBtn:SetText(OKAY)

    local function SaveLFGExpiry()
        local days = tonumber(expireBox:GetText())
        if not days then
            expireBox:SetText(tostring(CrossIgnore.charDB.profile.settings.lfgExpireDays or 1))
            return
        end
        days = math.max(0, days)
        CrossIgnore.charDB.profile.settings.lfgExpireDays = days
        expireBox:SetText(tostring(days))
        expireBox:ClearFocus()
        CrossIgnore:Print(L["LFG_EXPIRE_SET"]:format(days == 0 and L["NEVER"] or days))
    end

    expireOkayBtn:SetScript("OnClick", SaveLFGExpiry)
    expireBox:SetScript("OnEnterPressed", SaveLFGExpiry)
end
