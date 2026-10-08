local _, ns = ...
local CrossIgnore = ns.Addon

local ToSafeString = ns.CoreInternals.ToSafeString

function CrossIgnore:CreateBlockUnblockButton(root, fullName)
    if not fullName then return end
    root:CreateDivider()
    root:CreateTitle("|cFFffd100CrossIgnore|r")
    local isBlocked = self:IsPlayerBlocked(fullName)
    local label = isBlocked and "Unblock Player" or "Block Player"
    if self.isForever then label = label .. ": " .. fullName end
    root:CreateButton(label, function()
        self:AddOrDelIgnore(fullName)
    end)
end

function CrossIgnore:CrossIgnore_LFG_ApplicantMenu(owner, root)
    if not owner or not owner.resultID then return end
    local info = C_LFGList.GetSearchResultInfo(owner.resultID)
    if not info or not info.leaderName then return end
    local fullName = self:NormalizePlayerName(info.leaderName)
    self:CreateBlockUnblockButton(root, fullName)
end

function CrossIgnore:CrossIgnore_UnitMenu(owner, root, contextData)
    if not contextData or not contextData.unit then return end
    local name, realm = self:GetUnitPlayerName(contextData.unit)
    if not name then return end
    local fullName = self:NormalizePlayerName(name .. (not self.isForever and realm and "-" .. realm or ""))
    self:CreateBlockUnblockButton(root, fullName)
end

function CrossIgnore:CrossIgnore_PlayerNameMenu(owner, root, contextData)
    if not contextData then return end
    if canaccessvalue and not canaccessvalue(contextData.name) then return end
    if not contextData.name then return end
    local fullName = self:NormalizePlayerName(contextData.name .. (not self.isForever and contextData.server and contextData.server ~= "" and "-" .. contextData.server or ""))
    self:CreateBlockUnblockButton(root, fullName)
end

function CrossIgnore:ShowUnitMenuButton(tag, contextData)
    local unitMenus = { MENU_UNIT_ENEMY_PLAYER = true, MENU_UNIT_PLAYER = true, MENU_UNIT_PARTY = true, MENU_UNIT_RAID_PLAYER = true }
    local nameMenus = { MENU_UNIT_FRIEND = true, MENU_UNIT_FRIEND_OFFLINE = true, MENU_UNIT_CHAT_ROSTER = true }
    local frame = self.unitMenuButtonFrame
    if frame then frame:Hide() end
    if not contextData or not (nameMenus[tag] or (unitMenus[tag] and self.db.profile.settings.UnitBlock)) then return end

    local name
    local unit = ToSafeString(contextData.unit)
    if unit then
        local realm
        name, realm = self:GetUnitPlayerName(unit)
        if name and not self.isForever and realm and realm ~= "" then
            name = name .. "-" .. realm
        end
    else
        name = ToSafeString(contextData.name)
        local server = ToSafeString(contextData.server)
        if name and not self.isForever and server and server ~= "" then
            name = name .. "-" .. server
        end
    end
    local fullName = name and self:NormalizePlayerName(name)
    if not fullName then return end
    local manager = Menu.GetManager()
    local menu = manager and manager:GetOpenMenu()
    if not menu or not menu:IsShown() then return end

    if not frame then
        frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        frame:SetSize(180, 48)
        frame:SetClampedToScreen(true)
        frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
        frame:SetBackdropColor(0, 0, 0, 0.95)
        frame:SetBackdropBorderColor(0.65, 0.55, 0.3, 1)
        local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        title:SetPoint("TOPLEFT", 8, -7)
        title:SetText("CrossIgnore")
        frame.title = title
        frame.button = CreateFrame("Button", nil, frame)
        frame.button:SetPoint("TOPLEFT", 4, -24)
        frame.button:SetPoint("BOTTOMRIGHT", -4, 4)
        frame.button:SetNormalFontObject("GameFontHighlight")
        local label = frame.button:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("LEFT", 4, 0)
        label:SetPoint("RIGHT", -4, 0)
        label:SetJustifyH("LEFT")
        frame.button:SetFontString(label)
        frame.label = label
        local highlight = frame.button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(1, 0.82, 0, 0.2)
        frame.button:SetHighlightTexture(highlight)
        frame.button.HandlesGlobalMouseEvent = function(_, buttonName, event)
            return buttonName == "LeftButton" and event == "GLOBAL_MOUSE_DOWN"
        end
        frame.button:SetScript("OnClick", function()
            local selectedName = frame.fullName
            frame:Hide()
            Menu.GetManager():CloseMenus()
            if selectedName then self:AddOrDelIgnore(selectedName) end
        end)
        frame:SetScript("OnUpdate", function()
            if not frame.menu or not frame.menu:IsShown() or Menu.GetManager():GetOpenMenu() ~= frame.menu then frame:Hide() end
        end)
        self.unitMenuButtonFrame = frame
    end

    frame.menu = menu
    frame.fullName = fullName
    local function FindMenuFont(region)
        for _, childRegion in ipairs({ region:GetRegions() }) do
            if childRegion:IsObjectType("FontString") and ToSafeString(childRegion:GetText()) then
                local font, size, flags = childRegion:GetFont()
                if font and size then return font, size, flags end
            end
        end
        for _, child in ipairs({ region:GetChildren() }) do
            local font, size, flags = FindMenuFont(child)
            if font then return font, size, flags end
        end
    end
    local font, size, flags = FindMenuFont(menu)
    if font then
        frame.title:SetFont(font, size, flags)
        frame.label:SetFont(font, size, flags)
    end
    frame.button:SetText(self:IsPlayerBlocked(fullName) and "UnblockPlayer" or "BlockPlayer")
    frame:SetScale(menu:GetEffectiveScale() / UIParent:GetEffectiveScale())
    frame:SetWidth(menu:GetWidth())
    frame:SetFrameStrata(menu:GetFrameStrata())
    frame:SetFrameLevel(menu:GetFrameLevel() + 1)
    frame:ClearAllPoints()
    local bottom = menu:GetBottom()
    if bottom and bottom < frame:GetHeight() + 2 then
        local point, relativeTo, relativePoint, x, y = menu:GetPoint(1)
        if point then
            menu:SetPoint(point, relativeTo, relativePoint, x, y + frame:GetHeight() + 2 - bottom)
        end
    end
    frame:SetPoint("TOPLEFT", menu, "BOTTOMLEFT", 0, 0)
    frame:Show()
end
