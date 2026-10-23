local _, ns = ...
local CrossIgnore = ns.Addon
local UI = ns.UI

function CrossIgnore:IsMainFrameShown()
    local main = UI.Frames and UI.Frames.main
    return main ~= nil and main:IsShown()
end

function CrossIgnore:ToggleGUI()
        if self:IsMainFrameShown() then
                UI.Frames.main:Hide()
        else
                if not UI.Frames.main then self:CreateUI() end
                self:UpdateIgnoreList()
                self:CheckExpiredIgnores()
                UI.Frames.main:Show()
        end
end

function CrossIgnore:CreateUI()
    local CrossIgnoreDB = self.globalDB.sv
    UI:BuildMainFrame(self, CrossIgnoreDB)

    local panels = UI.Frames.panels
    if not panels then return end

    if not UI.IgnoreListBuilt then
        UI.IgnoreList:Build(panels.ignoreList, self)
        UI.IgnoreListBuilt = true
    end

    if not UI.GuildIgnoreBuilt then
        UI.GuildIgnore:Build(panels.guildIgnore, self)
        UI.GuildIgnoreBuilt = true
    end

    if not UI.WordFilterBuilt then
        UI.WordFilter:Build(panels.chatFilter, self, CrossIgnoreDB)
        UI.WordFilterBuilt = true
    end

    UI.Frames.main:Show()
end

function CrossIgnore:RefreshBlockedList(filterText)
    if not UI.Frames.main or not UI.Frames.main:IsShown() then return end
    if UI.IgnoreList and UI.IgnoreList.Refresh then
        UI.IgnoreList:Refresh(filterText)
    end
end

function CrossIgnore:UpdateWordsList(searchText)
    if not UI.Frames.main or not UI.Frames.main:IsShown() then return end
    if UI.WordFilter and UI.WordFilter.Refresh then
        UI.WordFilter:Refresh(searchText)
    end
end

return CrossIgnore
