local addonName, addonTable = ...
local L = addonTable.L
local UI = addonTable.UI
local W = UI.Widgets
local function T(key)
    return L[key] or addonTable.Locales.enUS[key]
end

local M = {}
UI.GuildIgnore = M

function M:Build(panel, addon)
    self.panel = panel
    self.addon = addon
    self.rows = {}

    local title = W:CreateLabel(panel, T("GUILD_IGNORE_TAB"), "TOPLEFT", 15, -15, "GameFontHighlightLarge")

    local explanation = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    explanation:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    explanation:SetWidth(415)
    explanation:SetJustifyH("LEFT")
    explanation:SetText(T("GUILD_IGNORE_EXPLAIN"))

    local bubbles = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    bubbles:SetPoint("TOPLEFT", explanation, "BOTTOMLEFT", 0, -8)
    bubbles:SetWidth(415)
    bubbles:SetJustifyH("LEFT")
    bubbles:SetText(T("GUILD_IGNORE_BUBBLES"))

    local nameBox = W:CreateEditBox(panel, 280, 24, "TOPLEFT", 15, -160)
    W:AttachPlaceholder(nameBox, T("GUILD_IGNORE_NAME"))
    self.nameBox = nameBox

    local function AddGuild()
        local name = strtrim(nameBox:GetText() or "")
        if name == "" then
            addon:Print(T("GUILD_IGNORE_INVALID"))
        elseif addon.GuildIgnore:AddGuild(name) then
            nameBox:SetText("")
            nameBox:ClearFocus()
            M:Refresh()
        else
            addon:Print(T("GUILD_IGNORE_EXISTS"))
        end
    end

    W:CreateButton(panel, T("GUILD_IGNORE_ADD"), "TOPLEFT", 305, -160, 125, 24, AddGuild)
    nameBox:SetScript("OnEnterPressed", AddGuild)
    nameBox:SetScript("OnEscapePressed", nameBox.ClearFocus)

    local list = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    list:SetPoint("TOPLEFT", 15, -195)
    list:SetSize(415, 145)
    list:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })

    local scroll = CreateFrame("ScrollFrame", nil, list, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -26, 6)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(380, 145)
    scroll:SetScrollChild(content)
    self.content = content

    local details = CreateFrame("Frame", nil, UI.Frames.main, "BackdropTemplate")
    details:SetSize(310, 405)
    details:SetFrameStrata("DIALOG")
    details:SetClampedToScreen(true)
    details:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 5, right = 5, top = 5, bottom = 5 } })
    details:Hide()
    self.details = details
    self.memberRows = {}
    self.memberTitle = W:CreateLabel(details, "", "TOPLEFT", 16, -16, "GameFontHighlightLarge")
    self.memberTitle:SetWidth(250)
    self.memberTitle:SetJustifyH("LEFT")
    W:CreateButton(details, "X", "TOPRIGHT", -12, -12, 24, 24, function() details:Hide() end)
    self.memberCount = W:CreateLabel(details, "", "TOPLEFT", 16, -43, "GameFontHighlightSmall")
    W:CreateLabel(details, T("GUILD_IGNORE_RETENTION"), "TOPLEFT", 16, -66, "GameFontNormalSmall")
    self.retentionButtons = {}
    for i, option in ipairs({ { 1, "GUILD_IGNORE_RETENTION_DAY" }, { 7, "GUILD_IGNORE_RETENTION_WEEK" }, { 30, "GUILD_IGNORE_RETENTION_MONTH" } }) do
        local days = option[1]
        self.retentionButtons[days] = W:CreateButton(details, T(option[2]), "TOPLEFT", 14 + (i - 1) * 94, -83, 90, 22, function()
            if M.selected and addon.GuildIgnore:SetRetentionDays(M.selected, days) then M:RefreshMembers() end
        end)
    end
    self.memberEmpty = W:CreateLabel(details, T("GUILD_IGNORE_MEMBERS_EMPTY"), "TOPLEFT", 18, -137, "GameFontDisable")
    self.memberEmpty:SetWidth(270)
    self.memberEmpty:SetJustifyH("LEFT")
    local memberScroll = CreateFrame("ScrollFrame", nil, details, "UIPanelScrollFrameTemplate")
    memberScroll:SetPoint("TOPLEFT", 12, -120)
    memberScroll:SetPoint("BOTTOMRIGHT", -30, 14)
    local memberContent = CreateFrame("Frame", nil, memberScroll)
    memberContent:SetSize(265, 270)
    memberScroll:SetScrollChild(memberContent)
    self.memberContent = memberContent
    panel:HookScript("OnHide", function() details:Hide() end)

    self.empty = W:CreateLabel(panel, T("GUILD_IGNORE_EMPTY"), "TOPLEFT", 26, -215, "GameFontDisable")

    W:CreateButton(panel, T("GUILD_IGNORE_REMOVE"), "TOPLEFT", 15, -347, 145, 24, function()
        if not M.selected then
            addon:Print(T("GUILD_IGNORE_SELECT"))
            return
        end
        addon.GuildIgnore:RemoveGuild(M.selected)
        M.selected = nil
        M.details:Hide()
        M:Refresh()
    end)

    local lookupBox = W:CreateEditBox(panel, 275, 24, "TOPLEFT", 15, -393)
    W:AttachPlaceholder(lookupBox, T("GUILD_IGNORE_PLAYER"))
    W:CreateButton(panel, T("GUILD_IGNORE_LOOKUP"), "TOPLEFT", 300, -393, 130, 24, function()
        local name = strtrim(lookupBox:GetText() or "")
        if name ~= "" and not addon.GuildIgnore:LookUpPlayer(name) then
            addon:Print(T("GUILD_IGNORE_LOOKUP_UNAVAILABLE"))
        end
    end)
    lookupBox:SetScript("OnEnterPressed", function()
        local name = strtrim(lookupBox:GetText() or "")
        if name ~= "" and not addon.GuildIgnore:LookUpPlayer(name) then
            addon:Print(T("GUILD_IGNORE_LOOKUP_UNAVAILABLE"))
        end
        lookupBox:ClearFocus()
    end)
    lookupBox:SetScript("OnEscapePressed", lookupBox.ClearFocus)

    local inviteCheckbox = CreateFrame("CheckButton", nil, panel, "ChatConfigCheckButtonTemplate")
    inviteCheckbox:SetPoint("TOPLEFT", 15, -422)
    inviteCheckbox:SetChecked(addon.globalDB.global.guildAutoDeclineInvites ~= false)
    inviteCheckbox:SetScript("OnClick", function(button)
        addon.globalDB.global.guildAutoDeclineInvites = button:GetChecked() and true or false
    end)
    local inviteLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    inviteLabel:SetPoint("LEFT", inviteCheckbox, "RIGHT", 4, 0)
    inviteLabel:SetText(T("GUILD_IGNORE_AUTO_DECLINE"))
end

function M:Refresh()
    if not self.content then return end
    local names = {}
    for _, name in pairs(self.addon.GuildIgnore:GetRules()) do names[#names + 1] = name end
    table.sort(names, function(a, b) return a:lower() < b:lower() end)
    self.empty:SetShown(#names == 0)
    for i, name in ipairs(names) do
        local row = self.rows[i]
        if not row then
            row = CreateFrame("Button", nil, self.content)
            row:SetSize(365, 22)
            row:SetPoint("TOPLEFT", 0, -((i - 1) * 22))
            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.text:SetPoint("LEFT", 8, 0)
            row.text:SetWidth(320)
            row.text:SetJustifyH("LEFT")
            row.arrow = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.arrow:SetPoint("RIGHT", -8, 0)
            row.arrow:SetText(">")
            row:SetScript("OnEnter", function(selfRow)
                selfRow.arrow:SetTextColor(1, 0.82, 0)
            end)
            row:SetScript("OnLeave", function(selfRow)
                selfRow.arrow:SetTextColor(0.9, 0.9, 0.9)
            end)
            row:SetScript("OnClick", function(selfRow)
                M.selected = selfRow.guildName
                M:Refresh()
                M:ShowMembers()
            end)
            self.rows[i] = row
        end
        row.guildName = name
        row.text:SetText(name)
        row.text:SetTextColor(self.selected == name and 1 or 0.9, self.selected == name and 0.82 or 0.9, self.selected == name and 0 or 0.9)
        row:Show()
    end
    for i = #names + 1, #self.rows do self.rows[i]:Hide() end
    self.content:SetHeight(math.max(145, #names * 22))
    if self.selected and not self.addon.GuildIgnore:IsGuildBlocked(self.selected) then
        self.selected = nil
        self.details:Hide()
    elseif self.details:IsShown() then
        self:RefreshMembers()
    end
end

function M:ShowMembers()
    if not self.selected then return end
    local details = self.details
    details:ClearAllPoints()
    local right = UI.Frames.main:GetRight()
    local screenRight = UIParent:GetRight()
    if right and screenRight and screenRight - right >= details:GetWidth() + 8 then
        details:SetPoint("TOPLEFT", UI.Frames.main, "TOPRIGHT", 4, -42)
    else
        details:SetPoint("TOPRIGHT", UI.Frames.main, "TOPLEFT", -4, -42)
    end
    details:Show()
    self:RefreshMembers()
end

function M:RefreshMembers()
    if not self.selected or not self.details or not self.details:IsShown() then return end
    local players = self.addon.GuildIgnore:GetKnownPlayersForGuild(self.selected)
    local retention = self.addon.GuildIgnore:GetRetentionDays(self.selected)
    self.memberTitle:SetText(self.selected)
    self.memberCount:SetText(string.format(T("GUILD_IGNORE_MEMBERS_COUNT"), #players))
    for days, button in pairs(self.retentionButtons) do
        if days == retention then button:LockHighlight() else button:UnlockHighlight() end
    end
    self.memberEmpty:SetShown(#players == 0)
    for i, player in ipairs(players) do
        local row = self.memberRows[i]
        if not row then
            row = CreateFrame("Frame", nil, self.memberContent)
            row:SetSize(265, 23)
            row:SetPoint("TOPLEFT", 0, -((i - 1) * 23))
            row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.name:SetPoint("LEFT", 5, 0)
            row.name:SetWidth(155)
            row.name:SetJustifyH("LEFT")
            row.seen = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            row.seen:SetPoint("RIGHT", -2, 0)
            row.seen:SetWidth(95)
            row.seen:SetJustifyH("RIGHT")
            self.memberRows[i] = row
        end
        row.name:SetText(player.name)
        row.seen:SetText(date("%b %d %H:%M", player.seen))
        row:Show()
    end
    for i = #players + 1, #self.memberRows do self.memberRows[i]:Hide() end
    self.memberContent:SetHeight(math.max(270, #players * 23))
end

return M
