local _, ns = ...
local CrossIgnore = ns.Addon

function CrossIgnore:OnInitialize()
    self:InitDB()
    self:InitMinimap()
    self:LoadDefaultBlockedWords()
    self:StartPurgeRemovedIgnores()

    if self.ChatFilter and self.ChatFilter.Initialize then
        self.ChatFilter:Initialize()
    end

    if self.BlockHandler then
        if self.BlockHandler.Initialize then self.BlockHandler:Initialize() end
        if self.BlockHandler.Register then self.BlockHandler:Register() end
    end

    if self.GuildIgnore then self.GuildIgnore:Initialize() end

    LibStub("AceConfig-3.0"):RegisterOptionsTable("CrossIgnore", ns.Options, {"CrossIgnore", "ci"})

    if not self.isForever then
        self:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED", "OnLFGDecline")
    end
    self:RegisterEvent("IGNORELIST_UPDATE", "DelayedUpdateIgnoreList")
    if self.isForever then self:RegisterEvent("PLAYER_LOGIN", "OnPlayerLogin") end

    if LFGListFrame and LFGListFrame.SearchPanel then
        LFGListFrame:HookScript("OnHide", function()
            if LfgCache then
                for k in pairs(LfgCache) do LfgCache[k] = nil end
            end
        end)
    end

    self:HookFunctions()
end

function CrossIgnore:OnEnable()
    self:RefreshKnownRealms()
    self:ProcessPendingRemovals()
    self:CheckExpiredIgnores()
    if not self._expiryTicker then
        self._expiryTicker = C_Timer.NewTicker(300, function()
            self:CheckExpiredIgnores()
        end)
    end
end

function CrossIgnore:OnDisable()
    if self._expiryTicker then
        self._expiryTicker:Cancel()
        self._expiryTicker = nil
    end
end

function CrossIgnore:OnPlayerLogin()
    self:ProcessPendingRemovals()
end
