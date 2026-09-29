local _, ns = ...
local CrossIgnore = ns.Addon
local L = ns.L

local UI = ns.UI
local W = UI.Widgets

local Theme = UI.Theme

function UI:BuildMainFrame(CrossIgnore, CrossIgnoreDB)
    if UI.Frames.main then return UI.Frames.main end

    self:BuildPopups(CrossIgnore, CrossIgnoreDB)

    local f = CreateFrame("Frame", "CrossIgnoreUI", UIParent, "BackdropTemplate")
    f:SetSize(Theme.frame.width, Theme.frame.height)
    f:SetPoint("CENTER")
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:HookScript("OnHide", function()
        UI:HideAddPlayerPopup()
    end)

    W:CreateLabel(f, L["TITLE_HEADER"], "TOP", 0, -12, "GameFontHighlightLarge")
    W:CreateButton(f, L["CLOSE_BUTTON"], "TOPRIGHT", -10, -10, 70, 25, function() f:Hide() end)

    tinsert(UISpecialFrames, "CrossIgnoreUI")

    local leftPanel = CreateFrame("Frame", nil, f, "BackdropTemplate")
    leftPanel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    leftPanel:SetPoint("TOPLEFT", 10, -40)
    leftPanel:SetSize(140, 460)

    local rightPanel = CreateFrame("Frame", nil, f, "BackdropTemplate")
    rightPanel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    rightPanel:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 10, 0)
    rightPanel:SetSize(450, 460)

    local panels = {
        ignoreList   = CreateFrame("Frame", nil, rightPanel),
        guildIgnore = CreateFrame("Frame", nil, rightPanel),
        chatFilter   = CreateFrame("Frame", nil, rightPanel),
        optionsMain  = CreateFrame("Frame", nil, rightPanel),
        optionsIgnore= CreateFrame("Frame", nil, rightPanel),
        optionsEI    = CreateFrame("Frame", nil, rightPanel),
        chatFilterDebug = CreateFrame("Frame", nil, rightPanel),
    }
    for _, p in pairs(panels) do p:SetAllPoints(); p:Hide() end
    panels.ignoreList:Show()

    UI.Frames.main = f
    UI.Frames.leftPanel = leftPanel
    UI.Frames.rightPanel = rightPanel
    UI.Frames.panels = panels

    self:BuildNavigation(leftPanel, panels, CrossIgnore)

    return f
end

return UI
