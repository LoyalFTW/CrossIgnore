local _, ns = ...
local CrossIgnore = ns.Addon
local L = ns.L

local Core = ns.CoreInternals
local CopyEntry = Core.CopyEntry

function CrossIgnore:ClearAllIgnoredPlayers()
    local players, overLimitPlayers = self:GetActivePlayerTables()

    local snapshot = {}

    local function collect(list)
        for _, entry in ipairs(list or {}) do
            local fullName = self:GetStoredIgnoreName(entry)
            if fullName then
                snapshot[#snapshot + 1] = fullName
            end
        end
    end

    collect(players)
    collect(overLimitPlayers)

    for _, fullName in ipairs(snapshot) do
        self:DelIgnore(fullName)
    end

    self.selectedPlayer = nil
    self.selectedRow = nil

    local ignoreSearchBox = ns.UI.Frames and ns.UI.Frames.ignoreSearchBox
    if ignoreSearchBox then
        self:RefreshBlockedList(ignoreSearchBox:GetText())
    else
        self:RefreshBlockedList()
    end
end

function CrossIgnore:TryAddBlizzardIgnore(fullName, limit)
    if C_FriendList.IsIgnored(fullName) then return true end
    if C_FriendList.GetNumIgnores() >= limit then return false end
    local ok, added = pcall(C_FriendList.AddIgnore, fullName)
    return ok and (added == true or C_FriendList.IsIgnored(fullName)) or false
end

function CrossIgnore:StoreLocalIgnore(entry, blizzard)
    entry.source = blizzard and "blizzard" or "addon"
    local profile = self.charDB.profile
    local list = blizzard and profile.players or profile.overLimitPlayers
    table.insert(list, CopyEntry(entry))
    self:EnsureGlobalPresence(entry, profile.settings.maxIgnoreLimit or 50)
end

function CrossIgnore:AddIgnore(name, note, duration)
    local fullName, base, realm = self:NormalizePlayerName(name)
    if not base or realm == nil then
        if self.isForever then return end
        realm = GetNormalizedRealmName()
        if not base or realm == nil then return end
    end

    if self:IsPlayerInAnyList(base, realm) then return end

    local dur = tonumber(duration)
    if not dur then
        local defaultDays = self.charDB.profile.settings.defaultExpireDays or 0
        dur = (defaultDays > 0) and (defaultDays * 86400) or 0
    end

    local expiresAt = (dur > 0) and (time() + dur) or 0

    local entry = {
        name       = base,
        server     = realm,
        firstName  = self.isForever and base:match("^(%S+)") or nil,
        lastName   = self.isForever and base:match("^%S+%s+(%S+)$") or nil,
        added      = time(),
        ignored    = true,
        type       = "player",
        note       = note or "",
        expires    = expiresAt,
        addedBy    = self:GetCurrentCharacterKey(),
    }

    local limit = self.charDB.profile.settings.maxIgnoreLimit or 50
    self:StoreLocalIgnore(entry, self:TryAddBlizzardIgnore(fullName, limit))

    self:Print(string.format(L["ADD_PLAYER_SUCCESS"] or "Added %s to CrossIgnore.", fullName))

    if self:IsMainFrameShown() then
        self:RefreshBlockedList()
    end
end

function CrossIgnore:maybeMarkPendingRemoval(base, realm, addedBy)
    local myChar = self:GetCurrentCharacterKey()
    if not myChar then return false end
    if addedBy and addedBy ~= myChar then
        local t = self.charDB.profile.settings.useGlobalIgnore and self.globalDB.global.pendingRemovals or self.charDB.profile.pendingRemovals
        table.insert(t, { name = base, server = realm, addedBy = addedBy, markedBy = myChar, markedAt = time() })
        return true
    end
    return false
end

function CrossIgnore:DelIgnore(name)
    if self:RemoveIgnoredPlayer(name) and self:IsMainFrameShown() then
        self:RefreshBlockedList()
    end
end

function CrossIgnore:AddOrDelIgnore(name)
    if self:IsPlayerBlocked(name) then
        self:DelIgnore(name)
    else
        self:AddIgnore(name)
    end
    self:RefreshBlockedList()

    if not self.isForever and LFGListFrame and LFGListFrame.SearchPanel and LFGListFrame.SearchPanel:IsShown() then
        local updateResults = _G["LFGListSearchPanel_UpdateResults"]
        if updateResults then updateResults(LFGListFrame.SearchPanel) end
    end
end

function CrossIgnore:IsPlayerBlocked(playerName)
    local _, name, server = self:NormalizePlayerName(playerName)
    if not name or server == nil then return false end
    return self:IsPlayerInAnyList(name, server)
end
