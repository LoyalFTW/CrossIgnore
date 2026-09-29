local _, ns = ...
local CrossIgnore = ns.Addon
local L = ns.L

local UI = ns.UI

function UI:BuildNavigation(leftPanel, panels, CrossIgnore)
    local function Btn(parent, text, x, y, w, h)
        local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        b:SetPoint("TOP", x, y)
        b:SetSize(w, h)
        b:SetText(text)
        return b
    end

    local buttons = {
        ignoreList   = Btn(leftPanel, L["IGNORE_LIST_HEADER"], 0, -10, 120, 40),
        guildIgnore = Btn(leftPanel, L["GUILD_IGNORE_TAB"] or "Guild Ignore", 0, -60, 120, 40),
        chatFilter   = Btn(leftPanel, L["CHAT_FILTER_HEADER"], 0, -110, 120, 40),
        optionsMain  = Btn(leftPanel, L["OPTIONS_HEADER"], 0, -160, 120, 40),
        optionsIgnore= Btn(leftPanel, L["OPTIONS_IGNORE"], 10, -205, 110, 30),
        optionsEI    = Btn(leftPanel, L["OPTIONS_E_I"], 10, -240, 110, 30),
        chatFilterDebug = Btn(leftPanel, "ChatFilter DeBug", 10, -275, 110, 30),
    }
    buttons.optionsIgnore:Hide()
    buttons.optionsEI:Hide()
    buttons.chatFilterDebug:Hide()

    local function HideAllPanels()
        for _, p in pairs(panels) do p:Hide() end
        if CrossIgnore.ChatFilter and CrossIgnore.ChatFilter.SetDebugActive then
            CrossIgnore.ChatFilter:SetDebugActive(false)
            if CrossIgnore.ChatFilter.ClearLog then CrossIgnore.ChatFilter:ClearLog() end
        end
    end

    local function ShowOptionsSubButtons(show)
        buttons.optionsIgnore:SetShown(show)
        buttons.optionsEI:SetShown(show)
        buttons.chatFilterDebug:SetShown(show)
    end

    local optionsConfig = {
        { btn = buttons.ignoreList, panel = panels.ignoreList, func = function() CrossIgnore:RefreshBlockedList(UI.State.ignoreFilterText or "") end },
        { btn = buttons.guildIgnore, panel = panels.guildIgnore, func = function() UI.GuildIgnore:Refresh() end },
        { btn = buttons.chatFilter, panel = panels.chatFilter, func = function() CrossIgnore:UpdateWordsList(UI.State.wordFilterText or "") end },
        { btn = buttons.optionsMain, panel = panels.optionsMain, func = function()
            if not CrossIgnore.optionsBuilt and CrossIgnore.CreateOptionsUI then CrossIgnore:CreateOptionsUI(panels.optionsMain); CrossIgnore.optionsBuilt = true end
        end },
        { btn = buttons.optionsIgnore, panel = panels.optionsIgnore, func = function()
            if not CrossIgnore.optionsIgnoreBuilt and CrossIgnore.CreateIgnoreOptions then CrossIgnore:CreateIgnoreOptions(panels.optionsIgnore); CrossIgnore.optionsIgnoreBuilt = true end
        end },
        { btn = buttons.optionsEI, panel = panels.optionsEI, func = function()
            if not CrossIgnore.optionsEIBuilt and CrossIgnore.CreateEIOptions then CrossIgnore:CreateEIOptions(panels.optionsEI); CrossIgnore.optionsEIBuilt = true end
        end },
        { btn = buttons.chatFilterDebug, panel = panels.chatFilterDebug, func = function()
            if not CrossIgnore.chatFilterDebugBuilt and CrossIgnore.CreateChatFilterDebugMenu then
                CrossIgnore:CreateChatFilterDebugMenu(panels.chatFilterDebug)
                CrossIgnore.chatFilterDebugBuilt = true
            end
            if CrossIgnore.ChatFilter and CrossIgnore.ChatFilter.SetDebugActive then
                CrossIgnore.ChatFilter:SetDebugActive(true)
            end
        end },
    }

    for _, cfg in ipairs(optionsConfig) do
        cfg.btn:SetScript("OnClick", function()
            HideAllPanels()
            cfg.panel:Show()
            if cfg.btn == buttons.optionsMain or cfg.btn == buttons.optionsIgnore or cfg.btn == buttons.optionsEI or cfg.btn == buttons.chatFilterDebug then
                ShowOptionsSubButtons(true)
            else
                ShowOptionsSubButtons(false)
            end
            cfg.func()
        end)
    end

    return buttons
end
