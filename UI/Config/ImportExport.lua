local _, ns = ...
local L = ns.L
local CrossIgnore = ns.Addon
local LibDeflate = LibStub("LibDeflate")

function CrossIgnore:CreateEIOptions(parent)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    label:SetPoint("TOP", 0, -12)
    label:SetText(L["OPTIONS_E_I"])

    local eiLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    eiLabel:SetPoint("TOPLEFT", 10, -50)
    eiLabel:SetText(L["OPTIONS_E_I"])

    local exportScroll = CreateFrame("ScrollFrame", "CrossIgnoreExportScroll", parent, "UIPanelScrollFrameTemplate")
    exportScroll:SetSize(400, 150)
    exportScroll:SetPoint("TOPLEFT", eiLabel, "BOTTOMLEFT", 0, -10)

    local exportBox = CreateFrame("EditBox", "CrossIgnoreExportBox", exportScroll)
    exportBox:SetMultiLine(true)
    exportBox:SetFontObject(ChatFontNormal)
    exportBox:SetWidth(400)
    exportBox:SetHeight(150)
    exportBox:SetAutoFocus(false)
    exportBox:SetText("")
    exportBox:SetScript("OnEscapePressed", function() exportBox:ClearFocus() end)
    exportScroll:SetScrollChild(exportBox)

    local exportBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    exportBtn:SetSize(100, 22)
    exportBtn:SetPoint("TOP", exportScroll, "BOTTOM", 0, -5)
    exportBtn:SetText(L["OPTIONS_EXPORT"])
    exportBtn:SetScript("OnClick", function()
        local filters = CrossIgnore.ChatFilter:GetFilters()
        if filters then
            local humanReadable = CrossIgnore:SerializeHuman(filters)
            local compressed = LibDeflate:CompressDeflate(humanReadable, { level = 9 })
            local encoded = LibDeflate:EncodeForPrint(compressed)
            exportBox:SetText(encoded)
            exportBox:HighlightText()
            exportBox:SetFocus()
        end
    end)

    local importScroll = CreateFrame("ScrollFrame", "CrossIgnoreImportScroll", parent, "UIPanelScrollFrameTemplate")
    importScroll:SetSize(400, 150)
    importScroll:SetPoint("TOPLEFT", exportScroll, "BOTTOMLEFT", 0, -30)

    local importBox = CreateFrame("EditBox", "CrossIgnoreImportBox", importScroll)
    importBox:SetMultiLine(true)
    importBox:SetFontObject(ChatFontNormal)
    importBox:SetWidth(400)
    importBox:SetHeight(150)
    importBox:SetAutoFocus(false)
    importBox:SetText(L["OPTIONS_PRINT1"])
    importBox:SetScript("OnEscapePressed", function() importBox:ClearFocus() end)
    importBox:SetScript("OnMouseDown", function(self)
        if self:GetText() == (L["OPTIONS_PRINT1"]) then
            self:SetText("")
        end
        self:HighlightText()
        self:SetFocus()
    end)
    importScroll:SetScrollChild(importBox)

    local importBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    importBtn:SetSize(100, 22)
    importBtn:SetPoint("TOP", importScroll, "BOTTOM", 0, -5)
    importBtn:SetText(L["OPTIONS_IMPORT"])
    importBtn:SetScript("OnClick", function()
        local text = importBox:GetText()
        if text and text ~= "" then
            local success, filters = pcall(function()
                local decoded = LibDeflate:DecodeForPrint(text)
                if not decoded then error("Decoding failed") end
                local decompressed = LibDeflate:DecompressDeflate(decoded)
                if not decompressed then error("Decompression failed") end
                return CrossIgnore:DeserializeHuman(decompressed)
            end)

            if success and filters then
                CrossIgnoreDB.global = CrossIgnoreDB.global or {}
                CrossIgnoreDB.global.filters = CrossIgnoreDB.global.filters or {}
                CrossIgnoreDB.global.filters.words = filters

                if CrossIgnore.ChatFilter and CrossIgnore.ChatFilter.UpdateWordsList then
                    CrossIgnore.ChatFilter:UpdateWordsList()
                end
                print(L["OPTIONS_PRINT2"])
            else
                print(L["OPTIONS_PRINT3"])
            end
        end
    end)
end
