local _, ns = ...
local L = ns.L
local CrossIgnore = ns.Addon

function CrossIgnore:CreateEIOptions(parent)
    local widgets = ns.UI.Widgets
    widgets:CreateLabel(parent, L["OPTIONS_E_I"], "TOP", 0, -12, "GameFontHighlightLarge")

    local function createTransferBox(name, top, boxHeight)
        local scroll, child = widgets:CreateScrollFrame(parent, 400, boxHeight, "TOPLEFT", 12, top)
        child:SetPoint("TOPLEFT", scroll, "TOPLEFT")
        local background = scroll:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0, 0, 0, 0.6)

        local box = CreateFrame("EditBox", name, child)
        box:SetPoint("TOPLEFT", 5, -5)
        box:SetWidth(390)
        box:SetMultiLine(true)
        box:SetAutoFocus(false)
        box:SetFontObject("ChatFontNormal")
        local _, fontHeight = box:GetFont()
        box:SetMaxBytes(0)
        box:SetMaxLetters(0)
        box:SetHeight(boxHeight - 10)
        box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        box:SetScript("OnTextChanged", function(self)
            local textHeight = (self:GetNumLines() or 1) * (fontHeight or 14)
            local height = math.max(boxHeight - 10, textHeight)
            self:SetHeight(height)
            child:SetHeight(height + 10)
        end)
        box:SetScript("OnCursorChanged", function(_, _, y, _, height)
            local offset = scroll:GetVerticalScroll()
            local cursorTop = -y
            if cursorTop < offset then
                scroll:SetVerticalScroll(math.max(0, cursorTop))
            elseif cursorTop + height > offset + boxHeight then
                scroll:SetVerticalScroll(cursorTop + height - boxHeight)
            end
        end)
        scroll:SetScript("OnMouseDown", function() box:SetFocus() end)
        return box
    end

    local function createCheckbox(text, x, y)
        local box = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        box:SetSize(24, 24)
        box:SetPoint("TOPLEFT", x, y)
        box:SetChecked(true)
        local label = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("LEFT", box, "RIGHT", 3, 0)
        label:SetText(text)
        box:SetHitRectInsets(0, -label:GetStringWidth() - 3, 0, 0)
        return box
    end

    local exportBox = createTransferBox("CrossIgnoreExportBox", -42, 110)
    local importBox = createTransferBox("CrossIgnoreImportBox", -198, 110)
    widgets:AttachPlaceholder(importBox, L["OPTIONS_PRINT1"])

    widgets:CreateLabel(parent, L["OPTIONS_IMPORT_CATEGORIES"], "TOPLEFT", 12, -321)
    local categories = {
        words = createCheckbox(L["OPTIONS_IMPORT_WORDS"], 12, -341),
        rules = createCheckbox(L["OPTIONS_IMPORT_RULES"], 225, -341),
        players = createCheckbox(L["IGNORE_LIST_HEADER"], 12, -368),
        guilds = createCheckbox(L["OPTIONS_IMPORT_GUILDS"], 225, -368),
    }

    widgets:CreateButton(parent, L["OPTIONS_EXPORT"], "TOP", 0, -160, 112, 24, function()
        local ok, text = pcall(CrossIgnore.ExportLists, CrossIgnore)
        if not ok or not text then
            CrossIgnore:Print(L["OPTIONS_EXPORT_FAILED"])
            return
        end
        exportBox:SetText(text)
        exportBox:SetFocus()
        exportBox:HighlightText()
    end)

    local importButton = widgets:CreateButton(parent, L["OPTIONS_IMPORT"], "TOP", 0, -407, 112, 24, function()
        local selected = {}
        for category, box in pairs(categories) do selected[category] = box:GetChecked() end

        local imported, skippedRules, skippedPlayers = CrossIgnore:ImportLists(importBox:GetText(), selected)
        if imported == nil then
            CrossIgnore:Print(L["OPTIONS_PRINT3"])
            return
        elseif not imported then
            CrossIgnore:Print(L["OPTIONS_IMPORT_NO_MATCH"])
            return
        end

        importBox:SetText("")
        importBox:ClearFocus()
        CrossIgnore:Print(L["OPTIONS_PRINT2"])
        if skippedRules > 0 or skippedPlayers > 0 then
            CrossIgnore:Print(L["OPTIONS_TRANSFER_SKIPPED"]:format(skippedPlayers, skippedRules))
        end
    end)

    for _, box in pairs(categories) do
        box:HookScript("OnClick", function()
            for _, category in pairs(categories) do
                if category:GetChecked() then
                    importButton:Enable()
                    return
                end
            end
            importButton:Disable()
        end)
    end
end
