local _, ns = ...
local UI = ns.UI
local W = UI.Widgets
local M = {}
UI.ChatFilterPresets = M

local function Text(key)
    return ns.L[key] or ns.Locales.enUS[key] or key
end

local function Label(parent, text, x, y, width, font)
    local label = W:CreateLabel(parent, text, "TOPLEFT", x, y, font or "GameFontNormalSmall")
    label:SetWidth(width)
    label:SetJustifyH("LEFT")
    return label
end

local function MultiLine(parent, width, height, x, y)
    local scroll, child = W:CreateScrollFrame(parent, width, height, "TOPLEFT", x, y)
    local background = scroll:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0, 0, 0, 0.7)
    local box = CreateFrame("EditBox", nil, child)
    box:SetPoint("TOPLEFT", 5, -5)
    box:SetWidth(width - 10)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetMaxLetters(4096)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnTextChanged", function(self)
        child:SetHeight(math.max(height, self:GetHeight() + 10))
    end)
    box:SetScript("OnCursorChanged", function(self, _, cursorY, _, cursorHeight)
        local offset = scroll:GetVerticalScroll()
        local top = -cursorY
        if top < offset then scroll:SetVerticalScroll(math.max(0, top))
        elseif top + cursorHeight > offset + height then scroll:SetVerticalScroll(top + cursorHeight - height) end
    end)
    scroll:SetScript("OnMouseDown", function() box:SetFocus() end)
    return box
end

function M:ShowView(view)
    for key, frame in pairs(self.views) do frame:SetShown(key == view) end
    self.view = view
    if view == "list" then self:Refresh() end
    if view == "history" then self:RefreshHistory() end
end

function M:Build(panel, CrossIgnore)
    self.ChatFilter = CrossIgnore.ChatFilter
    self.rows = {}
    self.historyRows = {}
    local button = W:CreateButton(panel, Text("FILTER_PRESETS_HEADER"), "TOPRIGHT", -10, -10, 130, 24)
    button:SetNormalFontObject("GameFontNormalSmall")
    button:SetHighlightFontObject("GameFontHighlightSmall")
    local popup = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    popup:SetSize(425, 402)
    popup:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", 0, -4)
    popup:SetFrameLevel(panel:GetFrameLevel() + 20)
    popup:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    popup:SetBackdropColor(0.05, 0.05, 0.05, 1)
    popup:EnableMouse(true)
    popup:Hide()
    self.popup = popup
    self.title = Label(popup, Text("FILTER_PRESETS_HEADER"), 12, -12, 350, "GameFontNormal")
    W:CreateButton(popup, "X", "TOPRIGHT", -8, -8, 24, 22, function() popup:Hide() end)
    self.views = {}
    for _, key in ipairs({ "list", "editor", "history" }) do
        local frame = CreateFrame("Frame", nil, popup)
        frame:SetPoint("TOPLEFT", 0, -38)
        frame:SetPoint("BOTTOMRIGHT", 0, 0)
        frame:Hide()
        self.views[key] = frame
    end
    button:SetScript("OnClick", function()
        if popup:IsShown() then popup:Hide() else self:ShowView("list"); popup:Show() end
    end)
    panel:HookScript("OnHide", function() popup:Hide() end)
    self:BuildList()
    self:BuildEditor()
    self:BuildHistory()
    self.ChatFilter.OnRulesChanged = function()
        if not popup:IsShown() then return end
        if self.view == "list" then self:Refresh()
        elseif self.view == "history" then self:RefreshHistory()
        elseif self.view == "editor" then
            self.editorCount:SetText(string.format(Text("FILTER_RULE_COUNT_DETAIL"), self.editing and self.ChatFilter:GetRuleStore().counts[self.editing] or 0))
        end
    end
    self.built = true
    self:ShowView("list")
end

function M:BuildList()
    local view = self.views.list
    self.totalLabel = Label(view, "", 12, 0, 395, "GameFontHighlightSmall")
    Label(view, Text("FILTER_RULE_NAME"), 12, -26, 126)
    Label(view, Text("FILTER_RULE_ACTIVE"), 146, -26, 35)
    Label(view, Text("FILTER_RULE_COUNT"), 184, -26, 50)
    Label(view, Text("FILTER_RULE_EXPRESSION"), 240, -26, 160)
    self.listScroll, self.listContent = W:CreateScrollFrame(view, 384, 225, "TOPLEFT", 12, -46)
    local function selected() return self.selected and self.ChatFilter:GetRuleStore().rules[self.selected] end
    W:CreateButton(view, Text("FILTER_RULE_NEW"), "TOPLEFT", 12, -283, 68, 24, function() self:EditRule() end)
    W:CreateButton(view, Text("FILTER_RULE_EDIT"), "TOPLEFT", 88, -283, 68, 24, function()
        if selected() then self:EditRule(self.selected) end
    end)
    W:CreateButton(view, Text("FILTER_RULE_REMOVE"), "TOPLEFT", 164, -283, 72, 24, function()
        if selected() then self.ChatFilter:RemoveRule(self.selected); self.selected = nil; self:Refresh() end
    end)
    W:CreateButton(view, Text("FILTER_RULE_HISTORY"), "TOPLEFT", 244, -283, 77, 24, function()
        self.historyFilter = self.selected
        self:ShowView("history")
    end)
    W:CreateButton(view, Text("FILTER_RULE_DEFAULTS"), "TOPLEFT", 329, -283, 82, 24, function()
        StaticPopup_Show("CROSSIGNORE_RESTORE_FILTER_RULES")
    end)
    Label(view, Text("FILTER_RULE_LIST_HINT"), 12, -320, 395, "GameFontDisableSmall")
    StaticPopupDialogs["CROSSIGNORE_RESTORE_FILTER_RULES"] = {
        text = Text("FILTER_RULE_DEFAULTS_CONFIRM"), button1 = ACCEPT, button2 = CANCEL,
        OnAccept = function()
            for _, preset in ipairs(self.ChatFilter.presets) do self.ChatFilter:RestoreDefaultRule(preset.id) end
            self:Refresh()
        end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
end

function M:Refresh()
    if not self.built then return end
    local _, total = self.ChatFilter:GetFilteredMessageCounts()
    self.totalLabel:SetText(string.format(Text("FILTER_RULE_TOTAL"), total))
    local list = self.ChatFilter:GetRuleList()
    local selectedExists = false
    for _, rule in ipairs(list) do if rule.id == self.selected then selectedExists = true end end
    if not selectedExists then self.selected = nil end
    for _, row in ipairs(self.rows) do row:Hide() end
    for index, rule in ipairs(list) do
        local row = self.rows[index]
        if not row then
            row = CreateFrame("Button", nil, self.listContent)
            row:SetSize(384, 28)
            row.background = row:CreateTexture(nil, "BACKGROUND")
            row.background:SetAllPoints()
            row.name = Label(row, "", 0, -5, 128, "GameFontHighlightSmall")
            row.active = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            row.active:SetSize(20, 20)
            row.active:SetPoint("TOPLEFT", 135, -2)
            row.count = Label(row, "", 173, -5, 45, "GameFontHighlightSmall")
            row.expression = Label(row, "", 228, -5, 153, "GameFontHighlightSmall")
            row.name:SetWordWrap(false)
            row.expression:SetWordWrap(false)
            row:SetScript("OnClick", function(selfRow)
                self.selected = selfRow.rule.id
                self:Refresh()
            end)
            row:SetScript("OnDoubleClick", function(selfRow) self:EditRule(selfRow.rule.id) end)
            row:SetScript("OnEnter", function(selfRow)
                GameTooltip:SetOwner(selfRow, "ANCHOR_RIGHT")
                GameTooltip:SetText(selfRow.rule.name)
                GameTooltip:AddLine(selfRow.rule.expression, 1, 1, 1, true)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            row.active:SetScript("OnClick", function(checkbox)
                self.ChatFilter:SetPresetEnabled(row.rule.id, checkbox:GetChecked())
            end)
            self.rows[index] = row
        end
        row.rule = rule
        row:SetPoint("TOPLEFT", 0, -(index - 1) * 28)
        row.name:SetText(rule.name)
        row.expression:SetText(rule.expression)
        row.count:SetText(tostring(rule.count))
        row.active:SetChecked(rule.enabled)
        if rule.id == self.selected then row.background:SetColorTexture(0.3, 0.3, 0.1, 0.9)
        else row.background:SetColorTexture(0.12, 0.12, 0.12, index % 2 == 0 and 0.8 or 0.3) end
        row:Show()
    end
    self.listContent:SetHeight(math.max(225, #list * 28))
end

function M:BuildEditor()
    local view = self.views.editor
    self.editorCount = Label(view, "", 12, 0, 390, "GameFontHighlightSmall")
    self.nameBox = W:CreateEditBox(view, 340, 24, "TOPLEFT", 16, -26)
    self.nameBox:SetMaxLetters(120)
    self.enabledBox = CreateFrame("CheckButton", nil, view, "UICheckButtonTemplate")
    self.enabledBox:SetSize(22, 22)
    self.enabledBox:SetPoint("TOPLEFT", 375, -26)
    self.enabledBox:SetScript("OnEnter", function(box)
        GameTooltip:SetOwner(box, "ANCHOR_RIGHT"); GameTooltip:SetText(Text("FILTER_RULE_ACTIVE")); GameTooltip:Show()
    end)
    self.enabledBox:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Label(view, Text("FILTER_RULE_EXPRESSION"), 12, -62, 300)
    W:CreateButton(view, Text("FILTER_RULE_HELP"), "TOPRIGHT", -15, -58, 55, 22, function()
        GameTooltip:SetOwner(self.ruleBox, "ANCHOR_RIGHT")
        GameTooltip:SetText(Text("FILTER_RULE_HELP"))
        GameTooltip:AddLine(Text("FILTER_RULE_HELP_TEXT"), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    self.ruleBox = MultiLine(view, 380, 110, 12, -85)
    Label(view, Text("FILTER_RULE_TEST_MESSAGE"), 12, -205, 285)
    W:CreateButton(view, Text("FILTER_RULE_TEST"), "TOPRIGHT", -15, -201, 55, 22, function()
        local matched, err = self.ChatFilter:TestRule(self.ruleBox:GetText(), self.testBox:GetText())
        self.result:SetText(err or (matched and Text("FILTER_RULE_TEST_BLOCKED") or Text("FILTER_RULE_TEST_ALLOWED")))
    end)
    self.testBox = MultiLine(view, 380, 48, 12, -230)
    self.result = Label(view, "", 12, -284, 390, "GameFontHighlightSmall")
    W:CreateButton(view, Text("FILTER_RULE_SAVE"), "TOPLEFT", 12, -326, 110, 24, function()
        local id, err = self.ChatFilter:SaveRule(self.editing, self.nameBox:GetText(), self.ruleBox:GetText(), self.enabledBox:GetChecked())
        if not id then self.result:SetText(err); return end
        self.selected = id
        self.nameBox:ClearFocus(); self.ruleBox:ClearFocus(); self.testBox:ClearFocus()
        self:ShowView("list")
    end)
    W:CreateButton(view, Text("FILTER_RULE_CANCEL"), "TOPLEFT", 132, -326, 110, 24, function() self:ShowView("list") end)
    self.resetButton = W:CreateButton(view, Text("FILTER_RULE_RESET"), "TOPLEFT", 252, -326, 155, 24, function()
        for _, preset in ipairs(self.ChatFilter.presets) do
            if preset.id == self.editing then
                self.nameBox:SetText(Text(preset.label)); self.ruleBox:SetText(preset.expression)
                self.enabledBox:SetChecked(false); self.result:SetText(""); return
            end
        end
    end)
end

function M:EditRule(id)
    self.editing = id
    local rule = id and self.ChatFilter:GetRuleStore().rules[id]
    local name = ""
    if rule then
        for _, entry in ipairs(self.ChatFilter:GetRuleList()) do if entry.id == id then name = entry.name end end
    end
    self.nameBox:SetText(name)
    self.ruleBox:SetText(rule and rule.expression or "")
    self.enabledBox:SetChecked(rule and rule.enabled or false)
    self.testBox:SetText("")
    self.result:SetText("")
    self.editorCount:SetText(string.format(Text("FILTER_RULE_COUNT_DETAIL"), id and self.ChatFilter:GetRuleStore().counts[id] or 0))
    local isDefault = false
    for _, preset in ipairs(self.ChatFilter.presets) do if preset.id == id then isDefault = true end end
    self.resetButton:SetShown(isDefault)
    self:ShowView("editor")
end

function M:BuildHistory()
    local view = self.views.history
    self.historyTitle = Label(view, "", 12, 0, 395, "GameFontHighlightSmall")
    self.historyScroll, self.historyContent = W:CreateScrollFrame(view, 380, 285, "TOPLEFT", 12, -26)
    W:CreateButton(view, Text("FILTER_RULE_BACK"), "TOPLEFT", 12, -326, 105, 24, function() self:ShowView("list") end)
    W:CreateButton(view, Text("FILTER_RULE_ALL_HISTORY"), "TOPLEFT", 130, -326, 160, 24, function()
        self.historyFilter = nil; self:RefreshHistory()
    end)
end

function M:RefreshHistory()
    local entries = self.ChatFilter:GetBlockHistory(self.historyFilter)
    self.historyTitle:SetText(string.format(Text("FILTER_RULE_HISTORY_DETAIL"), #entries))
    for _, row in ipairs(self.historyRows) do row:Hide() end
    local y = 0
    for index, entry in ipairs(entries) do
        local row = self.historyRows[index]
        if not row then
            row = CreateFrame("Frame", nil, self.historyContent)
            row:SetWidth(380)
            row.text = Label(row, "", 3, -4, 370, "GameFontHighlightSmall")
            row:EnableMouse(true)
            row:SetScript("OnEnter", function(selfRow)
                GameTooltip:SetOwner(selfRow, "ANCHOR_RIGHT")
                GameTooltip:SetText(selfRow.entry.word)
                GameTooltip:AddLine(selfRow.entry.expression or selfRow.entry.word, 1, 1, 1, true)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            self.historyRows[index] = row
        end
        row.entry = entry
        row:SetPoint("TOPLEFT", 0, -y)
        row.text:SetText(string.format("|cffffd100%s | %s | %s|r\n%s: %s\n%s",
            entry.time or "", entry.chatChannel or entry.channel or "", entry.word or "",
            entry.sender or "", entry.message or "", entry.expression or entry.word or ""))
        local height = row.text:GetStringHeight() + 14
        row:SetHeight(height)
        row:Show()
        y = y + height
    end
    if #entries == 0 then self.historyTitle:SetText(Text("FILTER_RULE_HISTORY_EMPTY")) end
    self.historyContent:SetHeight(math.max(285, y))
end
