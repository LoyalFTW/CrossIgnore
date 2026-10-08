local _, ns = ...
local CrossIgnore = ns.Addon
local L = ns.L

local UI = ns.UI
local W = UI.Widgets

local FALLBACK_REALM_NAMES = ns.RealmNames or {}

local function NormalizeRealmToken(value)
    if value == nil then
        return nil
    end

    local realm = strtrim(tostring(value or ""))
    if realm == "" then
        return nil
    end

    return realm:gsub("%s+", "")
end

local function NormalizeRealmSearchKey(value)
    local realm = NormalizeRealmToken(value)
    if not realm then
        return nil
    end

    realm = realm:lower()
    realm = realm:gsub("[%s%-%']", "")
    return realm
end

local function FormatRealmDisplayName(value)
    local realm = NormalizeRealmToken(value)
    if not realm then
        return ""
    end

    realm = realm:gsub("(%a)(%d)", "%1 %2")
    realm = realm:gsub("(%d)(%a)", "%1 %2")
    realm = realm:gsub("(%l)(%u)", "%1 %2")
    return realm
end

local function CollectRealmNames(activeAddon)
    if activeAddon and activeAddon.isForever then return {} end
    local realms, seen = {}, {}

    local function addRealm(value)
        local realm = NormalizeRealmToken(value)
        if not realm or seen[realm] then
            return
        end

        seen[realm] = true
        realms[#realms + 1] = realm
    end

    addRealm(GetNormalizedRealmName and GetNormalizedRealmName() or nil)
    addRealm(GetRealmName and GetRealmName() or nil)

    if activeAddon and activeAddon.RefreshKnownRealms then
        activeAddon:RefreshKnownRealms()
    end

    if activeAddon and activeAddon.GetKnownRealms then
        for _, realm in ipairs(activeAddon:GetKnownRealms() or {}) do
            addRealm(realm)
        end
    end

    if type(GetAutoCompleteRealms) == "function" then
        local ok, result1, result2, result3, result4, result5, result6, result7, result8 = pcall(GetAutoCompleteRealms)
        if ok then
            if type(result1) == "table" then
                for _, realm in ipairs(result1) do
                    addRealm(realm)
                end
            else
                addRealm(result1)
                addRealm(result2)
                addRealm(result3)
                addRealm(result4)
                addRealm(result5)
                addRealm(result6)
                addRealm(result7)
                addRealm(result8)
            end
        end
    end

    local function addFromList(list)
        for _, entry in ipairs(list or {}) do
            addRealm(entry and (entry.server or entry.realm))
        end
    end

    if activeAddon and activeAddon.charDB and activeAddon.charDB.profile then
        addFromList(activeAddon.charDB.profile.players)
        addFromList(activeAddon.charDB.profile.overLimitPlayers)
    end

    if activeAddon and activeAddon.globalDB and activeAddon.globalDB.global then
        addFromList(activeAddon.globalDB.global.players)
        addFromList(activeAddon.globalDB.global.overLimitPlayers)
    end

    if #realms <= 5 then
        for _, realm in ipairs(FALLBACK_REALM_NAMES) do
            addRealm(realm)
        end
    end

    local defaultRealm = NormalizeRealmToken(GetNormalizedRealmName and GetNormalizedRealmName() or nil)
    table.sort(realms, function(a, b)
        if defaultRealm then
            if a == defaultRealm and b ~= defaultRealm then
                return true
            end
            if b == defaultRealm and a ~= defaultRealm then
                return false
            end
        end
        return a:lower() < b:lower()
    end)

    return realms
end

function UI:HideAddPlayerPopup()
    local popup = UI.Frames and UI.Frames.addPlayerPopup
    if not popup then return end

    popup.nameBox:SetText("")
    popup.surnameBox:SetText("")
    if popup.SetSelectedRealm then
        popup:SetSelectedRealm(popup.defaultRealm)
    end
    if popup.realmDropdown then
        popup.realmDropdown:Hide()
    end
    popup:Hide()
end

function UI:ShowAddPlayerPopup(CrossIgnore)
    local popup = UI.Frames and UI.Frames.addPlayerPopup
    if not popup then return end

    popup.CrossIgnore = CrossIgnore
    popup.nameBox:SetText("")
    popup.surnameBox:SetText("")
    popup.surnameLabel:SetShown(CrossIgnore.isForever)
    popup.surnameBox:SetShown(CrossIgnore.isForever)
    popup.serverLabel:SetShown(not CrossIgnore.isForever)
    popup.realmButton:SetShown(not CrossIgnore.isForever)
    if not CrossIgnore.isForever and popup.RefreshRealmOptions then
        popup:RefreshRealmOptions()
    end
    if popup.SetSelectedRealm then
        popup:SetSelectedRealm(popup.defaultRealm)
    end
    popup:Show()
    popup.nameBox:SetFocus()
    popup.nameBox:HighlightText()
end

function UI:BuildPopups(CrossIgnore, CrossIgnoreDB)
    StaticPopupDialogs["CROSSIGNORE_CONFIRM_REMOVE_ALL_WORDS"] = {
        text = L["REMOVE_ALL_CONFIRM"],
        button1 = L["YES_BUTTON"],
        button2 = L["NO_BUTTON"],
        OnAccept = function()
            if CrossIgnoreDB and CrossIgnoreDB.global and CrossIgnoreDB.global.filters then
                CrossIgnoreDB.global.filters.words = {}
                CrossIgnoreDB.global.filters.removedDefaults = true
            end
            print(L["REMOVE_ALL_DONE"])
            CrossIgnore:UpdateWordsList(UI.State.wordFilterText or "")
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    StaticPopupDialogs["CROSSIGNORE_CONFIRM_REMOVE_ALL_PLAYERS"] = {
        text = L["REMOVE_ALL_PLAYERS_CONFIRM"] or "Are you sure you want to remove ALL ignored players?\n\nThis cannot be undone.",
        button1 = L["YES_BUTTON"] or "Yes",
        button2 = L["NO_BUTTON"] or "No",
        OnAccept = function()
            if CrossIgnore and CrossIgnore.ClearAllIgnoredPlayers then
                CrossIgnore:ClearAllIgnoredPlayers()
                UI.State.selectedPlayer = nil
                CrossIgnore.selectedPlayer = nil
                CrossIgnore.selectedRow = nil
                CrossIgnore:RefreshBlockedList(UI.State.ignoreFilterText or "")
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    local popup = CreateFrame("Frame", "CrossIgnoreAddPlayerPopup", UIParent, "BackdropTemplate")
    popup:SetSize(340, 210)
    popup:SetPoint("CENTER")
    popup:SetFrameStrata("DIALOG")
    popup:SetFrameLevel(10)
    popup:SetToplevel(true)
    popup:EnableMouse(true)
    popup:SetMovable(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
    popup:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    popup:Hide()

    W:CreateLabel(popup, L["ADD_PLAYER_POPUP_TITLE"] or "Add Ignored Player", "TOP", 0, -20, "GameFontHighlight")

    local nameLabel = W:CreateLabel(popup, CrossIgnore.isForever and (L["FOREVER_FIRST_NAME"] or "First Name") or L["PLAYER_NAME_HEADER"], "TOPLEFT", 24, -58, "GameFontNormal")
    local nameBox = W:CreateEditBox(popup, 292, 24, "TOPLEFT", 24, -80)
    W:AttachPlaceholder(nameBox, CrossIgnore.isForever and (L["FOREVER_FIRST_NAME"] or "First Name") or (L["ADD_PLAYER_NAME_PLACEHOLDER"] or "Player name"))

    local serverLabel = W:CreateLabel(popup, L["SERVER_HEADER"], "TOPLEFT", 24, -114, "GameFontNormal")
    local surnameLabel = W:CreateLabel(popup, L["FOREVER_LAST_NAME"] or "Last Name", "TOPLEFT", 24, -114, "GameFontNormal")
    local surnameBox = W:CreateEditBox(popup, 292, 24, "TOPLEFT", 24, -136)
    W:AttachPlaceholder(surnameBox, L["FOREVER_LAST_NAME"] or "Last Name")
    surnameLabel:Hide()
    surnameBox:Hide()
    local defaultRealm = not CrossIgnore.isForever and NormalizeRealmToken(GetNormalizedRealmName and GetNormalizedRealmName() or nil) or "Unknown"
    local realmButton = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    realmButton:SetSize(292, 24)
    realmButton:SetPoint("TOPLEFT", 24, -136)
    realmButton:SetText(FormatRealmDisplayName(defaultRealm))
    realmButton:SetNormalFontObject("GameFontHighlightSmall")
    realmButton:GetFontString():SetJustifyH("LEFT")
    realmButton:GetFontString():SetPoint("LEFT", realmButton, "LEFT", 10, 0)
    realmButton:GetFontString():SetPoint("RIGHT", realmButton, "RIGHT", -24, 0)

    local arrowText = realmButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    arrowText:SetPoint("RIGHT", realmButton, "RIGHT", -10, 0)
    arrowText:SetText("v")

    local realmDropdown = CreateFrame("Frame", nil, popup, "BackdropTemplate")
    realmDropdown:SetSize(292, 220)
    realmDropdown:SetPoint("TOPLEFT", realmButton, "BOTTOMLEFT", 0, -4)
    realmDropdown:SetFrameStrata("DIALOG")
    realmDropdown:SetFrameLevel(popup:GetFrameLevel() + 5)
    realmDropdown:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    realmDropdown:EnableMouse(true)
    realmDropdown:Hide()

    local realmSearchBox = W:CreateEditBox(realmDropdown, 248, 24, "TOPLEFT", 16, -18)
    W:AttachPlaceholder(realmSearchBox, L["SEARCH_PLACEHOLDER"] or "Search...")

    local realmListFrame = CreateFrame("Frame", nil, realmDropdown)
    realmListFrame:SetPoint("TOPLEFT", realmSearchBox, "BOTTOMLEFT", 0, -10)
    realmListFrame:SetSize(260, 150)
    realmListFrame:EnableMouseWheel(true)

    local noResultsLabel = realmDropdown:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    noResultsLabel:SetPoint("TOPLEFT", realmListFrame, "TOPLEFT", 6, -8)
    noResultsLabel:SetText(L["NO_RESULTS"] or "No matches found.")
    noResultsLabel:Hide()

    local realmButtons = {}
    for i = 1, 8 do
        local row = CreateFrame("Button", nil, realmListFrame, "UIPanelButtonTemplate")
        row:SetSize(248, 18)
        row:SetPoint("TOPLEFT", 6, -((i - 1) * 18))
        row:GetFontString():SetJustifyH("LEFT")
        row:GetFontString():SetPoint("LEFT", row, "LEFT", 8, 0)
        row:GetFontString():SetPoint("RIGHT", row, "RIGHT", -8, 0)
        realmButtons[i] = row
    end

    popup.defaultRealm = defaultRealm
    popup.selectedRealm = defaultRealm
    popup.realmOptions = {}
    popup.filteredRealmOptions = {}
    popup.realmScrollOffset = 0

    function popup:SetSelectedRealm(realm)
        local selected = NormalizeRealmToken(realm) or self.defaultRealm
        self.selectedRealm = selected
        realmButton:SetText(FormatRealmDisplayName(selected))
        if realmDropdown:IsShown() then
            realmDropdown:Hide()
        end
    end

    function popup:GetSelectedRealm()
        return NormalizeRealmToken(self.selectedRealm) or self.defaultRealm
    end

    function popup:RefreshRealmOptions()
        if CrossIgnore.isForever then return end
        self.defaultRealm = NormalizeRealmToken(GetNormalizedRealmName and GetNormalizedRealmName() or nil) or self.defaultRealm or "Unknown"
        self.realmOptions = CollectRealmNames(self.CrossIgnore or CrossIgnore)
        if #self.realmOptions == 0 then
            self.realmOptions = { self.defaultRealm }
        end
        self:FilterRealmOptions(realmSearchBox:GetText())
    end

    function popup:FilterRealmOptions(searchText)
        local filter = NormalizeRealmSearchKey(searchText) or ""
        local typedRealm = NormalizeRealmToken(searchText)
        wipe(self.filteredRealmOptions)

        for _, realm in ipairs(self.realmOptions or {}) do
            local realmKey = NormalizeRealmSearchKey(realm) or ""
            if filter == "" or strfind(realmKey, filter, 1, true) then
                self.filteredRealmOptions[#self.filteredRealmOptions + 1] = realm
            end
        end

        if typedRealm and filter ~= "" then
            local typedRealmKey = NormalizeRealmSearchKey(typedRealm)
            local hasExactTypedRealm = false
            for _, realm in ipairs(self.filteredRealmOptions) do
                if NormalizeRealmSearchKey(realm) == typedRealmKey then
                    hasExactTypedRealm = true
                    break
                end
            end

            if not hasExactTypedRealm then
                table.insert(self.filteredRealmOptions, 1, typedRealm)
            end
        end

        self.realmScrollOffset = 0
        self:UpdateRealmDropdownButtons()
    end

    function popup:UpdateRealmDropdownButtons()
        local visibleCount = 0

        for index, button in ipairs(realmButtons) do
            local realm = self.filteredRealmOptions[index + self.realmScrollOffset]
            if realm then
                visibleCount = visibleCount + 1
                button:SetText(FormatRealmDisplayName(realm))
                button:SetScript("OnClick", function()
                    popup:SetSelectedRealm(realm)
                end)
                button:Show()
            else
                button:Hide()
            end
        end

        noResultsLabel:SetShown(visibleCount == 0)
    end

    realmListFrame:SetScript("OnMouseWheel", function(_, delta)
        local maxOffset = max(0, #popup.filteredRealmOptions - #realmButtons)
        if maxOffset <= 0 then
            return
        end

        popup.realmScrollOffset = min(maxOffset, max(0, popup.realmScrollOffset - delta))
        popup:UpdateRealmDropdownButtons()
    end)

    realmSearchBox:SetScript("OnTextChanged", function(self)
        popup:FilterRealmOptions(self:GetText())
    end)
    realmSearchBox:SetScript("OnEscapePressed", function()
        realmDropdown:Hide()
    end)
    realmSearchBox:SetScript("OnEnterPressed", function(self)
        local realm = popup.filteredRealmOptions[1] or NormalizeRealmToken(self:GetText()) or popup.defaultRealm
        popup:SetSelectedRealm(realm)
        nameBox:SetFocus()
        nameBox:HighlightText()
    end)

    realmButton:SetScript("OnClick", function()
        if realmDropdown:IsShown() then
            realmDropdown:Hide()
            return
        end

        popup:RefreshRealmOptions()
        realmSearchBox:SetText("")
        realmDropdown:Show()
        realmSearchBox:SetFocus()
        realmSearchBox:HighlightText()
    end)

    local function SubmitAddPlayer()
        local activeAddon = popup.CrossIgnore or CrossIgnore
        if not activeAddon then return end

        local rawName = strtrim(nameBox:GetText() or "")
        local playerName
        if activeAddon.isForever then
            playerName = rawName .. " " .. strtrim(surnameBox:GetText() or "")
        else
            local realm = popup:GetSelectedRealm()
            playerName = rawName:find("-", 1, true) and rawName or rawName .. "-" .. realm
        end
        local fullName, base, normalizedRealm = activeAddon:NormalizePlayerName(playerName)
        if not fullName or not base or normalizedRealm == nil then
            print(activeAddon.isForever and (L["FOREVER_ADD_PLAYER_INVALID"] or "Enter both first and last names.") or (L["ADD_PLAYER_INVALID"] or "Enter a player and server name."))
            return
        end

        if activeAddon.IsPlayerInAnyList and activeAddon:IsPlayerInAnyList(base, normalizedRealm) then
            print(L["ADD_PLAYER_EXISTS"] or "That player is already blocked.")
            return
        end

        activeAddon:AddIgnore(fullName)
        activeAddon:RefreshBlockedList(UI.State.ignoreFilterText or "")
        UI:HideAddPlayerPopup()
    end

    nameBox:SetScript("OnEnterPressed", function()
        if (popup.CrossIgnore or CrossIgnore).isForever then
            surnameBox:SetFocus()
        else
            realmButton:Click()
        end
    end)
    surnameBox:SetScript("OnEnterPressed", SubmitAddPlayer)

    local addButton = W:CreateButton(popup, L["ADD_PLAYER_BTN"] or "Add Player", "BOTTOMLEFT", 24, 22, 128, 24, SubmitAddPlayer)
    local cancelButton = W:CreateButton(popup, L["CANCEL"] or "Cancel", "BOTTOMRIGHT", -24, 22, 128, 24, function()
        UI:HideAddPlayerPopup()
    end)

    popup.nameLabel = nameLabel
    popup.serverLabel = serverLabel
    popup.nameBox = nameBox
    popup.surnameLabel = surnameLabel
    popup.surnameBox = surnameBox
    popup.serverBox = realmButton
    popup.realmButton = realmButton
    popup.realmDropdown = realmDropdown
    popup.realmSearchBox = realmSearchBox
    popup.addButton = addButton
    popup.cancelButton = cancelButton
    UI.Frames.addPlayerPopup = popup

    tinsert(UISpecialFrames, "CrossIgnoreAddPlayerPopup")
end
