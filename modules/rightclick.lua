local addonName, addonTable = ...
local L = addonTable.L

local CrossIgnoreMenuFrame = CreateFrame("Frame", "CrossIgnoreMenuFrame", UIParent, "UIDropDownMenuTemplate")
CrossIgnoreMenuFrame:SetFrameStrata("TOOLTIP")
CrossIgnoreMenuFrame:Hide()

local function ShowStyledDropdown(items, anchorFrame)
    local function initialize(self, level)
        if not level then return end
        for _, item in ipairs(items) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = item.text
            info.func = item.func
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_Initialize(CrossIgnoreMenuFrame, initialize, "MENU")
    ToggleDropDownMenu(1, nil, CrossIgnoreMenuFrame, anchorFrame, 0, 0)
end

local function CreateCustomPopup(title, defaultText, onAccept)
    local frame = CreateFrame("Frame", "CrossIgnorePopupFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(300, 100)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    frame.titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.titleText:SetPoint("TOP", 0, -10)
    frame.titleText:SetText(title)

    frame.editBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    frame.editBox:SetSize(260, 25)
    frame.editBox:SetPoint("TOP", frame.titleText, "BOTTOM", 0, -10)
    frame.editBox:SetAutoFocus(true)
    frame.editBox:SetText(defaultText or "")

    frame.acceptBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.acceptBtn:SetSize(80, 25)
    frame.acceptBtn:SetPoint("BOTTOMLEFT", 20, 10)
    frame.acceptBtn:SetText("Save")
    frame.acceptBtn:SetScript("OnClick", function()
        if onAccept then onAccept(frame.editBox:GetText()) end
        frame:Hide()
    end)

    frame.cancelBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.cancelBtn:SetSize(80, 25)
    frame.cancelBtn:SetPoint("BOTTOMRIGHT", -20, 10)
    frame.cancelBtn:SetText("Cancel")
    frame.cancelBtn:SetScript("OnClick", function()
        frame:Hide()
    end)

    return frame, frame.editBox
end

function CrossIgnore:ShowSetExpiryPopup(entry)
    if not entry then return end

    local defaultDays = CrossIgnore.charDB
        and CrossIgnore.charDB.profile
        and CrossIgnore.charDB.profile.settings.defaultExpireDays
        or 0

    local title = string.format(L["SET_EXPIRATION"], entry.name or "Unknown")

    local popup, editBox = CreateCustomPopup(
        title,
        tostring(defaultDays),
        function(daysText)
            local days = tonumber(daysText)
            if not days or days < 0 then return end

            local expiresAt = (days > 0) and (time() + (days * 86400)) or 0

            local newEntry = {
                name = entry.name,
                server = entry.server,
                firstName = entry.firstName,
                lastName = entry.lastName,
                expires = expiresAt,
                lastModifiedExpires = time(),
            }

            CrossIgnore:EnsureGlobalPresence(newEntry, CrossIgnore.charDB.profile.settings.maxIgnoreLimit or 50)
            CrossIgnore:SyncLocalToGlobal()
            CrossIgnore:RefreshBlockedList()

            print(L["PLAYER_EXPIRE_SET"]:format(entry.name, (days == 0 and L["NEVER"] or days)))
        end
    )

    popup:Show()
    editBox:SetFocus()
end

function CrossIgnore:ShowContextMenu(anchorFrame, playerData)
    local menuItems = {
        {
            text = L["EDIT_NOTE"],
            func = function()
                self:ShowEditNotePopup(playerData)
            end
        },
        {
            text = L["SET_EXPIRY"],
            func = function()
                self:ShowSetExpiryPopup(playerData)
            end
        },
        {
            text = L["REMOVE_ENTRY"],
            func = function()
                local fullName = playerData.name .. (playerData.server and playerData.server ~= "" and ("-" .. playerData.server) or "")
                CrossIgnore:DelIgnore(fullName)
                CrossIgnore:RefreshBlockedList()
            end
        },
        { text = L["CANCEL"], func = function() end }
    }

    ShowStyledDropdown(menuItems, anchorFrame)
end

function CrossIgnore:ShowWordContextMenu(anchorFrame, entry)
    local menuItems = {
        {
            text = L["EDIT_WORD"],
            func = function()
                self:ShowEditWordPopup(entry)
            end
        },
        {
            text = L["REMOVE_WORD"],
            func = function()
                self:RemoveSelectedWord(entry)
            end
        },
        { text = L["CANCEL"], func = function() end }
    }

    ShowStyledDropdown(menuItems, anchorFrame)
end

function CrossIgnore:ShowEditWordPopup(entry)
    if not entry then return end

    local popup, editBox = CreateCustomPopup(
        L["EDIT_BLOCKED_WORD"],
        entry.word or "",
        function(newWord)
            if newWord == "" then return end

            local channelName = entry.channelName or entry.channel
            local wordIndex = entry.wordIndex

            if CrossIgnoreDB
                and CrossIgnoreDB.global
                and CrossIgnoreDB.global.filters
                and CrossIgnoreDB.global.filters.words
                and CrossIgnoreDB.global.filters.words[channelName]
                and CrossIgnoreDB.global.filters.words[channelName][wordIndex]
            then
                CrossIgnoreDB.global.filters.words[channelName][wordIndex] = {
                    word = newWord,
                    normalized = newWord:lower(),
                }
            end

            entry.word = newWord
            entry.normalized = newWord:lower()

            self:UpdateWordsList(_G.CrossIgnoreUI.searchBox:GetText() or "")
        end
    )

    popup:Show()
    editBox:SetFocus()
end

function CrossIgnore:ShowEditNotePopup(entry)
    if not entry then return end

    local popup, editBox = CreateCustomPopup(
        string.format(L["EDIT_NOTE_FOR"], entry.name or "Unknown"),
        entry.note or "",
        function(newNote)
            entry.note = newNote
            entry.lastModifiedNote = time()
            self:RefreshBlockedList()
        end
    )

    popup:Show()
    editBox:SetFocus()
end

function CrossIgnore:RemoveSelectedWord(entry)
    if not entry then return end

    local word = entry.word or entry.normalized
    if not word or word == "" then return end

    local channel = entry.channel or entry.channelName or L["CHANNEL_ALL"]
    if self.ChatFilter and self.ChatFilter.NormalizeChannelKey then
        channel = self.ChatFilter:NormalizeChannelKey(channel)
    end

    if self.ChatFilter then
        self.ChatFilter:RemoveWord(word, channel)
    end

    self:UpdateWordsList(_G.CrossIgnoreUI and _G.CrossIgnoreUI.searchBox:GetText() or "")
    if refreshLeftPanel then refreshLeftPanel() end
end
