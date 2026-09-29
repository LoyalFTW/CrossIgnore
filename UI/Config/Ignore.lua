local _, ns = ...
local CrossIgnore = ns.Addon
local L = ns.L

function CrossIgnore:CreateIgnoreOptions(parent)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    label:SetPoint("TOP", 0, -12)
    label:SetText(L["OPTIONS_IGNORE"])

    local expireLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    expireLabel:SetPoint("TOPLEFT", 10, -50)
    expireLabel:SetText(L["DEFAULT_EXPIRE_LABEL"])

    local expireBox = CreateFrame("EditBox", "CrossIgnoreDefaultExpireBox", parent, "InputBoxTemplate")
    expireBox:SetSize(50, 20)
    expireBox:SetPoint("LEFT", expireLabel, "RIGHT", 10, 0)
    expireBox:SetAutoFocus(false)
    expireBox:SetNumeric(true)

    local defaultDays = CrossIgnore.charDB.profile.settings.defaultExpireDays or 0
    expireBox:SetText(tostring(defaultDays))

    local expireOkayBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    expireOkayBtn:SetSize(60, 22)
    expireOkayBtn:SetPoint("LEFT", expireBox, "RIGHT", 10, 0)
    expireOkayBtn:SetText(OKAY)

    expireOkayBtn:SetScript("OnClick", function()
        local days = tonumber(expireBox:GetText()) or 0
        if days < 0 then days = 0 end
        CrossIgnore.charDB.profile.settings.defaultExpireDays = days
        print(L["DEFAULT_EXPIRE_SET"]:format((days == 0 and L["NEVER"] or days)))
    end)

    local autoReplyLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    autoReplyLabel:SetPoint("TOPLEFT", expireLabel, "BOTTOMLEFT", 0, -40)
    autoReplyLabel:SetText(L["AUTO_REPLY_ENABLE_CHECK"])

    local autoReplyCheckbox = CreateFrame("CheckButton", "CrossIgnoreAutoReplyCheckbox", parent, "ChatConfigCheckButtonTemplate")
    autoReplyCheckbox:SetPoint("LEFT", autoReplyLabel, "RIGHT", 10, 0)
    autoReplyCheckbox:SetChecked(CrossIgnore.charDB.profile.settings.autoReplyEnabled or false)
    autoReplyCheckbox:SetScript("OnClick", function(button)
        local value = button:GetChecked()
        CrossIgnore.charDB.profile.settings.autoReplyEnabled = value
    end)

    local autoReplyBox = CreateFrame("EditBox", "CrossIgnoreAutoReplyBox", parent, "InputBoxTemplate")
    autoReplyBox:SetSize(300, 40)
    autoReplyBox:SetPoint("TOPLEFT", autoReplyLabel, "BOTTOMLEFT", 0, -10)
    autoReplyBox:SetAutoFocus(false)
    autoReplyBox:SetMultiLine(true)
    autoReplyBox:SetText(CrossIgnore.charDB.profile.settings.autoReplyMessage)

    local autoReplyOkayBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    autoReplyOkayBtn:SetSize(60, 22)
    autoReplyOkayBtn:SetPoint("LEFT", autoReplyBox, "RIGHT", 10, 0)
    autoReplyOkayBtn:SetText(OKAY)

    autoReplyOkayBtn:SetScript("OnClick", function()
        local msg = autoReplyBox:GetText()
        CrossIgnore.charDB.profile.settings.autoReplyMessage = msg
    end)

    local blizzLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    blizzLabel:SetPoint("TOPLEFT", autoReplyBox, "BOTTOMLEFT", 0, -18)
    blizzLabel:SetText(L["HIDE_BLIZZ_ENABLE_CHECK"])

    local blizzCheckbox = CreateFrame("CheckButton", "CrossIgnoreHideBlizzCheckbox", parent, "ChatConfigCheckButtonTemplate")
    blizzCheckbox:SetPoint("LEFT", blizzLabel, "RIGHT", 10, 0)
    blizzCheckbox:SetChecked(CrossIgnore.charDB.profile.settings.hideBlizzardMessages or false)
    blizzCheckbox:SetScript("OnClick", function(button)
        local value = button:GetChecked()
        CrossIgnore.charDB.profile.settings.hideBlizzardMessages = value and true or false
    end)
end
