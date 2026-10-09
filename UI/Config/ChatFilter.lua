local _, ns = ...
local CrossIgnore = ns.Addon
local L = ns.L

function CrossIgnore:CreateChatFilterDebugMenu(parent)
    local ChatFilter = CrossIgnore.ChatFilter
    ChatFilter.IsFilteredMessage = ChatFilter.IsFilteredMessage or IsFilteredMessage

    local panelWidth, panelHeight = 140, 220
    local leftPanelWidth = panelWidth
    local rightPanelWidth = 280
    local selectedWord, selectedWordChannel = nil, nil
    local leftSearchText = ""
    local filterChannel = CrossIgnoreDB.selectedChannel or L["CHANNEL_ALL"]

    local blockedMessages = {}

    local leftPanel = CreateFrame("Frame", nil, parent)
    leftPanel:SetSize(leftPanelWidth, panelHeight)
    leftPanel:SetPoint("TOPLEFT", 10, -40)

    local leftBG = leftPanel:CreateTexture(nil, "BACKGROUND")
    leftBG:SetAllPoints()
    leftBG:SetColorTexture(0,0,0,0.5)

    local function UpdateChannelDropdown()
        local channelList = {L["CHANNEL_ALL"], L["CHANNEL_SAY"], L["CHANNEL_YELL"], L["CHANNEL_WHISPER"],
            L["CHANNEL_GUILD"], L["CHANNEL_OFFICER"], L["CHANNEL_PARTY"], L["CHANNEL_RAID"], L["CHANNEL_INSTANCE"]}

        local channels = { GetChannelList() }
        local seen = {}
        for i=1,#channels,3 do
            local chNum = channels[i]
            if chNum then
                local name, displayName = GetChannelName(chNum)
                local finalName = (type(name) == "string" and name) or displayName
                if finalName then
                    local clean = finalName:gsub("^%d+%.%s*", "")
                    if not seen[clean:lower()] then
                        table.insert(channelList, clean)
                        seen[clean:lower()] = true
                    end
                end
            end
        end
        return channelList
    end

    local function CreateChannelDropdown(parent)
        if Menu and MenuUtil then
            local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
            dropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -5)
            dropdown:SetSize(leftPanelWidth - 10, 25)
            dropdown:SetDefaultText(L["CHANNEL_ALL"])
            dropdown:SetupMenu(function(_, rootDescription)
                for _, channel in ipairs(UpdateChannelDropdown()) do
                    rootDescription:CreateRadio(channel, function(value)
                        return filterChannel == value
                    end, function(value)
                        filterChannel = value
                        CrossIgnoreDB.selectedChannel = value
                        refreshLeftPanel()
                    end, channel)
                end
            end)
            return dropdown
        end

        local dropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
        dropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", -20, -5)
        UIDropDownMenu_SetWidth(dropdown, leftPanelWidth - 10)

        local function OnClick(self)
            filterChannel = self.value
            CrossIgnoreDB.selectedChannel = self.value
            UIDropDownMenu_SetSelectedValue(dropdown, self.value)
            UIDropDownMenu_SetText(dropdown, self.value)
            refreshLeftPanel()
        end

        UIDropDownMenu_Initialize(dropdown, function(self)
            local selected = filterChannel
            for _, ch in ipairs(UpdateChannelDropdown()) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = ch
                info.value = ch
                info.func = OnClick
                info.checked = (ch == selected)
                UIDropDownMenu_AddButton(info)
            end
        end)

        UIDropDownMenu_SetSelectedValue(dropdown, filterChannel)
        UIDropDownMenu_SetText(dropdown, filterChannel)
        return dropdown
    end
    local channelDrop = CreateChannelDropdown(leftPanel)

    local leftSearchBox = CreateFrame("EditBox", nil, leftPanel, "InputBoxTemplate")
    leftSearchBox:SetSize(leftPanelWidth - 10, 20)
    leftSearchBox:SetPoint("TOPLEFT", channelDrop, "BOTTOMLEFT", 25, -5)
    leftSearchBox:SetAutoFocus(false)
    leftSearchBox:SetScript("OnTextChanged", function(self)
        leftSearchText = self:GetText():lower()
        refreshLeftPanel()
    end)

    local leftScroll = CreateFrame("ScrollFrame", nil, leftPanel, "UIPanelScrollFrameTemplate")
    leftScroll:SetPoint("TOPLEFT", leftSearchBox, "BOTTOMLEFT", 0, -5)
    leftScroll:SetPoint("BOTTOMRIGHT", leftPanel, "BOTTOMRIGHT", -20, 0)

    local leftContent = CreateFrame("Frame", nil, leftScroll)
    leftContent:SetSize(leftPanelWidth - 20, panelHeight)
    leftScroll:SetScrollChild(leftContent)
    leftContent.children = {}

    local rightPanel = CreateFrame("Frame", nil, parent)
    rightPanel:SetSize(rightPanelWidth, panelHeight)
    rightPanel:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 10, 0)

    local infoLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoLabel:SetPoint("BOTTOMLEFT", rightPanel, "TOPLEFT", 0, 5)
    infoLabel:SetPoint("BOTTOMRIGHT", rightPanel, "TOPRIGHT", 0, 5)
    infoLabel:SetJustifyH("LEFT")
    infoLabel:SetText(L["DEBUG_DUPLICATE_LOG"])

    local rightBG = rightPanel:CreateTexture(nil, "BACKGROUND")
    rightBG:SetAllPoints()
    rightBG:SetColorTexture(0,0,0,0.5)

    local rightScroll = CreateFrame("ScrollFrame", nil, rightPanel, "UIPanelScrollFrameTemplate")
    rightScroll:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 0, -5)
    rightScroll:SetPoint("BOTTOMRIGHT", rightPanel, "BOTTOMRIGHT", -20, 5)

    local rightContent = CreateFrame("Frame", nil, rightScroll)
    rightContent:SetSize(rightPanelWidth, panelHeight)
    rightScroll:SetScrollChild(rightContent)
    rightContent.children = {}

    local function cleanOldMessages()
        local now = time()
        for i = #blockedMessages, 1, -1 do
            if now - blockedMessages[i].timestamp > 300 then
                table.remove(blockedMessages, i)
            end
        end
    end

    ChatFilter.OnBlockedMessageAdded = ChatFilter.OnBlockedMessageAdded or {}
    table.insert(ChatFilter.OnBlockedMessageAdded, function(entry)
        table.insert(blockedMessages, entry)
        cleanOldMessages()
        refreshRightPanel()
    end)

    function refreshLeftPanel()
        for _, child in ipairs(leftContent.children) do
            child:Hide()
            child:SetParent(nil)
        end
        leftContent.children = {}

        local y = -5
        local wordsDB = ChatFilter:GetFilters() or {}

        local dbKey = filterChannel
        if filterChannel ~= L["CHANNEL_ALL"] then
            for k,_ in pairs(wordsDB) do
                if k:lower() == filterChannel:lower() then
                    dbKey = k
                    break
                end
            end
        end

        for channelName, wordList in pairs(wordsDB) do
            if type(wordList) == "table" and (filterChannel == L["CHANNEL_ALL"] or channelName == dbKey) then
                for wordIndex, wordEntry in ipairs(wordList) do
                    local word = type(wordEntry) == "table" and wordEntry.word or tostring(wordEntry)
                    local isStrict = type(wordEntry) == "table" and wordEntry.strict or false
                    if leftSearchText == "" or word:lower():find(leftSearchText) then
                        local row = CreateFrame("Button", nil, leftContent, "BackdropTemplate")
                        row:SetSize(leftPanelWidth - 20, 20)
                        row:SetPoint("TOPLEFT", 5, y)
                        row:EnableMouse(true)

                        local bg = row:CreateTexture(nil, "BACKGROUND")
                        bg:SetAllPoints()
                        if word:lower() == (selectedWord or "") and channelName == (selectedWordChannel or "") then
                            bg:SetColorTexture(0.2,0.6,1,0.3)
                        else
                            bg:SetColorTexture(0.1,0.1,0.1,0.8)
                        end

                        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                        row.text:SetPoint("LEFT", row, "LEFT", 5, 0)
                        row.text:SetText(word .. (isStrict and L["DEBUG_STRICT"] or ""))

                        local strictCheck = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
                        strictCheck:SetPoint("RIGHT", row, "RIGHT", -5, 0)
                        strictCheck:SetSize(20, 20)
                        strictCheck:SetChecked(isStrict)
                        strictCheck:SetScript("OnClick", function(self)
                            local checked = self:GetChecked()
                            local dbChannel = wordsDB[channelName]
                            if dbChannel then
                                dbChannel[wordIndex] = dbChannel[wordIndex] or { word = word }
                                dbChannel[wordIndex].strict = checked
                            end
                            refreshLeftPanel()
                        end)

                        row.entry = { word = word, strict = isStrict, channelName = channelName, wordIndex = wordIndex }

                        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                        row:SetScript("OnClick", function(_, button)
                            if button == "RightButton" then
                                CrossIgnore:ShowWordContextMenu(row, row.entry)
                            else
                                selectedWord = word:lower()
                                selectedWordChannel = channelName
                                refreshLeftPanel()
                                refreshRightPanel()
                            end
                        end)

                        leftContent.children[#leftContent.children + 1] = row
                        y = y - 22
                    end
                end
            end
        end
        leftContent:SetHeight(math.max(panelHeight, -y))
    end

    function refreshRightPanel()
    for _, child in ipairs(rightContent.children) do
        child:Hide()
        child:SetParent(nil)
    end
    rightContent.children = {}

    local logs = blockedMessages
    local y = -5
    local selWordLower = (selectedWord or ""):lower()
    local selChannel = selectedWordChannel

    for i = #logs, 1, -1 do
        local entry = logs[i]
        local msgLower = (entry.message or ""):lower()

        local show = false

        if selChannel == L["CHANNEL_ALL"] then
            if selWordLower == "" then
                show = true
            else
                if entry.strict then
                    local strippedMsg = msgLower:gsub("[%s%p]", "")
                    local strippedWord = selWordLower:gsub("[%s%p]", "")
                    show = strippedMsg:find(strippedWord, 1, true) ~= nil
                else
                    show = msgLower:find(selWordLower, 1, true) ~= nil
                end
            end
        else
            if entry.channel == selChannel then
                if selWordLower == "" then
                    show = true
                else
                    if entry.strict then
                        local strippedMsg = msgLower:gsub("[%s%p]", "")
                        local strippedWord = selWordLower:gsub("[%s%p]", "")
                        show = strippedMsg:find(strippedWord, 1, true) ~= nil
                    else
                        show = msgLower:find(selWordLower, 1, true) ~= nil
                    end
                end
            end
        end

        if show then
            local row = CreateFrame("Frame", nil, rightContent, "BackdropTemplate")
            row:SetPoint("TOPLEFT", 5, y)
            row:SetWidth(rightPanelWidth - 20)

            local bgColor = (#rightContent.children % 2 == 0) and {0,0,0,0.8} or {0.1,0.1,0.1,0.8}
            row:SetBackdrop({bgFile="Interface/Tooltips/UI-Tooltip-Background"})
            row:SetBackdropColor(unpack(bgColor))

            local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            text:SetPoint("TOPLEFT", row, "TOPLEFT", 5, -2)
            text:SetWidth(rightPanelWidth - 30)
            text:SetJustifyH("LEFT")
            text:SetText(string.format("[%s] |cff999999%s|r: %s%s",
                entry.time or "??",
                entry.sender or "?",
                entry.message or "",
                entry.strict and L["DEBUG_STRICT"] or ""
            ))

            row:SetHeight(text:GetStringHeight() + 8)
            rightContent.children[#rightContent.children + 1] = row
            y = y - row:GetHeight()
        end
    end

    rightContent:SetHeight(math.max(panelHeight, -y))
end

    local testFrame = CreateFrame("Frame", nil, parent)
    testFrame:SetPoint("TOPLEFT", leftPanel, "BOTTOMLEFT", 0, -10)
    testFrame:SetPoint("TOPRIGHT", rightPanel, "BOTTOMRIGHT", 0, -10)
    testFrame:SetHeight(60)

    local line = testFrame:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1,1,1,0.2)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", testFrame, "TOPLEFT", 0, -2)
    line:SetPoint("TOPRIGHT", testFrame, "TOPRIGHT", 0, -2)

    local testLabel = testFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    testLabel:SetPoint("TOPLEFT", testFrame, "TOPLEFT", 5, -5)
    testLabel:SetText(L["DEBUG_FILTER_TEST"])

    local testBox = CreateFrame("EditBox", nil, testFrame, "InputBoxTemplate")
    testBox:SetSize(300, 20)
    testBox:SetPoint("TOPLEFT", testLabel, "BOTTOMLEFT", 0, -2)
    testBox:SetAutoFocus(false)

    local testButton = CreateFrame("Button", nil, testFrame, "UIPanelButtonTemplate")
    testButton:SetSize(80, 20)
    testButton:SetPoint("LEFT", testBox, "RIGHT", 5, 0)
    testButton:SetText(L["DEBUG_TEST_LIVE"])

    local testResultText = testFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    testResultText:SetPoint("TOPLEFT", testBox, "BOTTOMLEFT", 0, -5)
    testResultText:SetJustifyH("LEFT")

    local function RunLiveTest()
        local message = testBox:GetText() or ""
        if message == "" then
            testResultText:SetText(L["DEBUG_ENTER_TEST"])
            return
        end

        local matches = {}
        local filters = ChatFilter:GetFilters() or {}
        local msgLower = message:lower()

        local preset = ChatFilter:MatchPreset(message)
        if preset then matches[#matches+1] = { channel = L["CHANNEL_ALL"], word = preset, strict = false } end

        for channelName, wordList in pairs(filters) do
            if type(wordList) == "table" and #wordList > 0 then
                for _, wordEntry in ipairs(wordList) do
                    local word = type(wordEntry) == "table" and wordEntry.normalized or wordEntry:lower()
                    local isStrict = type(wordEntry) == "table" and wordEntry.strict or false
                    if word then
                        local blocked = false
                        if isStrict then
                            local strippedMsg = msgLower:gsub("[%s%p]", "")
                            local strippedWord = word:gsub("[%s%p]", "")
                            blocked = strippedMsg:find(strippedWord, 1, true) ~= nil
                        else
                            blocked = msgLower:find(word, 1, true) ~= nil
                        end
                        if blocked then
                            matches[#matches+1] = { channel = channelName, word = wordEntry.word or word, strict = isStrict }
                            break
                        end
                    end
                end
            end
        end

        if #matches == 0 then
            testResultText:SetText(L["DEBUG_ALLOWED"])
        else
            local lines = {}
            for _, m in ipairs(matches) do
                lines[#lines+1] = string.format(L["DEBUG_BLOCKED"],
                    m.word or "?",
                    m.channel or "?",
                    m.strict and L["DEBUG_STRICT"] or ""
                )
            end
            testResultText:SetText(table.concat(lines, "\n"))
        end

        refreshRightPanel()
    end

    testButton:SetScript("OnClick", RunLiveTest)
    testBox:SetScript("OnEnterPressed", function()
        RunLiveTest()
        testBox:ClearFocus()
    end)

    refreshLeftPanel()
    refreshRightPanel()
end
