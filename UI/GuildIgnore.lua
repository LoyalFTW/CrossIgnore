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

    self.empty = W:CreateLabel(panel, T("GUILD_IGNORE_EMPTY"), "TOPLEFT", 26, -215, "GameFontDisable")

    W:CreateButton(panel, T("GUILD_IGNORE_REMOVE"), "TOPLEFT", 15, -347, 145, 24, function()
        if not M.selected then
            addon:Print(T("GUILD_IGNORE_SELECT"))
            return
        end
        addon.GuildIgnore:RemoveGuild(M.selected)
        M.selected = nil
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
            row.text:SetWidth(345)
            row.text:SetJustifyH("LEFT")
            row:SetScript("OnClick", function(selfRow)
                M.selected = selfRow.guildName
                M:Refresh()
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
end

return M
